#!/bin/bash

#SBATCH --job-name=fmriprep
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32g
#SBATCH --mail-type=NONE
#SBATCH --time=08:00:00
#
# Single-subject fMRIPrep run, for debugging one subject before launching the
# array job in fmriprep_multiSubj.sh.
#
# Log paths and --partition are not settable from config here, because SBATCH
# directives are read before the script runs. Pass them on the command line:
#
#   sbatch --partition=<queue> \
#          --output=<logdir>/%x-%j.log --error=<logdir>/%x-%j.err \
#          fmriprep_singleSubj.sh <subject_id>

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/config/load_config.sh"

hostname -s
uptime

SUBJ="${1:?usage: sbatch fmriprep_singleSubj.sh <subject_id>}"
FMRIPREP="$FMRIPREP_SIMG"
SURF_LICENSE="$FS_LICENSE_FILE"
OUTPUT_DIR="${FMRIPREP_DIR}/derivatives"
WORK_DIR="${FMRIPREP_DIR}/work"

# Keep every flag on the continuation chain. A commented-out line in the middle
# of a `\`-continued command silently truncates it -- bash treats the comment as
# ending the logical line, so the remaining flags are dropped and fMRIPrep runs
# with the wrong options.
singularity run \
    "$FMRIPREP" \
    "$BIDS_DIR" "$OUTPUT_DIR" participant \
    --n_cpus "$SLURM_CPUS_PER_TASK" \
    --omp-nthreads "$SLURM_CPUS_PER_TASK" \
    --fs-license-file="$SURF_LICENSE" \
    --participant-label="$SUBJ" \
    --dummy-scans "$DUMMY_SCANS" \
    --fs-no-reconall \
    --output-spaces MNI152NLin2009cAsym:res-2 \
    -w "$WORK_DIR"