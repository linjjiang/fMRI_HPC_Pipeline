function extract_behav_long(filepath,output_dir,sess_map_dir,subjectID,runNumber,direction,discard_time)
% Let's now load the data manually
fid = fopen(filepath, 'r');
if fid == -1
    error('Could not open file %s', filepath);
end

% Read all lines into a cell array
data = textscan(fid, '%s', 'Delimiter', '\n');
fclose(fid);

%%
% Convert from long to wide format
% Suppose 'lines' is a cell array of strings you obtained using textscan:

%--- Step 1: Read file into a cell array of lines (if not already done) ---
lines = data{1};

%--- Step 2: Find indices for trial blocks ---
% Here we assume each trial block is delimited by these markers:
startIdx = find(contains(lines, '*** LogFrame Start ***'));
endIdx   = find(contains(lines, '*** LogFrame End ***'));

if numel(startIdx) ~= numel(endIdx)
    error('Mismatched start and end markers. Please check file format.');
end

numTrials = numel(startIdx);
trialStructs = cell(numTrials, 1);  % cell array to hold each trial's structure

%--- Step 3: Parse each trial block ---
for i = 1:numTrials
    % Get the lines in the current trial block (exclude the marker lines)
    blockLines = lines(startIdx(i)+1 : endIdx(i)-1);
    trialData = struct();
    
    for j = 1:numel(blockLines)
        currentLine = strtrim(blockLines{j});
        if isempty(currentLine)
            continue;
        end
        
        % Split on the first colon (':')
        colonLoc = strfind(currentLine, ':');
        if isempty(colonLoc)
            continue; % Skip lines without a colon
        end
        
        % Get key and value, and trim whitespace
        key = strtrim(currentLine(1:colonLoc(1)-1));
        value = strtrim(currentLine(colonLoc(1)+1:end));
        
        % Make key a valid MATLAB field name
        key = matlab.lang.makeValidName(key);
        
        % If value is numeric, convert it; otherwise keep as string
        numVal = str2double(value);
        if ~isnan(numVal)
            value = numVal;
        end
        
        % Add the field to the trialData structure
        trialData.(key) = value;
    end
    trialStructs{i} = trialData;
end

%--- Step 4: Compute the union of all field names across trials ---
allFields = {};
for i = 1:numTrials
    allFields = union(allFields, fieldnames(trialStructs{i}));
end

%--- Step 5: Create a table from the cell array of structures ---
T = table();
for i = 1:length(allFields)
    fieldName = allFields{i};
    % Preallocate a cell array for the column data
    colData = cell(numTrials, 1);
    for j = 1:numTrials
         if isfield(trialStructs{j}, fieldName)
              colData{j} = trialStructs{j}.(fieldName);
         else
              colData{j} = []; % If desired, you could also use NaN for numeric fields
         end
    end
    % Assign the column to the table
    T.(fieldName) = colData;
end

%% Calculate output directory

 % map session number
% check session date from the behavioral file
sess_date = T.SessionDate{end};
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
sess_num = sess_map.string_sess_num(sess_map.string_id == subjectID & ...
    sess_map.string_sess_date == sess_date);
sess_num = char(sess_num);

% if this mapping is not found (meaning that there is no fMRI data)
% we skip this subject
if isempty(sess_num)
    fprintf('%s has no corresponding fMRI data. \n',filepath);
    return;
end

% output directory and files
task_design_dir = fullfile(output_dir,...
    ['sub-' subjectID],['ses-',sess_num],'func');

if ~isfolder(task_design_dir)
    mkdir(task_design_dir);
    % else
    %     rmdir(task_design_dir,'s');
    %     mkdir(task_design_dir);
end

run_name_pad = pad(runNumber, 2, 'left', '0');
task_design_file = fullfile(task_design_dir,...
    ['sub-' subjectID '_ses-' sess_num '_task-WM_dir-' direction '_run-' run_name_pad '_behav.mat']); % tsv file if using fmriprep


%% Now let's extract behavioral data from those files

target_types={'target','lure','nonlure'};
stim_types={'Face','Body','Tools','Place'};

% trial ids
sel_trial_ids = logical(strcmp(T.Procedure, 'TrialsPROC'));

if sum(sel_trial_ids)==80

    discard_tp=T.SyncSlide_OnsetTime{1};

    RT=convert_cell_2_mat(T.Stim_RT(sel_trial_ids));
    response=convert_cell_2_mat(T.Stim_RESP(sel_trial_ids));
    ACC=convert_cell_2_mat(T.Stim_ACC(sel_trial_ids));
    correctResponse=convert_cell_2_mat(T.CorrectResponse(sel_trial_ids));

    stimType_tmp=T.StimType(sel_trial_ids);

    stim=T.Stimulus(sel_trial_ids); 

    stimOnset = convert_cell_2_mat(T.Stim_OnsetTime(sel_trial_ids));
    stimOnset=((stimOnset-discard_tp)./1000)-discard_time;

    blockType_tmp=T.BlockType(sel_trial_ids);

    nbackLoad=zeros(80,1);
    targetType=nbackLoad;
    stimType=nbackLoad;

    nbackLoad(ismember(blockType_tmp,'2-Back'))=2;
    nbackLoad(ismember(blockType_tmp,'0-Back'))=0;

    targetType_tmp=T.TargetType(sel_trial_ids);

    for i = 1:length(target_types)
        targetType(ismember(targetType_tmp,target_types{i}))=i;
    end

    for i = 1:length(stim_types)
        stimType(ismember(stimType_tmp,stim_types{i}))=i;
    end

    trialID=[1:length(RT)]';
    blockNumID=reshape(repmat([1:8],10,1),80,1);

    % want to find the cue onset
    procedure = T.Procedure; procedure(end) = [];

    sel_cue_ids_tmp=ismember(procedure,'Cue2BackPROC')|ismember(procedure,'Cue0BackPROC');
    sel_cue_ids=find(sel_cue_ids_tmp);
    cueStim_tmp=T.Stimulus(sel_cue_ids);
    cueStim=[];
    cueOnset=[];


    for i = 1:numel(cueStim_tmp)

        repeated_element = repmat(cueStim_tmp(i), 10, 1);

        cueStim = [cueStim; repeated_element];
        if isempty(cueStim_tmp{i})
            repeated_onset = repmat(cell2mat(T.Cue2Back_OnsetTime(sel_cue_ids(i))), 10, 1);
        else
            repeated_onset = repmat(cell2mat(T.CueTarget_OnsetTime(sel_cue_ids(i))), 10, 1);
        end
        cueOnset = [cueOnset; repeated_onset];

    end
    cueOnset=((cueOnset-discard_tp)./1000)-discard_time;
    cueDur=ones(80,1).*2.5;
    stimDur=ones(80,1).*2;

    rest_onset = cell2mat(T.Fix15sec_OnsetTime);
    rest_onset=((rest_onset-discard_tp)./1000)-discard_time;
    rest_dur=15;

    triallist = table(trialID,stim,stimOnset,stimDur,stimType,nbackLoad,targetType,blockNumID,cueStim,cueOnset,cueDur,response,ACC,correctResponse,RT);
    
    save(task_design_file,"triallist",'rest_dur','rest_onset','stim_types','target_types');

end