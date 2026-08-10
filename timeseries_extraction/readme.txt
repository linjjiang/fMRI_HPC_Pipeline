Stage 4 -- ROI timeseries extraction
Linjing Jiang
Mar-31-2025

Run in this order:

gen_subjlist_for_ts.py
    Build the stage-4 subject list: the intersection of subjects that finished
    fMRIPrep and subjects with complete behavioral data. Writes with NO header,
    because the array job maps task N to line N.

submit_ts_extraction_job.slurm
    Submit one array task per subject-session. Run with `bash`, NOT `sbatch` --
    this script contains its own sbatch call.

run_extraction.py
    The per-subject-session worker, invoked by the array task. Parallelises
    across ROIs with joblib.
    NOTE: ROI masks are affine-resampled only, with no nonlinear warp. Valid
    only for atlases already in MNI152NLin2009cAsym -- see README, "Status and
    known limitations".

check_ts.py
    Inspect one output .npz: shapes, per-ROI mean/sd, and event timing. Useful
    as a smoke test across a finished batch.
    Usage: python check_ts.py <path to sub-XXX_ses-NN_ts.npz>
