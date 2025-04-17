#!/bin/bash
# Author: Linjing Jiang
# Date: 03-25-2025 (Updated)
# Description:
#   Submits one SLURM array job where each task processes one subject-session line
#   from the session mapping file.

# Set paths (modify as needed)
input_dir="./dicom_dir"
output_dir="./output_dir"
mapping_file="./session_map.txt"

# Output log and working directory
log_dir="${output_dir}/logs"
mkdir -p "$log_dir"

# Create a temp joblist file (skip header)
session_list_file="${log_dir}/session_list.txt"
tail -n +2 "$mapping_file" > "$session_list_file"

# Count lines (number of jobs)
num_jobs=$(wc -l < "$session_list_file")
echo "Submitting $num_jobs array jobs (1 per subject-session)"

# Submit array job
sbatch <<EOF
#!/bin/bash
#SBATCH --job-name=dcm2niix_sess_array
#SBATCH --output=${log_dir}/dcm2niix_%A_%a.out
#SBATCH --error=${log_dir}/dcm2niix_%A_%a.err
#SBATCH --time=00:30:00
#SBATCH --mem=10G
#SBATCH --cpus-per-task=1
#SBATCH --partition=part # change to your partition
#SBATCH --array=1-${num_jobs}

# Extract the line corresponding to the array task
mapfile -t lines < "$session_list_file"
line="\${lines[\$((SLURM_ARRAY_TASK_ID - 1))]}"

# Parse CSV: pID,session_date,session_num
IFS=',' read -r pid session_date session_num <<< "\$line"

echo "Processing subject: \$pid | session: \$session_date (ses-\$session_num)"

bash dcm2niix_func.sh "\$pid" "\$session_date" "\$session_num" "$input_dir" "$output_dir"
EOF
