#!/bin/bash
# Stage 2b: lay converted NIfTIs out as a BIDS dataset, one subject at a time.
#
# To re-run a subset, point SUBJECT_LIST in config/pipeline.env at a smaller
# list rather than editing this script.

set -uo pipefail
stage_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${stage_dir}/../../config/load_config.sh"

SUBJ_LIST="$SUBJECT_LIST"
RAW_NII="$NIFTI_DIR"
BIDS_DIR="$BIDS_DIR"
JSON_MAPPING="${stage_dir}/$(basename "$BIDS_MAPPING_JSON")"
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
    "${stage_dir}/symlink_nii_to_bids.sh" "$RAW_NII" "$BIDS_DIR" "$subject" "$JSON_MAPPING" > "$logfile" 2>&1
    echo "Subject $subject processed. Log saved to $logfile"
done

echo "All subjects processed successfully."
