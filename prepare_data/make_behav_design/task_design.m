% HCP Pittsburgh Task Design Extraction
% Extract task design and behav data from the raw txt files
% Based on Zhiyao Gao's script
% Linjing Jiang
% Mar-31-2025

% Extract task design from raw txt files, which are either 1) in wide
% format '_TAB.txt' or 2) in long format '.txt'. Either works. 

% Notice that I removed 3.2s at the very beginning as dummy scans. This
% corresponds to discarding the first 4 volumes during fMRI preprocessing
% (TR = 0.8 s for the HCP UPMC Pittsburgh dataset, so 4 volumes = 3.2s).

clear
close all
clc

%% Test on one subject

% Original task design files
input_dir = './EDAT_fMRI';
input_dir2 = './EDAT_fMRI2';
output_dir = './behav_dir';

sess_map_dir='./session_map.txt';
discard_time = 3.2;

subjlist = readtable('./subjlist.txt');
phasedirs = {'AP','PA'};
runnames = {'1','2'};

subjlist_nobehav = [];

diary(fullfile(output_dir,'task_design_log.txt'))   % Start logging everything
diary on
disp('This will be saved in the log.')

for ss = 1:size(subjlist,1)
    subj_id = num2str(subjlist{ss,1});
    for pp = 1:2 % phase
        phasedir = phasedirs{pp};
        run_name = runnames{pp};

        % get txt file path
        txt_file = dir(fullfile(input_dir,['XX',subj_id,'_BOLD_XX_run',run_name,'_',phasedir,'_TAB.txt']));

        % if there's no such file
        if isempty(txt_file)

            % we are trying to find the corresponding file in another input
            % folder
            txt_file = dir(fullfile(input_dir2,subj_id,'visit*','session*','fmri','run*','behav',['XX',subj_id,'_XX_run',run_name,'_',phasedir,'_TAB.txt']));

            if isempty(txt_file) % if another input folder also doesn't have this file

                % We are trying to find other type of behavioral files -
                % long format
                txt_file_long = dir(fullfile(input_dir,['XX',subj_id,'_BOLD_XX_run',run_name,'_',phasedir,'.txt']));

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
