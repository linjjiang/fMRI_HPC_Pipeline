#!/bin/bash
# Stage 1b: map each subject's scan dates to sequential session numbers.
# Output contains subject IDs AND scan dates -- written outside the repo, and
# only the session NUMBER is ever carried forward into BIDS filenames.

set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/config/load_config.sh"

base_dir="$DICOM_DIR"
output_file="$SESSION_MAP"
mkdir -p "$(dirname "$output_file")"

# Write header
echo "pID,session_date,session_num" > "$output_file"

# Loop through subject folders
for subj_path in "$base_dir"/*; do
    if [ -d "$subj_path" ]; then
        subj_id=$(basename "$subj_path")

        # Find all <subj>_<date> directories
        scan_dates=()
        for session_path in "$subj_path"/${subj_id}_*/; do
            [ -d "$session_path" ] || continue
            scan_dir="${session_path}/scans"

            # Only include if scans/ exists and is not empty
            if [ -d "$scan_dir" ] && [ "$(ls -A "$scan_dir")" ]; then
                session_folder=$(basename "$session_path")
                session_date="${session_folder#${subj_id}_}"
                scan_dates+=("$session_date")
            fi
        done

        # Sort scan dates and assign session numbers
        IFS=$'\n' sorted_dates=($(sort <<<"${scan_dates[*]}"))
        unset IFS
        for i in "${!sorted_dates[@]}"; do
            session_num=$(printf "%02d" $((i + 1)))
            echo "${subj_id},${sorted_dates[$i]},${session_num}" >> "$output_file"
        done
    fi
done

echo "✅ Session mapping saved to $output_file"
