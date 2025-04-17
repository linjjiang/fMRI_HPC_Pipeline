# Updated run_extraction.py to use joblib instead of multiprocessing for ROI parallelism
# %%
import os
import glob
import numpy as np
import pandas as pd
import nibabel as nib
from nilearn import image, input_data, signal
from nilearn.image import new_img_like
import argparse
import logging
import time
from joblib import Parallel, delayed
import psutil

# %%
# Limit thread usage for numpy/BLAS libs
os.environ["OMP_NUM_THREADS"] = "1"
os.environ["MKL_NUM_THREADS"] = "1"
os.environ["OPENBLAS_NUM_THREADS"] = "1"
os.environ["NUMEXPR_NUM_THREADS"] = "1"

def extract_confounds(confound_file):
    df = pd.read_csv(confound_file, sep='\t')
    cols = ['csf', 'white_matter', 'trans_x', 'trans_y', 'trans_z', 'rot_x', 'rot_y', 'rot_z']
    return df[cols]

def extract_task_design(events_file):
    events = pd.read_csv(events_file, sep='\t')
    task_design = {}
    for trial in events['trial_type'].unique():
        trial_events = events[events['trial_type'] == trial]
        onsets = trial_events['onset'].values
        offsets = (trial_events['onset'] + trial_events['duration']).values
        task_design[trial] = {'onset': onsets, 'offset': offsets}
    return task_design

def resample_roi(roi_img, target_img):
    return image.resample_to_img(roi_img, target_img, interpolation='nearest')

def extract_timeseries(fmri_img, roi_img, roi_name, confounds, tr, high_pass, dummy_scan):
    try:
        start_time = time.time()
        logging.info("Starting timeseries extraction for ROI: %s", roi_name)

        # 1. Resample ROI
        roi_resampled = resample_roi(roi_img, fmri_img)
        #logging.info("[%s] Step 1: ROI resampled", roi_name)

        # 2. Binarize ROI
        roi_data = roi_resampled.get_fdata()
        # Binarize: set non-zero voxels to 1
        binary_mask = (roi_data > 0).astype(np.uint8)
        # Turn binary arrays back into NIfTI images
        mask_img = new_img_like(roi_resampled, binary_mask)
        #logging.info("[%s] Step 2: ROI binarized (%d voxels)", roi_name, binary_mask.sum())

        # 3. Create a ROI mask
        masker = input_data.NiftiMasker(mask_img=mask_img) #standardize=True # do not use NiftiLabelsMasker, use NiftiMasker
        #logging.info("[%s] Step 3: NiftiMasker created", roi_name)

        # 4. Mask the fMRI image (extract timeseries)
        ts = masker.fit_transform(fmri_img)
        #logging.info("[%s] Step 4: Timeseries extracted (shape: %s)", roi_name, ts.shape)

        # 5. Remove dummy scans
        ts_nodummy = ts[dummy_scan:,:] # from fmri timeseries
        confounds_nodummy = confounds.values[dummy_scan:,:] # from confounds timeseries
        #logging.info("[%s] Step 5: Dummy scans removed (n=%d)", roi_name, dummy_scan)

        # 6. Denoise the signal (high-pass butterworth filter (high_pass=0.008 Hz) -> confound regression (6 motion params, csf, wm) -> standardization)
        ts_clean = signal.clean(ts_nodummy, confounds=confounds_nodummy, t_r=tr,
                        low_pass=None, high_pass=high_pass, standardize=True,detrend=False)
        #logging.info("[%s] Step 6: Signal cleaned", roi_name)

        # 7. Average timeseries across voxels
        roi_ts = np.mean(ts_clean, axis=1)
        #logging.info("[%s] Step 7: Timeseries averaged (final shape: %s)", roi_name, roi_ts.shape)

        # Logging information and return extracted timeseries
        logging.info("[%s] ✅ Timeseries extraction complete in %.2fs", roi_name, time.time() - start_time)

        return roi_name, roi_ts
    
    except Exception as e:
        logging.error("Error processing ROI %s: %s", roi_name, str(e))
        return roi_name, None

def save_results(output_file, ts_array, run_ids, roi_ids, task_designs):
    np.savez_compressed(output_file, ts_array=ts_array, run_ids=run_ids, roi_ids=roi_ids, task_designs=task_designs)
    logging.info("Saved results to %s", output_file)

def main(args):
    subid = args.subid
    sesid = args.sesid
    output_folder = args.output_folder
    fmriprep_base = args.fmriprep_base
    events_base = args.events_base
    roi_dir = args.roi_dir
    roi_expression = args.roi_expression
    tr = float(args.tr)
    high_pass = float(args.high_pass)
    dummy_scan = int(args.dummy_scan)

    log_file = os.path.join(output_folder, "sub-"+subid+"_ses-"+sesid+"_run_extraction.log")
    logging.basicConfig(
        filename=log_file,
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    )
    console = logging.StreamHandler()
    console.setLevel(logging.INFO)
    formatter = logging.Formatter("%(asctime)s [%(levelname)s] %(message)s", datefmt="%Y-%m-%d %H:%M:%S")
    console.setFormatter(formatter)
    logging.getLogger('').addHandler(console)

    logging.info("Started processing subject %s session %s", subid, sesid)

    run_dir_pairs = [('01', 'AP'), ('02', 'PA')]
    roi_pattern = os.path.join(roi_dir, roi_expression)
    roi_files = sorted(glob.glob(roi_pattern))
    if len(roi_files) == 0:
        logging.error("No ROI files found in %s", roi_dir)
        return
    roi_imgs = [(os.path.basename(f), nib.load(f)) for f in roi_files]
    roi_ids = [name for name, _ in roi_imgs]

    run_ids = []
    task_designs = {}
    ts_per_run = []

    for run, direction in run_dir_pairs:
        fmri_file = os.path.join(fmriprep_base,
            "sub-"+subid,"ses-"+sesid,"func","sub-"+subid+"_ses-"+sesid+"_task-WM_dir-"+direction+"_run-"+run+"_space-MNI152NLin2009cAsym_res-2_desc-preproc_bold.nii.gz")
        confound_file = os.path.join(fmriprep_base,
            "sub-"+subid,"ses-"+sesid,"func","sub-"+subid+"_ses-"+sesid+"_task-WM_dir-"+direction+"_run-"+run+"_desc-confounds_timeseries.tsv")
        events_file = os.path.join(events_base,
            "sub-"+subid,"ses-"+sesid,"func","sub-"+subid+"_ses-"+sesid+"_task-WM_dir-"+direction+"_run-"+run+"_events.tsv")

        if not all(map(os.path.exists, [fmri_file, confound_file, events_file])):
            logging.warning("Missing one or more files for run %s-%s", run, direction)
            continue

        run_id = "run_"+run+"_dir_"+direction
        run_ids.append(run_id)
        logging.info("Processing run %s", run_id)

        # load the fmri image, confounds, and task designs
        fmri_img = nib.load(fmri_file)
        confounds = extract_confounds(confound_file)
        task_designs[run_id] = extract_task_design(events_file)

        
        logging.info("Memory usage before ROI extraction: %.2f GB", psutil.Process().memory_info().rss / 1e9)

        roi_results = Parallel(n_jobs=args.n_jobs)(
            delayed(extract_timeseries)(fmri_img, roi_img, roi_name, confounds, tr, high_pass, dummy_scan)
            for roi_name, roi_img in roi_imgs
        )

        roi_ts_list = []
        for roi_name, roi_ts in roi_results:
            if roi_ts is not None:
                roi_ts_list.append(roi_ts)
            else:
                logging.warning("Skipping ROI %s", roi_name)

        if roi_ts_list:
            run_ts_matrix = np.column_stack(roi_ts_list)
            ts_per_run.append(run_ts_matrix)
        else:
            logging.warning("No ROI time series collected for run %s", run_id)

    if ts_per_run:
        ts_array = np.stack(ts_per_run, axis=0)
        output_file = os.path.join(output_folder, "sub-"+subid+"_ses-"+sesid+"_ts.npz")
        save_results(output_file, ts_array, run_ids, roi_ids, task_designs)
    else:
        logging.error("No runs were processed for subject %s session %s", subid, sesid)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--subid", required=True)
    parser.add_argument("--sesid", required=True)
    parser.add_argument("--output_folder", required=True)
    parser.add_argument("--fmriprep_base", required=True)
    parser.add_argument("--events_base", required=True)
    parser.add_argument("--roi_dir", required=True)
    parser.add_argument("--roi_expression", required=True)
    parser.add_argument("--tr", required=True)
    parser.add_argument("--high_pass", required=True)
    parser.add_argument("--dummy_scan", required=True)
    parser.add_argument("--n_jobs", type=int, default=8, help="Number of processes (default: 8)")
    args = parser.parse_args()
    main(args)
