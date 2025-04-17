# %%
import numpy as np

# %%
data = np.load('/scratch/users/ljjiang/hcp_upmc_mdsi/ts_all_wt_fieldmap/sub-225_ses-01_ts.npz',allow_pickle=True)

# %%
print(data)

# %%
print(data['ts_array'].shape)
print(data['ts_array'][0,:,0])

# %%
print(type(data['ts_array'][0,:,0]))
# %%
print(data['run_ids'])
print(data['roi_ids'])
print(data['task_designs'])

# %%

# Retrieve the task designs dictionary (it is stored as an object, so use .item())
task_designs = data['task_designs'].item()
print(task_designs)

# Now you can access task designs for each run.
# For example, to get the '2bk' onsets for run_01_dir_AP:
onsets_run1_2bk = task_designs['run_01_dir_AP']['2bk']['onset']
print("Run 1, 2bk onsets:", onsets_run1_2bk)
print(type(onsets_run1_2bk))

onsets_run1_0bk = task_designs['run_01_dir_AP']['0bk']['onset']
print("Run 1, 0bk onsets:", onsets_run1_0bk)

onsets_run1_rest = task_designs['run_01_dir_AP']['rest']['onset']
print("Run 1, rest onsets:", onsets_run1_rest)

# Similarly, for run_02_dir_PA, you might do:
onsets_run2_2bk = task_designs['run_02_dir_PA']['2bk']['onset']
print("Run 2, 2bk onsets:", onsets_run2_2bk)

# %%
print(data['ts_array'][0,:,0].shape)
ts = data['ts_array'][0,:,0]
print(ts.mean())
print(ts.std())

# %%
