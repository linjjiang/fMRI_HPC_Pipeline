#!/bin/bash
# Recovery helper: scan stage-2 job logs for array tasks killed by the walltime
# limit, and re-emit them as a session map so they can be resubmitted with a
# longer --time. Feed the result back into submit_dcm2nii_job.sh.

set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/config/load_config.sh"

logs_dir="${NIFTI_DIR}/logs"
output_file="${WORK_DIR}/timed_out_sessions.txt"

# Write header
echo "pID,session_date,session_num" > "$output_file"

# Search and extract info
grep -rl --include='*.err' "DUE TO TIME LIMIT" "$logs_dir" | while read -r err_file; do
  out_file="${err_file%.err}.out"
  if [ -f "$out_file" ]; then
    first_line=$(head -n 1 "$out_file")
    if [[ $first_line =~ Processing\ subject:\ ([0-9]+)\ \|\ session:\ ([0-9]+)\ \(ses-([0-9]+)\) ]]; then
      pid="${BASH_REMATCH[1]}"
      date="${BASH_REMATCH[2]}"
      ses_num="${BASH_REMATCH[3]}"
      echo "$pid,$date,$ses_num" >> "$output_file"
    fi
  fi
done
