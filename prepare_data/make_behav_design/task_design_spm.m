% Task Design Extraction - Create SPM-compatible Task Design Files
% Linjing Jiang
% Mar-24-2025
% Version 4 - Creating SPM Task Design Files

%%%%%%%%%%%%%%%%%%%% IMPORTANT, READ BEFORE PROCEEDING %%%%%%%%%%%%%%%%

% If you use fMRIprep to perform slice-timing correction, you have to
% double-check the microtime onset in your SPM GLM model. The rationale is
% that fMRIprep performs STC using the AFNI 3dTshift function, which uses
% the middle slice as the reference. So you need to make sure that in the
% SPM GLM, the reference slice is the middle slice too. Otherwise, you need
% to deliberately adjust the onset of the events by -TR/2.

% More discussions:
% https://reproducibility.stanford.edu/slice-timing-correction-in-fmriprep-and-linear-modeling/
% https://fmriprep.org/en/latest/outputs.html#outputs-of-fmriprep 

% In this version of the script, I did not shift the event onset for SPM
% design matrix as it will be fed into the SPM GLM analysis directly. So
% make sure you double-check the microtime resolution in your model!!!!

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear
close all
clc

%% Directories
% Original task design files
input_dir = './behav_dir';
output_dir = input_dir;
TR = 0.8; % CHANGE AS NEEDED
shift_event_onset = 0;

if shift_event_onset % Do you want to shift the event onset?
    half_TR = TR/2; % yes
else
    half_TR = 0; % no
end

diary(fullfile(output_dir,'task_design_log_spmDesign.txt'))   % Start logging everything
disp('This will be saved in the log.')

%% Look through all subjects and sessions and convert to SPM-compatible task design file

% Get list of subject directories (assuming they are named 'sub-*')
sub_dirs = dir(fullfile(input_dir, 'sub-*'));
for iSub = 1:length(sub_dirs)
    if sub_dirs(iSub).isdir
        sub_path = fullfile(input_dir, sub_dirs(iSub).name);
        
        % Get list of session directories (assuming they are named 'ses-*')
        ses_dirs = dir(fullfile(sub_path, 'ses-*'));
        for iSes = 1:length(ses_dirs)
            if ses_dirs(iSes).isdir
                ses_path = fullfile(sub_path, ses_dirs(iSes).name);
                
                % Define the func folder path
                func_path = fullfile(ses_path, 'func');
                if isfolder(func_path)
                    % Get list of behavioral files (e.g., *_behav.mat)
                    behav_files = dir(fullfile(func_path, '*_behav.mat'));
                    
                    for iFile = 1:length(behav_files)
                        file_path = fullfile(func_path, behav_files(iFile).name);
                        fprintf('Processing file: %s\n', file_path);
                        
                        try
                            % Load the behavioral data
                            % Assumes that variables 'triallist', 'rest_onset', and 'rest_dur'
                            % are present in the file.
                            load(file_path);
                            
                            % --- Create SPM Design Structure ---
                            
                            % Define condition names: resting, 0-back, and 2-back
                            names = {'rest', '0bk', '2bk'};
                            
                            % Rest periods (Shift onsets if needed)
                            rest_onsets = rest_onset - half_TR;
                            rest_durations = repmat(rest_dur,4,1);
                            
                            % For trial events, filter based on nbackLoad:
                            % 0-back and 2-back trials only.
                            idx0bk = (triallist.nbackLoad == 0);
                            idx2bk = (triallist.nbackLoad == 2);
                            
                            % Extract onsets and durations for 0-back trials (Shift onsets if needed)
                            onsets_0bk = triallist.stimOnset(idx0bk) - half_TR;
                            durations_0bk = triallist.stimDur(idx0bk);
                            
                            % Extract onsets and durations for 2-back trials (Shift onsets if needed)
                            onsets_2bk = triallist.stimOnset(idx2bk) - half_TR;
                            durations_2bk = triallist.stimDur(idx2bk);

                            % Build the SPM design structure
                            onsets = {rest_onsets, onsets_0bk, onsets_2bk};
                            durations = {rest_durations, durations_0bk, durations_2bk};
                            
                            % --- Construct output file name ---
                            % Replace '_behav' with '_spmDesign' in the base filename
                            [folder, name, ~] = fileparts(file_path);
                            new_name = strrep(name, '_behav', '_spmDesign');
                            output_filename = fullfile(folder, [new_name, '.mat']);
                            
                            % Save the SPM design structure to the output file
                            save(output_filename, 'names','onsets','durations');
                            
                            fprintf('SPM design file saved as: %s\n', output_filename);
                            
                        catch ME
                            fprintf('Error processing %s: %s\n', file_path, ME.message);
                        end
                        
                    end
                    
                else
                    fprintf('No func folder found in %s\n', ses_path);
                end
            end
        end
    end
end

diary off