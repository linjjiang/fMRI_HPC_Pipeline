#!/bin/bash
# Author: Linjing Jiang
# Apr-01-2025
#
# Stage 4: submit one SLURM array task per subject-session for ROI timeseries
# extraction. Each task runs run_extraction.py, which parallelises across ROIs
# with joblib.
#
# Usage:  bash submit_ts_extraction_job.slurm
#         (NOT sbatch -- this script contains its own sbatch call)
#
# All paths and parameters come from config/pipeline.env.

set -euo pipefail
stage_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${stage_dir}/../config/load_config.sh"

output_folder="$TS_DIR"                       # output - a new folder
fmriprep_base="${FMRIPREP_DIR}/derivatives"   # imaging data (preprocessed)
events_base="$BIDS_DIR"                       # task design
roi_dir="$ROI_DIR"                            # roi masks
subjlist="$TS_SUBJECT_LIST"                   # subject list, no header
roi_expression="$ROI_EXPRESSION"
tr="$TR"
high_pass="$HIGH_PASS"
dummy_scan="$DUMMY_SCANS"
task_label="$TASK_LABEL"

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

# Count number of jobs. The list has no header, so line N == array task N.
num_jobs=$(wc -l < "$subjlist")
echo "Found ${num_jobs} subject-sessions in the subject list"

# Submit array job without quoting the EOF delimiter so that shell variables are expanded.
sbatch <<EOF
#!/bin/bash
#SBATCH --job-name=fMRI_extraction
#SBATCH --output=${log_dir}/%A_%a.out
#SBATCH --error=${log_dir}/%A_%a.err
#SBATCH --array=1-${num_jobs}
#SBATCH --time=${TS_TIME}
#SBATCH --cpus-per-task=${TS_CPUS}
#SBATCH --partition=${SLURM_PARTITION}
#SBATCH --mem=${TS_MEM}

echo "SLURM job started on \$(hostname) at \$(date)"

# Limit max threads (avoid BLAS / numpy multithreading conflict)
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export NUMEXPR_NUM_THREADS=1

# Get subject and session IDs from the subject list (no header; line N = task N)
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

# joblib workers are capped below --cpus-per-task to leave headroom for I/O.
python "${stage_dir}/run_extraction.py" --subid "\$subid" --sesid "\$sesid" \
    --output_folder "${output_folder}" \
    --fmriprep_base "${fmriprep_base}" \
    --events_base "${events_base}" \
    --roi_dir "${roi_dir}" \
    --roi_expression "${roi_expression}" \
    --task_label "${task_label}" \
    --tr "${tr}" \
    --high_pass "${high_pass}" \
    --dummy_scan "${dummy_scan}" \
    --n_jobs ${TS_NJOBS}

echo "SLURM job completed at \$(date)"
EOF
