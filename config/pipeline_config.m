function cfg = pipeline_config()
% PIPELINE_CONFIG  Read config/pipeline.env into a MATLAB struct.
%
%   Parses the same shell config the bash stages source, so paths are defined
%   in exactly one place and the two languages cannot drift apart.
%
%   Handles: KEY=value, KEY="value", KEY='value', trailing inline comments,
%   and ${VAR} references to keys defined earlier in the file.
%
%   cfg = pipeline_config();
%   cfg.BIDS_DIR, cfg.TR_num, ...

here = fileparts(mfilename('fullpath'));
env_file = getenv('PIPELINE_CONFIG');
if isempty(env_file)
    env_file = fullfile(here, 'pipeline.env');
end

if exist(env_file, 'file') ~= 2
    error('pipeline_config:missing', ...
        ['No config at %s\n' ...
         'Run: cp config/pipeline.env.example config/pipeline.env'], env_file);
end

cfg = struct();
fid = fopen(env_file, 'r');
if fid == -1
    error('pipeline_config:unreadable', 'Could not open %s', env_file);
end
cleaner = onCleanup(@() fclose(fid));

while true
    line = fgetl(fid);
    if ~ischar(line), break; end
    line = strtrim(line);
    if isempty(line) || line(1) == '#', continue; end

    tok = regexp(line, '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$', 'tokens', 'once');
    if isempty(tok), continue; end

    key = tok{1};
    val = strtrim(tok{2});
    if isempty(val)
        cfg.(key) = '';
        continue;
    end

    if val(1) == '"' || val(1) == ''''
        % Quoted: take everything up to the matching close quote, and ignore
        % any trailing inline comment.
        q = val(1);
        closeIdx = find(val(2:end) == q, 1, 'first');
        if isempty(closeIdx)
            val = val(2:end);          % unterminated quote; take the rest
        else
            val = val(2:closeIdx);     % content between the quotes
        end
    else
        % Unquoted: a '#' starts a comment.
        hashIdx = find(val == '#', 1, 'first');
        if ~isempty(hashIdx)
            val = strtrim(val(1:hashIdx-1));
        end
    end

    % Expand ${VAR} against keys already parsed.
    refs = regexp(val, '\$\{([A-Za-z_][A-Za-z0-9_]*)\}', 'tokens');
    for r = 1:numel(refs)
        name = refs{r}{1};
        if isfield(cfg, name)
            val = strrep(val, ['${' name '}'], cfg.(name));
        end
    end

    cfg.(key) = val;
end

% Numeric fields, converted for convenience.
numeric_keys = {'TR', 'HIGH_PASS', 'DUMMY_SCANS'};
for k = 1:numel(numeric_keys)
    name = numeric_keys{k};
    if isfield(cfg, name)
        cfg.([name '_num']) = str2double(cfg.(name));
    end
end
end
