"""Inspect one extracted timeseries .npz and print its structure.

Usage:
    python check_ts.py /path/to/sub-XXX_ses-YY_ts.npz

Prints the shape and contents of every array in the archive. Useful as a
sanity check after a batch of extraction jobs, and as documentation of the
output format -- see examples/output_format.md for the shapes it should print.
"""

import argparse

import numpy as np


def describe(path):
    data = np.load(path, allow_pickle=True)

    print(f"archive: {path}")
    print(f"keys:    {list(data.keys())}\n")

    ts = data["ts_array"]
    run_ids = [str(x) for x in data["run_ids"]]
    roi_ids = [str(x) for x in data["roi_ids"]]

    print(f"ts_array shape : {ts.shape}   (n_runs, n_timepoints, n_rois)")
    print(f"ts_array dtype : {ts.dtype}")
    print(f"run_ids ({len(run_ids)}) : {', '.join(run_ids)}")
    print(f"roi_ids ({len(roi_ids)}) : {', '.join(roi_ids[:4])}"
          f"{', ...' if len(roi_ids) > 4 else ''}\n")

    # Signals are z-scored per ROI by nilearn.signal.clean(standardize=True),
    # so each column should sit near mean 0, sd 1.
    for r, run_id in enumerate(run_ids):
        col = ts[r, :, 0]
        print(f"{run_id}: roi[0] mean={col.mean():+.4f} sd={col.std():.4f} "
              f"n={col.size}")

    # task_designs is a dict, stored as a 0-d object array.
    task_designs = data["task_designs"].item()
    print()
    for run_id, conditions in task_designs.items():
        print(f"{run_id}:")
        for cond, times in conditions.items():
            print(f"    {cond:<6} {len(times['onset'])} events, "
                  f"first onset {times['onset'][0]:.2f}s")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("npz", help="path to a *_ts.npz produced by run_extraction.py")
    describe(parser.parse_args().npz)
