#!/bin/bash
# Author: Linjing Jiang
# Apr-01-2025
# This script submits timeseries extraction job for each subject (rerun)
# Tailored for HCP UPMC dataset.
# IMPORTANT: do not put spaces at random places, linux is sensitive to spaces!
# Make sure you change:
# 1) All the paths and variables
# 2) Job array, time, number of cpus, partition, memory, and n_job inputs for run_extraction_updated.py script


# Set paths (modify as needed)
output_folder='./ts_output_dir'  # output - a new folder
fmriprep_base='./fmriprep_output_dir/derivatives'   # imaging data (preprocessed)
events_base='./bids_dir'                          # task design
roi_dir='./roi_dir' # roi
subjlist='./ts_subjlist.txt' # subject list
#'/scratch/users/ljjiang/hcp_upmc_mdsi/ts_all_wt_fieldmap/failed_subjects_3.txt' # subject list
roi_expression='*_Atlas.nii.gz'
tr='0.8'
high_pass='0.008'
dummy_scan='4'

# Check if subject list file exists
if [ ! -f "$subjlist" ]; then
    echo "Error: Subject list file $subjlist does not exist"
    exit 1
fi

# Check if subject list file is empty
if [ ! -s "$subjlist" ]; then
    echo "Error: Subject list file $subjlist is empty"
    exit 1
fi

# Output log and working directory
log_dir="${output_folder}/logs"
mkdir -p "$log_dir"

# Count number of jobs (subjects) for the header
num_jobs=$(($(wc -l < "$subjlist")))
echo "Found ${num_jobs} subjects in the subject list (excluding header)"

# Submit array job without quoting the EOF delimiter so that shell variables are expanded.
sbatch <<EOF
#!/bin/bash
#SBATCH --job-name=fMRI_extraction
#SBATCH --output=${log_dir}/%A_%a.out
#SBATCH --error=${log_dir}/%A_%a.err
#SBATCH --array=1-${num_jobs}
#SBATCH --time=03:00:00 
#SBATCH --cpus-per-task=8 
#SBATCH --partition=part
#SBATCH --mem=32G

echo "SLURM job started on \$(hostname) at \$(date)"

# Limit max threads (avoid BLAS / numpy multithreading conflict)
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export NUMEXPR_NUM_THREADS=1

# Get subject and session IDs from the subject list (do not skip header)
linenum=\$((SLURM_ARRAY_TASK_ID))
line=\$(sed -n "\${linenum}p" "$subjlist")
if [ -z "\$line" ]; then
    echo "Error: Could not read line \$linenum from subject list"
    exit 1
fi

subid=\$(echo "\$line" | awk '{print \$1}')
sesid=\$(echo "\$line" | awk '{print \$2}')

if [ -z "\$subid" ] || [ -z "\$sesid" ]; then
    echo "Error: Invalid subject or session ID at line \$linenum"
    exit 1
fi

echo "Processing subject \$subid, session \$sesid"

# Run with capped number of ROI workers (e.g., 10 if --cpus-per-task=12)
echo "Calling with arguments: ..."
python ./run_extraction_updated.py --subid "\$subid" --sesid "\$sesid" \
    --output_folder "${output_folder}" \
    --fmriprep_base "${fmriprep_base}" \
    --events_base "${events_base}" \
    --roi_dir "${roi_dir}" \
    --roi_expression "${roi_expression}" \
    --tr "${tr}" \
    --high_pass "${high_pass}" \
    --dummy_scan "${dummy_scan}" \
    --n_jobs 6

echo "SLURM job completed at \$(date)"
EOF
