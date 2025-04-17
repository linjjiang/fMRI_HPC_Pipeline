This folder contains Linjing's matlab script that generates different behavioral and task design files
Linjing Jiang
Mar-25-2025

task_design.m: The first script that you need to run to convert raw fMRI behavioral outputs (.txt) to a .mat files

task_design_bids.m: You can run this script after running the previous scripts. 
    This script is to generate the bids-compatible event tsv files.
    Note: event onsets have been shifted by -TR/2 to match the fMRIprep slice timing correction routine. Check scripts for more details.

task_design_spm.m: Run this only after running the previous scripts. 
    This script generates SPM-compatible task design mat files.
    Note: event onsets have not been shifted. However, please check the microtime onset in the SPM GLM model to make sure
          it is set to the middle slice.