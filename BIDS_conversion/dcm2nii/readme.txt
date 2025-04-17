# This folder contains Linjing's script that converts dicom files to nifti files
# By: Linjing Jiang
# Version: 1.1.0
# Date: 03-25-2025

Updated main scripts:
dcm2niix_func.sh: use more complete data from a different folder

submit_dcm2nii_job: submit parallel jobs for dicom to nifti conversion
    Usage: bash submit_dcm2nii_job.sh 
    ****** USE BASH NOT SBATCH: *****
    ****** DO NOT USE sbatch submit_dcm2nii_job.sh AS THERE IS SBATCH COMMAND WITHIN THAT FILE. ********

extract_timed_out: extract subject id, session date and session number for subjects exceeding designated job time limit

# If you want to test a single subject:
./dcm2niix_func.sh ${subID} \
    ${dicom_path} \
    ${nifti_path} \
    ${session_map_file}


