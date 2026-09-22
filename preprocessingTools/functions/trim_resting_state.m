function [] = trim_resting_state(file, outputpath, EO_marker, EC_marker)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Epoch resting state EEG
% INPUTS:
%   file                   = EEG file
%   EO_marker (optional)   = event code for eyes open, auto 1
%   EC_marker (optional)   = event code for eyes closed, auto 0
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Defaults
if nargin < 4 || isempty(EO_marker)
    EO_marker = 1;
    fprintf('Using default EO marker: %d\n', EO_marker);
end
if nargin < 5 || isempty(EC_marker)
    EC_marker = 0;
    fprintf('Using default EC marker: %d\n', EC_marker);
end

%% Load EEG
[~, currentName, ~ ] = fileparts(file);
parts = split(currentName,'_');
subid = str2double(parts{1});
scandate = str2double(parts{2});
task = str2double(parts{3});
preprocVer = str2double(parts{4});

currentName = [parts{1} '_' parts{2} '_' parts{3} '_' parts{4}];

trimmedOpen = fullfile(outputpath, [currentName '_EyesOpen.set']);
trimmedClosed = fullfile(outputpath, [currentName '_EyesClosed.set']);

if exist(trimmedOpen, 'file') && exist(trimmedClosed, 'file')
    warning('%s Already trimmed this file!%s', currentName)
    return
end

if ischar(file) || isstring(file)
    EEG = pop_loadset(file);
else
    EEG = file;
end
srate = EEG.srate;

%% Clean event types, ignore boundary events
all_types = {EEG.event.type};
all_latencies = [EEG.event.latency];

n = numel(all_types);

% preallocate maximum needed size
types = zeros(1, n);
latencies = zeros(1, n);

idx = 0;

for i = 1:length(all_types)
    current_type = all_types{i};
    
    % ignore boundary events
    if ischar(current_type) || isstring(current_type)
        if strcmp(char(current_type), 'boundary')
            continue
        end
        current_type = str2double(current_type);
    end
    
    idx = idx + 1;
    types(idx) = current_type;
    latencies(idx) = all_latencies(i);
end

types = types(1:idx);
latencies = latencies(1:idx);

%% Identify block boundaries
in_block = false;
blocks = [];

for i = 1:length(types)
    current = types(i);
    
    % look for valid EO/EC marker
    if ismember(current,[EO_marker EC_marker])
        
        % start new block if not currently within a block
        if ~in_block
            block_start = i;
            block_type = current;
            in_block = true;
            
        % continue same block
        elseif current ~= block_type
            blocks(end+1,:) = [block_start i-1 block_type];
            block_start = i;
            block_type = current;
        end
        
    % if other marker found, end block
    else
        if in_block
            blocks(end+1,:) = [block_start i-1 block_type];
            in_block = false;
        end
    end
end

%% Close final block (safety step)

if in_block
    blocks(end+1,:) = [block_start length(types) block_type];
end

%% Validate blocks
nEO = sum(blocks(:,3) == EO_marker);
nEC = sum(blocks(:,3) == EC_marker);

if size(blocks,1) ~= 8
    error('Expected 8 total blocks, found %d.', size(blocks,1));
end

if nEO ~= 4
    error('Expected 4 eyes open blocks, found %d.', nEO);
end

if nEC ~= 4
    error('Expected 4 eyes open blocks, found %d.', nEC);
end

%% Concat blocks

EO_blocks = {};
EC_blocks = {};

for b = 1:size(blocks,1)
    start_event = blocks(b,1);
    end_event   = blocks(b,2);
    cond        = blocks(b,3);

    % Get start/end latencies
    start_lat = latencies(start_event) - 3*srate;
    end_lat = latencies(end_event) + 3*srate;
    
    % Convert to seconds
    t1 = (start_lat - 1) / srate;
    t2 = (end_lat - 1) / srate;
    
    % Extract segment
    EEG_block = pop_select(EEG, 'time', [t1 t2]);
    
    % Store by condition
    if cond == EO_marker
        EO_blocks{end+1} = EEG_block;
    elseif cond == EC_marker
        EC_blocks{end+1} = EEG_block;
    end
end

%% create set files
% eyes open blocks
if ~isempty(EO_blocks)
    EEG_EO = EO_blocks{1};
    for i = 2:length(EO_blocks)
        EEG_EO = pop_mergeset(EEG_EO, EO_blocks{i});
    end
    EEG = pop_saveset(EEG_EO,'filename',[currentName '_EyesOpen.set'],'filepath',outputpath);
else
    EEG = [];
end

% eyes closed blocks
if ~isempty(EC_blocks)
    EEG_EC = EC_blocks{1};
    for i = 2:length(EC_blocks)
        EEG_EC = pop_mergeset(EEG_EC, EC_blocks{i});
    end
    EEG_EC = pop_saveset( EEG_EC, 'filename',[currentName '_EyesClosed.set'],'filepath',outputpath);
else
    EEG_EC = [];
end
end
