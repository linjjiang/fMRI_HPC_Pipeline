#!/bin/bash
# Author: Linjing Jiang
# Date: 03-25-2025 (Updated)
# Description:
#   Converts DICOM to NIfTI for a specific subject-session pair
#   based on direct inputs from the session mapping file.

subject_id="$1"
session_date="$2"
session_num="$3"
input_dir="$4"
output_dir="$5"

echo "🔄 Running dcm2niix_func"
echo "Subject: $subject_id | Session date: $session_date | Session num: $session_num"
echo "Input dir: $input_dir"
echo "Output dir: $output_dir"

if [ "$#" -ne 5 ]; then
    echo "Usage: $0 <subject_id> <session_date> <session_num> <input_dir> <output_dir>"
    exit 1
fi

if ! command -v dcm2niix &> /dev/null; then
    echo "❌ dcm2niix not found"
    exit 1
fi

orig_dir="${input_dir}/${subject_id}/${subject_id}_${session_date}/scans"
if [ ! -d "$orig_dir" ]; then
    echo "⚠️ No scans directory for ${subject_id}_${session_date}"
    exit 0
fi

# Check if any valid dicom data exists
has_data=0
for scan_dir in "$orig_dir"/*; do
    dicom_dir="${scan_dir}/resources/DICOM/files"
    if [ -d "$dicom_dir" ] && [ "$(ls -A "$dicom_dir")" ]; then
        has_data=1
        break
    fi
done

if [ $has_data -eq 0 ]; then
    echo "⚠️ No DICOM data found for ${subject_id}_${session_date}"
    exit 0
fi

# Set up output directory
nii_dir="${output_dir}/sub-${subject_id}/ses-${session_num}"
mkdir -p "$nii_dir"

# Convert each scan
for scan_dir in "$orig_dir"/*; do
    dicom_dir="${scan_dir}/resources/DICOM/files"
    if [ -d "$dicom_dir" ] && [ "$(ls -A "$dicom_dir")" ]; then
        scan_name=$(basename "$scan_dir")
        echo "🧠 Converting scan: $scan_name"
        dcm2niix -z y -f "%s_%d" -o "$nii_dir" "$dicom_dir"
    fi
done

echo "✅ Done with $subject_id $session_date (ses-$session_num)"
