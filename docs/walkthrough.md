# One subject's journey through the pipeline

Following a single fictional subject, `1001`, scanned twice. This is the same
path all ~1,000 subjects take; the only difference at scale is that stages 2, 3
and 4 run as SLURM array jobs rather than one at a time.

Every path below is a placeholder from `config/pipeline.env.example`. No real
subject IDs, dates, or cluster paths appear anywhere in this repo.

---

## Stage 1 — Data preparation

**In:** the raw DICOM tree, as the scanner console wrote it.

```
$DICOM_DIR/1001/1001_20240115/scans/1_T1w_MPR/resources/DICOM/files/*.dcm
                             /scans/6_BOLD_WM1_AP/resources/DICOM/files/*.dcm
                             /scans/7_BOLD_WM2_PA/resources/DICOM/files/*.dcm
$DICOM_DIR/1001/1001_20240712/scans/...
```

`gen_subjlist.sh` walks that tree and writes the roster. `gen_session_map.sh`
sorts each subject's scan dates and assigns sequential session numbers:

```
# $SESSION_MAP
pID,session_date,session_num
1001,20240115,01
1001,20240712,02
```

This mapping is the pipeline's one privacy-relevant hinge. **The scan date is
used here and then dropped.** Everything downstream refers to `ses-01`, never
`20240115`, so a calendar date — which is re-identifying — never reaches BIDS
filenames, derivatives, or output archives. The map itself is written to
`$WORK_DIR`, outside the repo, and is gitignored.

In parallel, `task_design.m` parses the raw E-Prime logs into `.mat` trial
tables, then `task_design_bids.m` converts those to BIDS `_events.tsv`. Onsets
are shifted by `-TR/2` to match fMRIPrep's slice-timing reference, and the first
`DUMMY_SCANS × TR` seconds are subtracted so behavioral time and imaging time
share an origin.

**Out:** `$SUBJECT_LIST`, `$SESSION_MAP`, `$BEHAV_DIR/sub-1001/ses-01/func/*_events.tsv`

---

## Stage 2 — BIDS conversion

**In:** DICOMs + the session map.

`submit_dcm2nii_job.sh` reads `$SESSION_MAP`, counts its lines, and submits a
SLURM array with **one task per subject-session** — subject 1001 gets two tasks,
one per session, which run concurrently on different nodes. Each task calls
`dcm2niix_func.sh`, which converts every scan folder in that session.

```
$NIFTI_DIR/sub-1001/ses-01/6_BOLD_WM1_AP.nii.gz
                           6_BOLD_WM1_AP.json
                           1_T1w_MPR.nii.gz
```

Then `nii2bids_all.sh` walks the subject list and, per subject, runs
`symlink_nii_to_bids.sh`. The BIDS layout is built from **symlinks, not copies** —
at 10 TB+ this is the difference between a few megabytes of metadata and a
second full copy of the dataset. Which scanner filename maps to which BIDS
entity is declared in `bids_mapping.json`, not hardcoded in the script:

```json
"func": {
  "source": "sub-{subject}/ses-{session}/*BOLD_{task}{run}_{direction}.nii.gz",
  "dest":   "sub-{subject}/ses-{session}/func/sub-{subject}_ses-{session}_task-{task}_dir-{direction}_run-{run}_bold.nii.gz"
}
```

JSON sidecars are *copied* rather than symlinked, because they get mutated —
`TaskName` is injected into functional sidecars, and fieldmap sidecars get an
`IntendedFor` list built only from functional files that actually exist.
`behav2bids_all.sh` then links the stage-1 events files in, but only for
sessions that already have imaging.

**Out:** a BIDS dataset at `$BIDS_DIR`.

---

## Stage 3 — Preprocessing (fMRIPrep)

**In:** `$BIDS_DIR`.

`fmriprep_multiSubj.sh` submits an array with **one task per subject** — the
unit of parallelism widens here, because fMRIPrep works on a whole subject at
once. Each task runs the pinned fMRIPrep container under Singularity:

```
--participant-label=1001
--dummy-scans 4
--output-spaces MNI152NLin2009cAsym:res-2 anat
--fs-no-reconall
--n_cpus $SLURM_CPUS_PER_TASK
```

`--fs-no-reconall` skips FreeSurfer surface reconstruction, which is the
single largest time saver — volumetric ROI extraction is all stage 4 needs, and
surfaces would add hours per subject across 1,000+ subjects.

Use `fmriprep_singleSubj.sh` to debug one subject before committing the array.

**Out:** `$FMRIPREP_DIR/derivatives/sub-1001/ses-01/func/` containing
`*_space-MNI152NLin2009cAsym_res-2_desc-preproc_bold.nii.gz` and
`*_desc-confounds_timeseries.tsv`.

---

## Stage 4 — ROI timeseries extraction

**In:** fMRIPrep derivatives + confounds + the stage-1 events files.

`gen_subjlist_for_ts.py` intersects "finished preprocessing" with "has complete
behavioral data" — a subject that fails either check is dropped rather than
carried forward as a half-populated row. That intersection drives the array.

`submit_ts_extraction_job.slurm` submits **one task per subject-session**, and
inside each task `run_extraction.py` uses **joblib to fan out across ROIs**.
That is the nested-parallelism layer: SLURM across subjects, joblib across ROIs
within a subject. BLAS threading is pinned to 1 (`OMP_NUM_THREADS` and friends)
so joblib workers don't oversubscribe the allocated cores — without that, N
workers each spawning N BLAS threads will thrash a node.

Per ROI: resample the mask, binarise, extract voxels, drop dummy scans from
signal and confounds together, high-pass filter and regress out motion + CSF +
white matter, standardize, then average across voxels.

> **Limitation.** The mask step is an affine resample onto the functional voxel
> grid, with no nonlinear transform. It is only correct for ROIs already defined
> in `MNI152NLin2009cAsym`. An atlas in any other space must be warped with ANTs
> (`antsApplyTransforms`, using the `*_from-MNI152NLin2009cAsym_to-T1w_*_xfm.h5`
> that fMRIPrep emits) before it is usable here. Resampling alone would produce
> misaligned ROIs without raising an error.

**Out:** `$TS_DIR/sub-1001_ses-01_ts.npz`, an array of shape
`(n_runs, n_timepoints, n_rois)` plus run labels, ROI labels, and event timing.
See [examples/output_format.md](../examples/output_format.md).

---

## Where things fail, and what catches it

At this scale individual tasks fail routinely; the design assumes it.

- **Stage 2 walltime.** Sessions with unusually many series exceed
  `DCM2NII_TIME`. `extract_timed_out.sh` greps the job logs for
  `DUE TO TIME LIMIT`, recovers the subject/session from the matching `.out`
  file, and re-emits a session map that can be resubmitted with a longer
  `--time`.
- **Missing runs.** `symlink_nii_to_bids.sh` skips a session with no task data
  instead of creating an empty BIDS folder that would later fail validation.
- **Missing derivatives.** `run_extraction.py` checks that the preprocessed
  BOLD, confounds, and events files all exist before touching a run, and logs a
  warning rather than crashing the array task.
- **Per-ROI failures.** Each ROI is extracted in a `try/except`; one bad mask
  logs an error and returns `None` instead of losing the whole subject.
- **Per-subject logs.** Every stage writes one log per unit of work, so a
  failure at subject 700 of 1,000 is diagnosable without re-running anything.
