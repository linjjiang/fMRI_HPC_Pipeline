#!/bin/bash
# Define file paths and directories

# I did two subject lists in order:
# All subjects: "$myoak/2025_mdsihvb_ad/data/subjectlist/subjlist_hcp_upmc_all.txt"
# Subjects that need to rerun: "$myoak/2025_mdsihvb_ad/data/subjectlist/rerun_nii2bids_subj_wt_two_WM.txt"

# Define file paths and directories
SUBJ_LIST="./subjlist.txt"
RAW_NII='./nii_dir'
BIDS_DIR="./bids_dir"
JSON_MAPPING="bids_mapping.json"
LOG_DIR="${BIDS_DIR}/nii_logs"

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
    ./symlink_nii_to_bids.sh "$RAW_NII" "$BIDS_DIR" "$subject" "$JSON_MAPPING" > "$logfile" 2>&1
    echo "Subject $subject processed. Log saved to $logfile"
done

echo "All subjects processed successfully."
