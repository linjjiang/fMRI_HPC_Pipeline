% Task Design Extraction - to create BIDS-compatible TSV files
% Linjing Jiang
% Mar-24-2025
% Version 3 - Creating BIDS-COMPATIBLE TSV files with -half_TR shift on EVENT onsets

%%%%%%%%%%%%%%%%%%%% IMPORTANT, READ BEFORE PROCEEDING %%%%%%%%%%%%%%%%

% If you use fMRIprep to perform slice-timing correction, you have to
% shift the event onset by -TR/2 in your model. The rationale is
% that fMRIprep performs STC using the AFNI 3dTshift function, which uses
% the middle slice as the reference. 

% More discussions:
% https://reproducibility.stanford.edu/slice-timing-correction-in-fmriprep-and-linear-modeling/
% https://fmriprep.org/en/latest/outputs.html#outputs-of-fmriprep 

% In this version of the script, I shifted the event onset by -TR/2 as it 
% will be used for customized causal connectivity analysis. 

% And I further removed 3.2 s at the very beginning as dummy scans during the hcp_upmc_task_design.m scripts
% (which matched what I did during fMRIPrep preprocessing. 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear
close all
clc

%% Directories
% Original task design files
input_dir = './behav_dir';

output_dir = input_dir;
TR = 0.8; % Change this value if your TR is different (in seconds)
shift_event_onset = 1; % Yes I want to shift the event onset.

if shift_event_onset % Do you want to shift the event onset?
    half_TR = TR/2; % yes
else
    half_TR = 0; % no
end

diary(fullfile(output_dir,'task_design_log_events.txt'))   % Start logging everything
disp('This will be saved in the log.')

%% Look through all subjects and sessions and convert to TSV file

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
                    % Get list of behavioral events files (e.g., *_behav.mat)
                    event_files = dir(fullfile(func_path, '*_behav.mat'));

                    for iFile = 1:length(event_files)
                        file_path = fullfile(func_path, event_files(iFile).name);
                        fprintf('Processing file: %s\n', file_path);
                        
                        try
                            load(file_path);
                            
                            % --- Convert Behavioral Data to BIDS-compatible Events TSV ---
                            % Behavioral data is stored in a table "triallist" and the
                            % resting period variables "rest_onset" and "rest_dur".
                            % All onsets are shifted by -half_TR (i.e., subtracted) to match
                            % the fmriprep slice timing correction reference.
                            
                            % Create an event row for the resting period (shift onset)
                            rest_event = table(rest_onset - half_TR, ...
                                repmat(rest_dur,4,1), repmat({'rest'},4,1), ...
                                'VariableNames', {'onset', 'duration', 'trial_type'});
                            
                            % Filter trial rows for 0-back and 2-back trials
                            % (i.e., trials where nbackLoad is either 0 or 2)
                            idx_trials = ismember(triallist.nbackLoad, [0, 2]);
                            trial_events_raw = triallist(idx_trials, :);
                            
                            % Initialize a cell array to store trial type labels
                            nTrials = height(trial_events_raw);
                            trial_type = cell(nTrials, 1);
                            
                            % Loop through each trial to assign the appropriate trial type
                            for i = 1:nTrials
                                if trial_events_raw.nbackLoad(i) == 0
                                    trial_type{i} = '0bk';
                                elseif trial_events_raw.nbackLoad(i) == 2
                                    trial_type{i} = '2bk';
                                end
                            end
                            
                            % Create the trial events table using stimOnset (shifted) and stimDur for each trial
                            trial_events = table(trial_events_raw.stimOnset - half_TR, trial_events_raw.stimDur, trial_type, ...
                                'VariableNames', {'onset', 'duration', 'trial_type'});
                            
                            % Combine the rest event and trial events into a single events table
                            events = [rest_event; trial_events];
                            
                            % Sort events by the onset time (optional but recommended)
                            events = sortrows(events, 'onset');
                            
                            % I want to only keep the onset of
                            % each block
                            events_block = events([1,11,21,22,32,42,43,53, ...
                                63,64,74,84],:);
                            events_block.duration = repmat([25,25,15]',4,1);

                            % Construct output file names
                            [folder, name, ext] = fileparts(file_path);                            
                            % Replace '_behav' with '_events' in the base filename
                            new_name = strrep(name, '_behav', '_events');
                            % Create the new file path with the .tsv extension
                            output_filename = fullfile(folder, [new_name, '.tsv']);
                            
                            % Write the events table to a BIDS-compatible TSV file
                            % save events_block instead of events
                            writetable(events_block, output_filename, 'FileType', 'text', 'Delimiter', '\t');
                            
                            fprintf('BIDS events file saved as: %s\n', output_filename);
                            
                        catch ME
                            fprintf('Error reading %s: %s\n', file_path, ME.message);
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
