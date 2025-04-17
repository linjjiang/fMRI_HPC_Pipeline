#!/bin/bash
# Customized BIDS Conversion Script for HCP UPMC (Single Subject Mode)
# Linjing Jiang, 03-25-2025
# Usage: ./symlink_nii_to_bids.sh <source_root> <bids_root> <subject_id> <json_mapping>

# Helper function to check if a file exists.
# If the file is a symlink, also check if its target exists.
file_exists() {
    local file="$1"
    if [ -L "$file" ]; then
        local target
        target=$(readlink -f "$file")
        if [ -n "$target" ] && [ -e "$target" ]; then
            return 0
        else
            return 1
        fi
    else
        [ -e "$file" ]
    fi
}

symlink_to_bids_hcp_upmc_single() {
    local source_root="$1"
    local bids_root="$2"
    local subj="$3"
    local json_mapping="$4"
#    local behav_root="$5"

#    if [ "$#" -ne 5 ]; then
    if [ "$#" -ne 4 ]; then
        echo "Customized BIDS Conversion Script for NII files (Single Subject Mode)"
        echo "Usage: ./symlink_nii_to_bids.sh <source_root> <bids_root> <subject_id> <json_mapping>"
        return 1
    fi

    mkdir -p "$bids_root"

    local directions=($(jq -r '.directions[]' "$json_mapping"))
    local tasks=($(jq -r '.tasks[]' "$json_mapping"))
    local sessions=($(jq -r '.sessions[]' "$json_mapping"))
    local runs=($(jq -r '.runs[]' "$json_mapping"))

    echo "Processing subject: $subj"
    for session in "${sessions[@]}"; do
        has_task_data=false
        for modality in func sbref; do
            src_pattern_modality=$(jq -r ".${modality}.source" "$json_mapping")
            for task in "${tasks[@]}"; do
                for dir in "${directions[@]}"; do
                    for run in "${runs[@]}"; do
                        candidate=$(echo "$src_pattern_modality" | sed "s/{subject}/$subj/g;s/{session}/$session/g;s/{task}/$task/g;s/{direction}/$dir/g;s/{run}/$run/g")
                        files=($(find "$source_root" -path "$source_root/$candidate"))
                        if [ "${#files[@]}" -gt 0 ]; then
                            has_task_data=true
                            break 4
                        fi
                    done
                done
            done
        done

        if [ "$has_task_data" = false ]; then
            echo "No task data found for subject $subj in session $session. Skipping session."
            continue
        fi

        # Anatomical image
        anat_src=$(jq -r '.anat.source' "$json_mapping" | sed "s/{subject}/$subj/g;s/{session}/$session/g")
        anat_dst=$(jq -r '.anat.dest' "$json_mapping" | sed "s/{subject}/$subj/g;s/{session}/$session/g")
        anat_files=($(find "$source_root" -path "$source_root/$anat_src"))
        if [ "${#anat_files[@]}" -gt 0 ]; then
            # Sort the found anatomical files using version sort and pick the last one.
            last_anat=$(printf "%s\n" "${anat_files[@]}" | sort -V | tail -n 1)
            mkdir -p "$(dirname "$bids_root/$anat_dst")"
            ln -sf "$last_anat" "$bids_root/$anat_dst"
            echo "Anat symlinked: $last_anat -> $bids_root/$anat_dst"
        fi

        # Anatomical JSON
        anat_json_src=$(jq -r '.anat_json.source' "$json_mapping" | sed "s/{subject}/$subj/g;s/{session}/$session/g")
        anat_json_dst=$(jq -r '.anat_json.dest' "$json_mapping" | sed "s/{subject}/$subj/g;s/{session}/$session/g")
        anat_json_files=($(find "$source_root" -path "$source_root/$anat_json_src"))
        if [ "${#anat_json_files[@]}" -gt 0 ]; then
            # Sort and pick the last anatomical JSON file
            last_anat_json=$(printf "%s\n" "${anat_json_files[@]}" | sort -V | tail -n 1)
            mkdir -p "$(dirname "$bids_root/$anat_json_dst")"
            ln -sf "$last_anat_json" "$bids_root/$anat_json_dst"
            echo "Anat JSON symlinked: $last_anat_json -> $bids_root/$anat_json_dst"
        fi


        # Func & SBRef (and their JSONs)
        for modality in func sbref; do
            src_pattern=$(jq -r ".${modality}.source" "$json_mapping")
            dst_pattern=$(jq -r ".${modality}.dest" "$json_mapping")
            src_json_pattern=$(jq -r ".${modality}_json.source" "$json_mapping")
            dst_json_pattern=$(jq -r ".${modality}_json.dest" "$json_mapping")

            for task in "${tasks[@]}"; do
                for dir in "${directions[@]}"; do
                    for run in "${runs[@]}"; do
                        padded_run=$(printf "%02d" "$run")

                        src=$(echo "$src_pattern" | sed "s/{subject}/$subj/g;s/{session}/$session/g;s/{task}/$task/g;s/{direction}/$dir/g;s/{run}/$run/g")
                        dst=$(echo "$dst_pattern" | sed "s/{subject}/$subj/g;s/{session}/$session/g;s/{task}/$task/g;s/{direction}/$dir/g;s/{run}/$padded_run/g")

                        # Use find to gather all matching files
                        files=($(find "$source_root" -path "$source_root/$src"))
                        if [ "${#files[@]}" -gt 0 ]; then
                            # Sort files using version sort and pick the last file
                            last_file=$(printf "%s\n" "${files[@]}" | sort -V | tail -n 1)
                            mkdir -p "$(dirname "$bids_root/$dst")"
                            ln -sf "$last_file" "$bids_root/$dst"
                            echo "$modality symlinked: $last_file -> $bids_root/$dst"
                        fi

                        # Process JSON files with metadata (TaskName)
                        src_json=$(echo "$src_json_pattern" | sed "s/{subject}/$subj/g;s/{session}/$session/g;s/{task}/$task/g;s/{direction}/$dir/g;s/{run}/$run/g")
                        dst_json=$(echo "$dst_json_pattern" | sed "s/{subject}/$subj/g;s/{session}/$session/g;s/{task}/$task/g;s/{direction}/$dir/g;s/{run}/$padded_run/g")
                        json_files=($(find "$source_root" -path "$source_root/$src_json"))
                        if [ "${#json_files[@]}" -gt 0 ]; then
                            mkdir -p "$(dirname "$bids_root/$dst_json")"
                            # Also sort JSON files, just in case
                            last_json=$(printf "%s\n" "${json_files[@]}" | sort -V | tail -n 1)
                            cp "$last_json" "$bids_root/$dst_json"
                            taskname=$task
                            jq ". + {\"TaskName\": \"$taskname\"}" "$bids_root/$dst_json" > "$bids_root/$dst_json.tmp" && mv "$bids_root/$dst_json.tmp" "$bids_root/$dst_json"
                            echo "$modality JSON with TaskName -> $bids_root/$dst_json"
                        fi
                    done
                done
            done
        done


        # Field maps (fmap and fmap_json)
        for dir in "${directions[@]}"; do
            # Fmap image
            fmap_src=$(jq -r '.fmap.source' "$json_mapping" | sed "s/{subject}/$subj/g;s/{session}/$session/g;s/{direction}/$dir/g")
            fmap_dst=$(jq -r '.fmap.dest' "$json_mapping" | sed "s/{subject}/$subj/g;s/{session}/$session/g;s/{direction}/$dir/g")
            fmap_files=($(find "$source_root" -path "$source_root/$fmap_src"))
            if [ "${#fmap_files[@]}" -gt 0 ]; then
                # Sort and select the last fmap file
                last_fmap=$(printf "%s\n" "${fmap_files[@]}" | sort -V | tail -n 1)
                mkdir -p "$(dirname "$bids_root/$fmap_dst")"
                ln -sf "$last_fmap" "$bids_root/$fmap_dst"
                echo "Fmap symlinked: $last_fmap -> $bids_root/$fmap_dst"
            fi

            # Fmap JSON file with IntendedFor metadata (using templates from JSON mapping metadata)
            fmap_json_src=$(jq -r '.fmap_json.source' "$json_mapping" | sed "s/{subject}/$subj/g;s/{session}/$session/g;s/{direction}/$dir/g")
            fmap_json_dst=$(jq -r '.fmap_json.dest' "$json_mapping" | sed "s/{subject}/$subj/g;s/{session}/$session/g;s/{direction}/$dir/g")
            fmap_json_files=($(find "$source_root" -path "$source_root/$fmap_json_src"))
            if [ "${#fmap_json_files[@]}" -gt 0 ]; then
                # Sort and select the last fmap JSON file
                last_fmap_json=$(printf "%s\n" "${fmap_json_files[@]}" | sort -V | tail -n 1)
                mkdir -p "$(dirname "$bids_root/$fmap_json_dst")"
                cp "$last_fmap_json" "$bids_root/$fmap_json_dst"

                # Build IntendedFor array using task-specific replacements from metadata field in JSON mapping
                intendedForTemplates=($(jq -r '.fmap_json.metadata.IntendedFor[]' "$json_mapping"))
                intendedForValues=()
                for template in "${intendedForTemplates[@]}"; do
                    v=$(echo "$template" | sed "s/{subject}/$subj/g;s/{session}/$session/g")
                    echo "$v"
                    if file_exists "$bids_root/sub-$subj/$v"; then
                        intendedForValues+=("$v")
                    fi
                done
                if [ "${#intendedForValues[@]}" -gt 0 ]; then
                    intendedForJson=$(printf '%s\n' "${intendedForValues[@]}" | jq -R . | jq -s .)
                    jq --argjson intendedFor "$intendedForJson" '. + {"IntendedFor": $intendedFor}' "$bids_root/$fmap_json_dst" > "$bids_root/$fmap_json_dst.tmp" && mv "$bids_root/$fmap_json_dst.tmp" "$bids_root/$fmap_json_dst"
                    echo "Fmap JSON updated with IntendedFor -> $bids_root/$fmap_json_dst"
                else
                    echo "No corresponding func file found for IntendedFor in fmap JSON update for subject $subj, session $session, direction $dir."
                fi
            fi
        done

    done  # <-- Add this line to close the "for session" loop

    echo "All symbolic links created successfully."
}

symlink_nii_to_bids "$@"
