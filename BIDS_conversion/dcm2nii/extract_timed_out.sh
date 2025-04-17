#!/bin/bash

logs_dir="./output_dir/logs"
output_file="./timed_out_sessions.txt"

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
