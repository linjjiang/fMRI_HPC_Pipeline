#!/bin/bash
# submit_behav_symlink_jobs.sh
#
# This script submits one SLURM job per subject for behavioral symlink conversion.
# The behavioral symlink script (symlink_behav_to_bids.sh) expects arguments:
#   <behav_source_root> <bids_root> <subject_id> <json_mapping>
#
# Adjust SBATCH directives (e.g., walltime, memory) as needed.

# Define file paths and directories
SUBJ_LIST="./subjlist.txt"
BEHAV_ROOT='./behav_dir'
#"/oak/stanford/groups/menon/projects/ljjiang/2025_mdsihvb_ad/data/imaging/participants/hcp_upmc_raw_behav"
BIDS_DIR="./bids_dir"
JSON_MAPPING="bids_mapping.json"
LOG_DIR="${BIDS_DIR}/behav_logs"

# Check that the subject list file exists
if [ ! -f "$SUBJ_LIST" ]; then
    echo "Error: Subject list file '$SUBJ_LIST' not found!"
    exit 1
fi

# Create logs directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Process each subject, skipping the header (first line)
tail -n +2 "$SUBJ_LIST" | while IFS= read -r subject || [ -n "$subject" ]; do
    # Skip empty lines
    if [ -z "$subject" ]; then
        continue
    fi
    echo "Processing subject: $subject"
    # Create a log file for this subject with a timestamp
    logfile="${LOG_DIR}/${subject}_$(date +%Y%m%d%H%M%S).log"
    # Run the conversion script and redirect both stdout and stderr to the log file
    ./symlink_behav_to_bids.sh "$BEHAV_ROOT" "$BIDS_DIR" "$subject" "$JSON_MAPPING" > "$logfile" 2>&1
    echo "Subject $subject processed. Log saved to $logfile"
done

echo "All subjects processed successfully."
