#!/bin/bash
# Customized BIDS Conversion Script for HCP UPMC - Behavioral Data Only
# Linjing Jiang, 03-25-2025
#
# This script symlinks behavioral files from a BIDS-compatible behavioral folder (behav/)
# to the corresponding subject/session func/ folder in the imaging BIDS folder,
# but only if:
#   1) The corresponding behavioral file exists under the behavioral root.
#   2) The corresponding subject and session already has an imaging file under the
#      func/ folder in the target BIDS directory.
#   3) Multiple behavioral file types are supported: the "behav" domain in the JSON
#      mapping file defines arrays for both "source" and "dest" paths. For each index,
#      the first behavioral source is linked to the first behavioral destination, etc.
#
# Usage:
#   ./symlink_behav_to_bids.sh <behav_source_root> <bids_root> <subject_id> <json_mapping>

symlink_behav_to_bids() {
    local behav_root="$1"     # Source behavioral folder (e.g., .../hcp_upmc_raw_behav)
    local bids_root="$2"      # Target imaging BIDS folder (e.g., /scratch/users/ljjiang/hcp_upmc_bids)
    local subj="$3"           # Subject ID (e.g., sub-205)
    local json_mapping="$4"   # JSON mapping file

    if [ "$#" -ne 4 ]; then
        echo "Usage: ./symlink_behav_to_bids.sh <behav_source_root> <bids_root> <subject_id> <json_mapping>"
        return 1
    fi

    # Create the target BIDS folder if needed
    mkdir -p "$bids_root"

    # Get sessions, tasks, directions, and runs from the JSON mapping file
    local sessions=($(jq -r '.sessions[]' "$json_mapping"))
    local tasks=($(jq -r '.tasks[]' "$json_mapping"))
    local directions=($(jq -r '.directions[]' "$json_mapping"))
    local runs=($(jq -r '.runs[]' "$json_mapping"))

    # Read the behavioral mapping arrays.
    # These arrays should be defined in the JSON mapping file under the "behav" domain.
    mapfile -t behav_src_array < <(jq -r '.behav.source[]' "$json_mapping")
    mapfile -t behav_dst_array < <(jq -r '.behav.dest[]' "$json_mapping")
    local behav_count=${#behav_src_array[@]}

    echo "Processing behavioral files for subject: $subj"

    for session in "${sessions[@]}"; do
        echo "  Session: $session"
        # Condition 2: Check that imaging data exists under the func/ folder for this subject/session.
        local func_dir="${bids_root}/sub-${subj}/ses-${session}/func"
        local imaging_found
        imaging_found=$(find "$func_dir" -maxdepth 1 \( -type f -o -type l \) -name "*.nii.gz" 2>/dev/null)
        if [ -z "$imaging_found" ]; then
            echo "    No imaging file found under $func_dir; skipping behavioral symlink for this session."
            continue
        fi

        local session_processed=false
        # Loop over task, direction, and run.
        for task in "${tasks[@]}"; do
            for dir in "${directions[@]}"; do
                for run in "${runs[@]}"; do
                    local padded_run
                    padded_run=$(printf "%02d" "$run")
                    # For each behavioral file mapping (there could be multiple file types)
                    for ((i=0; i<behav_count; i++)); do
                        # Substitute placeholders in behavioral source and destination patterns.
                        local src_behav
                        local dst_behav
                        src_behav=$(echo "${behav_src_array[$i]}" | sed "s/{subject}/$subj/g;s/{session}/$session/g;s/{task}/$task/g;s/{direction}/$dir/g;s/{run}/$padded_run/g")
                        dst_behav=$(echo "${behav_dst_array[$i]}" | sed "s/{subject}/$subj/g;s/{session}/$session/g;s/{task}/$task/g;s/{direction}/$dir/g;s/{run}/$padded_run/g")
                        
                        echo $src_behav
                        # Look for matching behavioral file under the behavioral root.
                        local behav_files
                        IFS=$'\n' read -rd '' -a behav_files < <(find "$behav_root" -path "$behav_root/$src_behav" 2>/dev/null)
                        if [ "${#behav_files[@]}" -gt 0 ]; then
                            session_processed=true
                            mkdir -p "$(dirname "$bids_root/$dst_behav")"
                            ln -sf "${behav_files[-1]}" "$bids_root/$dst_behav"
                            echo "    Behavioral file symlinked: ${behav_files[-1]} -> $bids_root/$dst_behav"
                        else
                            echo "    No behavioral file found matching: $src_behav"
                        fi
                    done
                done
            done
        done
        if [ "$session_processed" = false ]; then
            echo "    No behavioral files processed for session $session."
        fi
    done

    echo "Behavioral symlinks creation completed for subject $subj."
}

symlink_behav_to_bids "$@"
