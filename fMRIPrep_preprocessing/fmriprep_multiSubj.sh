#!/bin/bash
# Author: Linjing Jiang
# Date: 03-27-2025 (Updated)
# Description:
#   Submits one SLURM array job where each task processes one subject
#   from the subject list file.

# Set paths (modify as needed)
subject_list_file="./subjlist.txt"
output_dir="./fmriprep_output_dir"
log_dir="${output_dir}/logs"
mkdir -p "$log_dir"

# Create a temporary subject list file (skip header)
temp_subject_list="${log_dir}/subject_list.txt"
tail -n +2 "$subject_list_file" > "$temp_subject_list"

# Count lines (number of jobs)
num_jobs=$(wc -l < "$temp_subject_list")
echo "Submitting ${num_jobs} array jobs (1 per subject)"

# Submit array job
sbatch <<EOF
#!/bin/bash
#SBATCH --job-name=fmriprep
#SBATCH --output=${log_dir}/fmriprep_%A_%a.out
#SBATCH --error=${log_dir}/fmriprep_%A_%a.err
#SBATCH --time=06:00:00
#SBATCH --mem=20G
#SBATCH --cpus-per-task=4
#SBATCH --partition=part # change to your partition
#SBATCH --array=1-${num_jobs}

# Extract the subject corresponding to the array task
mapfile -t subjects < "$temp_subject_list"
SUBJ=\${subjects[\$((SLURM_ARRAY_TASK_ID - 1))]}
echo "Processing subject: \$SUBJ"

# fMRIPrep command parameters
FMRIPREP=./fmriprep-24.1.1.simg
SURF_LICENSE=./license.txt
BIDS_DIR=./bids_dir
OUTPUT_DIR=${output_dir}/derivatives
WORK_DIR=${output_dir}/work

singularity run \\
    \$FMRIPREP \\
    \$BIDS_DIR \$OUTPUT_DIR participant \\
    --n_cpus \$SLURM_CPUS_PER_TASK \\
    --omp-nthreads \$SLURM_CPUS_PER_TASK \\
    --fs-license-file=\$SURF_LICENSE \\
    --participant-label=\$SUBJ \\
    --dummy-scans 4 \\
    --output-spaces MNI152NLin2009cAsym:res-2 anat \\
    --fs-no-reconall \\
    -w \$WORK_DIR
EOF
