function allErrors = run_epoching(task, maindir)

% defining input arguments
arguments
    task
    maindir
end

% check if maindir exists
while ~isfolder(maindir)
    maindir = input('maindir does not exist! Enter main directory: ','s');
end

% overwrite existing files?
overwrite_reply = input('Overwrite existing files? (y/n): ','s');

if strcmp(overwrite_reply,'y') % y = overwrite existing files; n = skip completed files
    fprintf("Will overwrite existing files\n")
    overwrite = 1;
elseif strcmp(overwrite_reply,'n')
    fprintf('Will skip files already preprocessed\n')
    overwrite = 0;
else
    error('Preprocessing aborted by user.')
end

% print out settings
fprintf('\n===== EPOCHING SETTINGS =====\n');
fprintf('Task                   : %s\n', task);
fprintf('Preprocessed directory : %s\n', maindir);
fprintf('Task directory         : %s\n',fullfile(maindir,task));
fprintf('==================================\n');

reply = input('Proceed? (y/n): ','s');

if ~strcmpi(reply,'y')
    error('Preprocessing aborted by user.');
end

% load in paths to fieldtrip and eeglab
addpath('/Volumes/Hera/Projects/7TBrainMech/scripts/fieldtrip-20180926/')
addpath(genpath('/Volumes/Hera/EEG_toolkit/preprocessingTools'))
run('/Volumes/Hera/EEG_toolkit/Resources/eeglab_current/eeglab2024.2/eeglab.m')

% study are we pulling data from- matters for cap locations and remarking
if contains(maindir,'SPA')
    study = 'SPA';    
elseif contains(maindir, 'Habit')
    study = 'Habit';
elseif contains(maindir,'7TBrainMech')
    study = '7T';    
else
    error('Unable to define study')    
end

% create outpaths, create subfolders if they don't exist
paths = create_output_paths(maindir, task, study);

%% clean epochs and remove ones that are bad
if strcmp(study,'7T')
    cleanICA_path = paths.ICAwholeclean_homogenize;
elseif strcmp(study,'Habit') || strcmp(study,'SPA')
    cleanICA_path = paths.ICAwholeclean;
end

epoch_folder = paths.epoch;
marked_epoch_folder = paths.marked_epoch;
kept_epoch_folder = paths.kept_epoch;

if strcmp(study,'7T')
    EEGfileNames = dir([cleanICA_path, '/*_CleanICA_Homogenize.set']);
elseif strcmp(study,'Habit') || strcmp(study,'SPA')
    EEGfileNames = dir([cleanICA_path, '/*_CleanICA.set']);
end

n = size(EEGfileNames,1);

errorEpoch = cell(n,5); % preallocate error array

% view all events to potentially epoch to
view_events_eeg = pop_loadset(fullfile(cleanICA_path, EEGfileNames(1).name));
disp({view_events_eeg.event.type});

% user input to events to epoch to
epoch_event = input(sprintf("Select event(s) to epoch around for %s (comma-separated): ",task),'s');
epoch_event = strtrim(split(epoch_event,','));

% user input to get epoch times
while true
    epoch_times = input('Enter epoch limits in seconds (e.g. [-2 1]): ');
    if isnumeric(epoch_times) && numel(epoch_times) == 2 && epoch_times(1) < epoch_times(2)
        break;
    end
    fprintf('Invalid input. Please enter a vector like [-2 1].\n');
end

%% Run over entire data set or just one file
% User input to determine if running on entire dataset or a particular subject
fullrun_response = input("Run epoching on full dataset? (y/n): ",'s');

if strcmp(fullrun_response,'n')
    %% Run on specific subject
    file_match = [];
    while ~any(file_match)
        subid_response = NaN;
        scandate_response = NaN;
        
        % get specific subject to run
        while isnan(subid_response)
            subid_response = input("Input subject ID to run epoching on: ",'s');
            if str2double(subid_response) < 10000
                fprintf("Subject ID too small; retry\n")
                subid_response = NaN;
            end
        end
        
        % get specific date to run
        while isnan(scandate_response)
            scandate_response = input("Input scan date to run epoching on: ",'s');
            if str2double(scandate_response) < 20000000
                fprintf("Subject ID too small; retry\n")
                scandate_response = NaN;
            end
        end
        
        % find file corresponding to that subject
        file_match = contains([EEGfileNames(:).name], subid_response) & contains([EEGfileNames(:).name], scandate_response);
        if ~any(file_match)
            fprintf("No file matched specified subject ID and date; retry\n")
        end
        
        % run epoch on specific subject
        filename = [EEGfileNames(file_match).name];
        input_file = fullfile(cleanICA_path,filename);
        try 
            epochclean(input_file,epoch_folder,marked_epoch_folder,...
                kept_epoch_folder,overwrite,epoch_event,epoch_times)
        catch e
             % extract error details
            errorMessage = e.message;
            errorLine = e.stack(1).line;
            errorName = e.stack(1).name;
            errorFile = e.stack(1).file;

            % print error details
            fprintf("Error occured in %s at line %d.\n",errorName, errorLine)
            fprintf("Error epoching %s: %s\n", EEGfileNames(j).name, errorMessage)

            % save error details
            errorEpoch(j,:) = {EEGfileNames(j).name, errorMessage, errorLine, errorName, errorFile};
        end
        
    end
elseif strcmp(fullrun_response,'y')
    %% loop over each EEG and run epochclean
    for j = 1:n
        filename=[EEGfileNames(j).name];
        input_file = fullfile(cleanICA_path,filename);
        try
            epochclean(input_file,epoch_folder, marked_epoch_folder,...
                kept_epoch_folder,overwrite, epoch_event, epoch_times)
        catch e
             % extract error details
            errorMessage = e.message;
            errorLine = e.stack(1).line;
            errorName = e.stack(1).name;
            errorFile = e.stack(1).file;

            % print error details
            fprintf("Error occured in %s at line %d.\n",errorName, errorLine)
            fprintf("Error epoching %s: %s\n", EEGfileNames(j).name, errorMessage)

            % save error details
            errorEpoch(j,:) = {EEGfileNames(j).name, errorMessage, errorLine, errorName, errorFile};
        end

    end
end
allErrors = errorEpoch(~cellfun(@isempty,errorEpoch(:,1)),:);
end