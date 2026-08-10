#!/bin/bash
# Stage 1a: scan the raw DICOM tree and emit the list of subject IDs.
# Output contains subject identifiers -- it is written outside the repo.

set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/config/load_config.sh"

base_dir="$DICOM_DIR"
output_file="$SUBJECT_LIST"
mkdir -p "$(dirname "$output_file")"

# Initialize an empty list
subj_list=()

# Loop through all subdirectories in base_dir
for subj_folder in "$base_dir"/*; do
    if [ -d "$subj_folder" ]; then
        subj_id=$(basename "$subj_folder")
        # Check if the subfolder matches the expected pattern (numeric subject ID)
        if [[ "$subj_id" =~ ^[0-9]+$ ]]; then
            subj_list+=("$subj_id")
        fi
    fi
done

# Sort and remove duplicates
sorted_unique_list=$(printf "%s\n" "${subj_list[@]}" | sort -u)

# Write to output file with header
echo "pID" > "$output_file"
echo "$sorted_unique_list" >> "$output_file"

echo "✅ Subject list with header saved to $output_file"
