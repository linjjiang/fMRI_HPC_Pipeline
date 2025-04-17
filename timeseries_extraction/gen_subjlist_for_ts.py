# Subject list for timeseries extraction
# Linjing Jiang
# Mar-31-2025

# Create a subject & session list from overlapping subjects between preprocessing logs and complete behavioral data.

# Subjects completed preprocessing: ./successful_subjects.txt
#     It's a single-column file with subject id per row (starting from the first line)
# Subjects with complete behavioral data: ./sessions_complete_behav.txt
#     It's a two-column txt file with a header "pID session_num".

# I extracted the overlapping subjects between these two files (subjects that finished preprocessing AND with complete WM imaging and behavioral data), and outputed a new subject and session list file: /scratch/users/ljjiang/hcp_upmc_mdsi/ts_all_wt_fieldmap/subjlist.txt


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
# A header is included to mirror the input behavioral file format.
with open(output_file, 'w') as f:
    f.write("pID session_num\n")
    for pid, session_num in overlapping:
        f.write(f"{pid} {session_num}\n")


# %%
