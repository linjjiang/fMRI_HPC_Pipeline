% Task Design Extraction
% Extract task design and behav data from the raw E-Prime txt files
% Based on Zhiyao Gao's script
% Linjing Jiang
% Mar-31-2025

% Extract task design from raw txt files, which are either 1) in wide
% format '_TAB.txt' or 2) in long format '.txt'. Either works.

% The first DUMMY_SCANS volumes are discarded at the start of each run, to
% match what fMRIPrep is told to discard in stage 3. discard_time is derived
% as DUMMY_SCANS * TR so the two can never drift apart.

clear
close all
clc

%% Configuration
addpath(fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'config'));
cfg = pipeline_config();

input_dir  = cfg.EPRIME_DIR_WIDE;
input_dir2 = cfg.EPRIME_DIR_LONG;
output_dir = cfg.BEHAV_DIR;

sess_map_dir = cfg.SESSION_MAP;
discard_time = cfg.DUMMY_SCANS_num * cfg.TR_num;   % seconds

subjlist = readtable(cfg.SUBJECT_LIST);
phasedirs = {'AP','PA'};
runnames = {'1','2'};

if ~isfolder(output_dir)
    mkdir(output_dir);
end

subjlist_nobehav = [];

diary(fullfile(output_dir,'task_design_log.txt'))   % Start logging everything
diary on
disp('This will be saved in the log.')

for ss = 1:size(subjlist,1)
    subj_id = num2str(subjlist{ss,1});
    for pp = 1:2 % phase
        phasedir = phasedirs{pp};
        run_name = runnames{pp};

        % Fill {subj}/{run}/{dir} into the configured filename patterns.
        fill = @(p) strrep(strrep(strrep(p, ...
            '{subj}', subj_id), '{run}', run_name), '{dir}', phasedir);

        % get txt file path
        txt_file = dir(fullfile(input_dir, fill(cfg.EPRIME_PATTERN_WIDE)));

        % if there's no such file
        if isempty(txt_file)

            % we are trying to find the corresponding file in another input
            % folder
            txt_file = dir(fullfile(input_dir2, fill(cfg.EPRIME_PATTERN_NESTED)));

            if isempty(txt_file) % if another input folder also doesn't have this file

                % We are trying to find other type of behavioral files -
                % long format
                txt_file_long = dir(fullfile(input_dir, fill(cfg.EPRIME_PATTERN_LONG)));

                if isempty(txt_file_long) % if no such file exists

                    fprintf('Subject %s WM Run %s has no behavioral data. Skip. \n',subj_id, run_name)
                    subjlist_nobehav = [subjlist_nobehav; [ss str2num(subj_id) pp]];
                    continue;
                end
            end

        end


        % if the file is wide format
        if ~isempty(txt_file)
            txt_files = txt_file;
            clear txt_file
            for tt = 1:size(txt_files,1)
                txt_file = txt_files(tt);
                extract_behav_wide(txt_file,output_dir,sess_map_dir,subj_id,run_name,phasedir,discard_time);
            end
        elseif ~isempty(txt_file_long)
            txt_files_long = txt_file_long;
            clear txt_file_long
            for tt = 1:size(txt_files_long,1)
                txt_file_long = txt_files_long(tt);
                extract_behav_long(txt_file_long,output_dir,sess_map_dir,subj_id,run_name,phasedir,discard_time);
            end
        else
            error('something is wrong')
        end


    end
end

diary off
