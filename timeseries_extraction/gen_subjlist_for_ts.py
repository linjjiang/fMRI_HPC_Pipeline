# Subject list for timeseries extraction
# Linjing Jiang
# Mar-31-2025

# Create a subject & session list from overlapping subjects between preprocessing logs and complete behavioral data.

# Subjects completed preprocessing: successful_subjects.txt
#     Single-column file, one subject id per row, no header.
# Subjects with complete behavioral data: sessions_complete_behav.txt
#     Two-column file with a header "pID session_num".
#
# The output is the intersection: subjects that finished preprocessing AND have
# complete task imaging plus behavioral data. That list drives the stage-4 job
# array. Written WITHOUT a header, because submit_ts_extraction_job.slurm maps
# array task N to line N.


# %%
import os

# %%
# Define file paths
preprocessing_file = "./successful_subjects.txt"
behavioral_file = "./sessions_complete_behav.txt"
output_file = "./ts_subjlist.txt"

# %%
# Read subjects that completed preprocessing
with open(preprocessing_file, 'r') as f:
    preproc_subjects = {line.strip() for line in f if line.strip()}

# %%
print(preproc_subjects)
print(len(preproc_subjects))

# %%
# Read the behavioral file (skipping header) and collect subject and session info
behavioral_data = []
with open(behavioral_file, 'r') as f:
    header = f.readline()  # Skip header ("pID session_num")
    for line in f:
        parts = line.strip().split()
        if len(parts) >= 2:
            pid, session_num = parts[0], parts[1]
            behavioral_data.append((pid, session_num))

# %%
print(behavioral_data)
print(len(behavioral_data))

# %%
# Identify overlapping subjects: those present in both lists
overlapping = [(pid, session_num) for pid, session_num in behavioral_data if pid in preproc_subjects]
overlapping_subj = set([pid for pid, session_num in behavioral_data if pid in preproc_subjects])

print(overlapping_subj)

print(f"Found {len(overlapping_subj)} overlapping subjects out of {len(preproc_subjects)} preprocessed subjects.")

# %%
# Write the overlapping subjects and session numbers to the output file.
# No header: submit_ts_extraction_job.slurm maps SLURM_ARRAY_TASK_ID N to line
# N, so a header line would consume array task 1 on a bogus subject "pID".
with open(output_file, 'w') as f:
    for pid, session_num in overlapping:
        f.write(f"{pid} {session_num}\n")


# %%
