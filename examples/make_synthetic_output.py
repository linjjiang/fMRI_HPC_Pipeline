"""Generate a synthetic stage-4 output file with the same structure as a real one.

No real data is involved: the timeseries are Gaussian noise and the subject ID
is fictional. The point is to make the output contract inspectable by someone
who has neither the imaging data nor a cluster.

    python examples/make_synthetic_output.py
    python timeseries_extraction/check_ts.py examples/sub-EXAMPLE_ses-01_ts.npz

The shapes and key names below mirror save_results() in
timeseries_extraction/run_extraction.py exactly.
"""

import os

import numpy as np

# Matches config/pipeline.env.example
TR = 0.8
DUMMY_SCANS = 4

# One task block group is 25 s 0-back + 25 s 2-back + 15 s rest, repeated 4x.
BLOCK_S = [25.0, 25.0, 15.0]
N_BLOCK_GROUPS = 4
RUN_DURATION_S = sum(BLOCK_S) * N_BLOCK_GROUPS          # 260 s
N_TIMEPOINTS = int(RUN_DURATION_S / TR) + 1 - DUMMY_SCANS

# Two runs, acquired with opposing phase-encoding directions.
RUN_IDS = ["run_01_dir_AP", "run_02_dir_PA"]

# One mask file per ROI; names are whatever ROI_EXPRESSION globbed up.
ROI_IDS = [
    "L_DLPFC_Atlas.nii.gz",
    "R_DLPFC_Atlas.nii.gz",
    "L_IPS_Atlas.nii.gz",
    "R_IPS_Atlas.nii.gz",
    "L_Hippocampus_Atlas.nii.gz",
    "R_Hippocampus_Atlas.nii.gz",
]


def build_task_design():
    """Reproduce the events -> onset/offset dict that extract_task_design builds."""
    designs = {}
    for run_id in RUN_IDS:
        onsets = {"0bk": [], "2bk": [], "rest": []}
        durations = {"0bk": [], "2bk": [], "rest": []}
        t = 0.0
        for _ in range(N_BLOCK_GROUPS):
            for cond, dur in zip(["0bk", "2bk", "rest"], BLOCK_S):
                onsets[cond].append(t)
                durations[cond].append(dur)
                t += dur
        designs[run_id] = {
            cond: {
                "onset": np.array(onsets[cond]),
                "offset": np.array(onsets[cond]) + np.array(durations[cond]),
            }
            for cond in onsets
        }
    return designs


def main():
    rng = np.random.default_rng(0)

    # run_extraction.py z-scores each ROI column via
    # nilearn.signal.clean(standardize=True), so synthetic data is drawn
    # standard-normal and re-standardized to match.
    ts = rng.standard_normal((len(RUN_IDS), N_TIMEPOINTS, len(ROI_IDS)))
    ts = (ts - ts.mean(axis=1, keepdims=True)) / ts.std(axis=1, keepdims=True)

    out = os.path.join(os.path.dirname(__file__), "sub-EXAMPLE_ses-01_ts.npz")
    np.savez_compressed(
        out,
        ts_array=ts,
        run_ids=np.array(RUN_IDS),
        roi_ids=np.array(ROI_IDS),
        task_designs=build_task_design(),
    )
    print(f"wrote {out}")
    print(f"ts_array shape: {ts.shape}  (n_runs, n_timepoints, n_rois)")


if __name__ == "__main__":
    main()
