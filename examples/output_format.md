# Output format

The pipeline's terminal artifact is one compressed NumPy archive per
subject-session: `sub-<pID>_ses-<NN>_ts.npz`.

You can produce a structurally identical file without any real data:

```console
$ python examples/make_synthetic_output.py
$ python timeseries_extraction/check_ts.py examples/sub-EXAMPLE_ses-01_ts.npz
archive: examples/sub-EXAMPLE_ses-01_ts.npz
keys:    ['ts_array', 'run_ids', 'roi_ids', 'task_designs']

ts_array shape : (2, 322, 6)   (n_runs, n_timepoints, n_rois)
ts_array dtype : float64
run_ids (2) : run_01_dir_AP, run_02_dir_PA
roi_ids (6) : L_DLPFC_Atlas.nii.gz, R_DLPFC_Atlas.nii.gz, L_IPS_Atlas.nii.gz, R_IPS_Atlas.nii.gz, ...

run_01_dir_AP: roi[0] mean=-0.0000 sd=1.0000 n=322
run_02_dir_PA: roi[0] mean=+0.0000 sd=1.0000 n=322

run_01_dir_AP:
    0bk    4 events, first onset 0.00s
    2bk    4 events, first onset 25.00s
    rest   4 events, first onset 50.00s
run_02_dir_PA:
    0bk    4 events, first onset 0.00s
    2bk    4 events, first onset 25.00s
    rest   4 events, first onset 50.00s
```

## Keys

| Key | Type | Shape | Meaning |
|---|---|---|---|
| `ts_array` | `float64` | `(n_runs, n_timepoints, n_rois)` | Denoised, ROI-averaged BOLD signal |
| `run_ids` | `str` | `(n_runs,)` | e.g. `run_01_dir_AP`; indexes axis 0 |
| `roi_ids` | `str` | `(n_rois,)` | ROI mask filenames; indexes axis 2 |
| `task_designs` | `dict` | — | Per-run event timing; needs `.item()` to unpack |

`n_timepoints` is volumes remaining after the first `DUMMY_SCANS` are dropped.
Runs that fail validation are skipped, so `n_runs` can be 1 rather than 2 —
axis 0 is always aligned to `run_ids`, never assumed to be length 2.

## Why these values look the way they do

Each column of `ts_array` is z-scored, because
`nilearn.signal.clean(..., standardize=True)` is the last denoising step. A
per-ROI mean near 0 and sd near 1 is therefore the expected signature of a
correctly processed run, which is what makes `check_ts.py` a useful smoke test
across a batch of a few hundred output files.

`task_designs` is a nested dict, stored as a 0-d object array:

```python
data = np.load(path, allow_pickle=True)
designs = data["task_designs"].item()
designs["run_01_dir_AP"]["2bk"]["onset"]   # np.ndarray of onset times, seconds
designs["run_01_dir_AP"]["2bk"]["offset"]  # onset + duration
```

Onsets are in seconds relative to the first retained volume, already shifted by
`-TR/2` (see the slice-timing note in
`prepare_data/make_behav_design/task_design_bids.m`).

## Denoising applied

In `extract_timeseries()`, per ROI, in order:

1. Resample the ROI mask to the functional image (nearest-neighbour). **Affine
   grid resampling only — no nonlinear warp.** Valid only for ROIs already in
   `MNI152NLin2009cAsym`; see the limitation note in the README.
2. Binarise the mask.
3. Extract per-voxel timeseries with `NiftiMasker`.
4. Drop the first `DUMMY_SCANS` volumes from signal and confounds together.
5. `signal.clean`: high-pass Butterworth at `HIGH_PASS` Hz, regress out 6 motion
   parameters plus CSF and white-matter signal, then standardise.
6. Average across voxels within the ROI.

Step 4 dropping both signal and confounds together is what keeps the confound
matrix row-aligned with the signal; getting that wrong is a common and silent
source of bad denoising.
