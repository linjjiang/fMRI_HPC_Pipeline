#!/bin/bash

#SBATCH --job-name=fmriprep
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32g
#SBATCH --mail-type=NONE
#SBATCH --partition=part
#SBATCH --output=./fmriprep_output_dir/logs/%x-%j.log
#SBATCH --error=./fmriprep_output_dir/logs/%x-%j.err
#SBATCH --time=08:00:00

hostname -s
uptime

SUBJ=123 #$1
FMRIPREP=./fmriprep-24.1.1.simg
SURF_LICENSE=./license.txt
BIDS_DIR=./bids_dir
OUTPUT_DIR=./fmriprep_output_dir/derivatives
WORK_DIR=./fmriprep_output_dir/work

singularity run \
    $FMRIPREP      \
    $BIDS_DIR $OUTPUT_DIR participant \
    --n_cpus $SLURM_CPUS_PER_TASK        \
    --omp-nthreads $SLURM_CPUS_PER_TASK \
    --fs-license-file=$SURF_LICENSE         \
    --participant-label=$SUBJ \
    # --skip_bids_validation --ignore slicetiming \
    --dummy-scans 4 \
    --fs-no-reconall \
    --output-spaces MNI152NLin2009cAsym:res-2 \
    -w $WORK_DIR