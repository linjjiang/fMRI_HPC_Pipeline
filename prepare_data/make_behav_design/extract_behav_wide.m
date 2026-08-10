function extract_behav_wide(txt_file,output_dir,sess_map_dir,subj_id,run_name,phasedir,discard_time)

% load the data
txt_path = fullfile(txt_file.folder,txt_file.name);
data = readtable(txt_path); % do not add this-> ,'VariableNamingRule','preserve'

% check session date from the behavioral file
sess_date = data.SessionDate(1);
% Convert to a datetime object (the input format is MM-dd-yyyy)
dt = datetime(sess_date, 'InputFormat', 'MM-dd-yyyy');
% Convert the datetime object to a string in the format yyyyMMdd
sess_date = datestr(dt, 'yyyymmdd');

% load session mapping file
sess_map = readtable(sess_map_dir);
sess_map.Properties.VariableNames = {'id','sess_date','sess_num'};
sess_map = varfun(@string, sess_map, 'OutputFormat', 'table');
sess_map.string_sess_num = pad(sess_map.string_sess_num, 2, 'left', '0');

% 1) map behavioral data to specific session in the bids organization
sess_num = sess_map.string_sess_num(sess_map.string_id == subj_id & ...
    sess_map.string_sess_date == sess_date);
sess_num = char(sess_num);

run_name_pad = pad(run_name, 2, 'left', '0');

% if this mapping is not found (meaning that there is no fMRI data)
% we skip this subject
if isempty(sess_num)
    fprintf('%s has no corresponding fMRI data. \n',txt_path);
    return;
end

% output directory
task_design_dir = fullfile(output_dir,...
    ['sub-' subj_id],['ses-',sess_num],'func');

if ~isfolder(task_design_dir)
    mkdir(task_design_dir);
    % else
    %     rmdir(task_design_dir,'s');
    %     mkdir(task_design_dir);
end

task_design_file = fullfile(task_design_dir,...
    ['sub-' subj_id '_ses-' sess_num '_task-WM_dir-' phasedir '_run-' run_name_pad '_behav.mat']); % tsv file if using fmriprep


% 2) load behavioral data and retrieve task design
% modified from zhiyao's script

% To syncronize behavioral data and fMRI data, we subtract Syncslide.onset from
% stimilus's onset; and then we further 4s of discarding volumes time from this new
% onset time.
%                                                                  04/15/2023 zygao

% nbackload: 0 or 2
% stimType: 1-4, corresponding to face, body, tools, and place
% targetType: 1-3, corresponding to target, lure, and nonlure???
% blockNumID: block number, 1-8, rest followed by stimulus
% cue onset vs. stimulus onset??? -> fixation vs. stimulus??
% response: 2 or 3 or NAN
% ACC: accuray. 0 - inaccurate, 1 - accurate
% correctResponse: 2 or 3
% RT: reaction time in ms?


target_types={'target','lure','nonlure'};
stim_types={'Face','Body','Tools','Place'};

% trial ids
sel_trial_ids=data.CorrectResponse==2|data.CorrectResponse==3;

% if there are 80 trials in total
if sum(sel_trial_ids)==80
    discard_tp=data.SyncSlide_OnsetTime(1);


    RT=data.Stim_RT(sel_trial_ids);
    response=data.Stim_RESP(sel_trial_ids);
    ACC=data.Stim_ACC(sel_trial_ids);
    correctResponse=data.CorrectResponse(sel_trial_ids);
    stimType_tmp=data.StimType(sel_trial_ids);
    stim=data.Stimulus_Block_(sel_trial_ids);
    stimOnset=((data.Stim_OnsetTime(sel_trial_ids)-discard_tp)./1000)-discard_time;

    blockType_tmp=data.BlockType(sel_trial_ids);

    nbackLoad=zeros(80,1);
    targetType=nbackLoad;
    stimType=nbackLoad;

    nbackLoad(ismember(blockType_tmp,'2-Back'))=2;
    nbackLoad(ismember(blockType_tmp,'0-Back'))=0;

    targetType_tmp=data.TargetType(sel_trial_ids);

    for i = 1:length(target_types)
        targetType(ismember(targetType_tmp,target_types{i}))=i;
    end

    for i = 1:length(stim_types)
        stimType(ismember(stimType_tmp,stim_types{i}))=i;
    end

    trialID=[1:length(RT)]';
    blockNumID=reshape(repmat([1:8],10,1),80,1);

    sel_cue_ids_tmp=ismember(data.Procedure_Block_,'Cue2BackPROC')|ismember(data.Procedure_Block_,'Cue0BackPROC');
    sel_cue_ids=find(sel_cue_ids_tmp);
    cueStim_tmp=data.Stimulus_Block_(sel_cue_ids);
    cueStim=[];
    cueOnset=[];


    for i = 1:numel(cueStim_tmp)

        repeated_element = repmat(cueStim_tmp(i), 10, 1);

        cueStim = [cueStim; repeated_element];
        if isempty(cueStim_tmp{i})
            repeated_onset = repmat(data.Cue2Back_OnsetTime(sel_cue_ids(i)), 10, 1);
        else
            repeated_onset = repmat(data.CueTarget_OnsetTime(sel_cue_ids(i)), 10, 1);
        end
        cueOnset = [cueOnset; repeated_onset];

    end
    cueOnset=((cueOnset-discard_tp)./1000)-discard_time;
    cueDur=ones(80,1).*2.5;
    stimDur=ones(80,1).*2;

    rest_onset=((data.Fix15sec_OnsetTime(~isnan(data.Fix15sec_OnsetTime))-discard_tp)./1000)-discard_time;
    rest_dur=15;

    triallist = table(trialID,stim,stimOnset,stimDur,stimType,nbackLoad,targetType,blockNumID,cueStim,cueOnset,cueDur,response,ACC,correctResponse,RT);
    save(task_design_file,"triallist",'rest_dur','rest_onset','stim_types','target_types');

end

end