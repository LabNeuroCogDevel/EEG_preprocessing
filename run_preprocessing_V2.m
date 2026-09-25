function allErrors = run_preprocessing_V2(task,maindir,rawdir)
% recent edits - sanvi korsapathy, 06.05.26
% fixing epochclean and names of error cells - abby beatty 06.09.26
% combined added a user input to choose whether or not to use parallel processing
% to avoid having two separate scripts - sanvi korsapathy 06.23.26
% user input to ask if you want to overwrite existing files - abby beatty 07.06.2026
% change name of preprocessing version to yearmonthday

%% function inputs
% task = character of task preprocessing, e.g. 'resting_state'
% maindir = main path to save new data, e.g. '/Volumes/Hera/Sanvi/Habit/preprocessed_data'
% rawdir = raw file location, e.g.'/Volumes/Hera/Raw/EEG/Habit'
% for resting state i don't think we should be running ICA on concatenated data; best run on continuous data -abby
% resting_state_type = used if preprocessing resting state
    % automatically set to 1 (aka preprocess eyes open)
    % change to 0 to preprocess eyes closed
    
arguments
    task
    maindir
    rawdir
end

%% outline
%   1. create folders
%   2. remark
%   3. start preprocessing
%       1. reref to mastoids
%       2. filter + downsample
%       3. remove line noise
%       4. channel rejection
%       5. average reref
%       6. generate ICA
%       7. IC rejection
%       8. homogenize chan locs
%   4. epoching

%% initialize
% preprocessing pipeline version!
preprocVer = '20260922';

% initial values
lowBP = 0.5;
highBP = 70;
% FLAG = 1; % re-reference to channel average

% settings
only128 = 0; % 0 = do all subjects, 1 = only 128 channel subjects
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

dryrun = 0;

% check if directories exist
while ~isfolder(maindir)
    maindir = input('maindir does not exist! Enter main directory: ','s');
end

while ~isfolder(rawdir)
    rawdir = input('rawdir does not exist! Enter raw directory: ','s');
end

fprintf('\n===== PREPROCESSING SETTINGS =====\n');
fprintf('Task                   : %s\n', task);
fprintf('Preprocessed directory : %s\n', maindir);
fprintf('Raw files directory    : %s\n', rawdir);
fprintf('==================================\n');

reply = input('Proceed? (y/n): ','s');

if ~strcmpi(reply,'y')
    error('Preprocessing aborted by user.');
end

par_option = NaN; % user enters whether to use parallel processing or not

while isnan(par_option)
    par_option = input('Use parallel processing? (y/n): ','s');
end

if strcmp(par_option,'y')
    num_workers = NaN; % if using parallel, prompt user to select number of workers
    while isnan(num_workers)
        worker_text = 'Enter number of workers to use (number of files to process in parallel): ';
        num_workers = str2double(input(worker_text , 's'));
    end
    fprintf('Will process %d files at a time...', num_workers);
elseif strcmp(par_option,'n')
    disp('Will process each file one at a time...');
end

% load in paths to fieldtrip and eeglab
addpath('/Volumes/Hera/Projects/7TBrainMech/scripts/fieldtrip-20180926/')
addpath(genpath('/Volumes/Hera/EEG_toolkit/preprocessingTools'))
run('/Volumes/Hera/EEG_toolkit/Resources/eeglab_current/eeglab2024.2/eeglab.m')

msg = "I am running " + task + " with preprocessing pipeline version " + preprocVer;
disp(msg)

% create outpaths, create subfolders if they don't exist
paths = create_output_paths(maindir, task);

% study are we pulling data from- matters for cap locations and remarking
if contains(rawdir,'SPA')
    study = 'SPA';    
elseif contains(rawdir, 'Habit')
    study = 'Habit';
elseif contains(rawdir,'7TBrainMech')
    study = '7T';    
else
    error('Unable to define study')    
end

%% remarking
% changes trials to be a single digit
addpath('/Volumes/Hera/EEG_toolkit/preprocessingTools/functions/remark_functions/')
% all raw EEGs from study
rawEEGs = dir(fullfile(rawdir,'*','*.bdf'));
% raw EEGs for specific task being preprocessed
IDX = find(cellfun(@any,regexpi ( {rawEEGs.name}.', task)));
% set up error cell
n = length(rawEEGs);
errorRemarking = cell(n,2);

% loop over all specific task EEGs
for idx = IDX'
    % define current EEG
    currentName = regexprep(rawEEGs(idx).name,'\.bdf$','');
    d = [rawEEGs(idx).folder '/'];
    % skip if already created
    finalfile = fullfile(paths.remarked, [currentName '_' preprocVer '_Rem.set']);
    if exist(finalfile,'file') && overwrite == 0
        fprintf('already have %s\n', finalfile)
        continue
    end
    if dryrun
        fprintf('want to run %s; set dryrun=0 to actually run\n', finalfile)
        continue
    end
    fprintf('making %s\n',finalfile);
    
    % load EEG set
    EEG = pop_biosig([d currentName '.bdf']);
    EEG.setname=[currentName 'Rem'];
    
    try
        switch task
            case "rest"
                remark_resting_state(EEG, currentName, preprocVer, paths.remarked);
            case "habit"
                remark_habit_task(EEG, currentName, preprocVer, paths.remarked)
            case "anti"                
                if strcmp(study,'7T')
                    remark_AS_7T(EEG, currentName, preprocVer, paths.remarked);
                end
        end
    catch e
        fprintf("Error remarking %s : %s\n",currentName,e.message)
        errorRemarking{idx,1} = rawEEGs{i};
        errorRemarking{idx,2} = e.message;
        for s=e.stack
            disp(s)
        end
    end
end

errorRemarking = errorRemarking(~cellfun(@isempty,errorRemarking(:,1)),:);
allErrors.remarking = errorRemarking;
%% gather all file paths for subjects remarked data
setfilesDir = [paths.remarked, '/*.set'];
remarked_files = all_remarked_set(setfilesDir);
n = length(remarked_files); %number of EEG sets to preprocess

%% load in file with demographic information 
if strcmp(study,'7T')
    age_df = readtable('/Volumes/Hera/Projects/7TBrainMech/scripts/txt/merged_7t.csv');
    age_df.ses = age_df.visitno;
elseif strcmp(study,'Habit')
    age_df = readtable('/Volumes/Hera/Projects/Habit/redcap/data/eeg_mr_vdate.csv');
    age_df.eeg_date = age_df.eeg;
elseif strcmp(study,'SPA')
    % TODO!!! add SPA ages
end

%% loop through every subject to preprocess
% saving input files that failed to be preprocessed
errorProcessing = cell(n,2);
errorAddingAge = cell(n,2);
if strcmp(par_option,'y')
    delete(gcp('nocreate')) % clear any existing parpool
    parpool(num_workers);
    parfor j = 1:n
        inputfile = remarked_files{j};
        splitfilename = split(inputfile,"/");
        filename = splitfilename{end};
        splitname = split(filename,"_");
        lunaid = str2double(splitname{1});
        scandate = str2double(splitname{2});
        eeg_age = [];
        ses = [];
        subidx = find(age_df.lunaid == lunaid & age_df.eeg_date == scandate);
        try 
            subtable = age_df(subidx,:);
            eeg_age = subtable.eeg_age;
            ses = subtable.ses;
        catch e
            fprintf('Error adding age "%s": %s\n',inputfile, e.message)
            errorAddingAge(j,:) = {remarked_files{j}, e.message};
        end
        try
            preprocessing_pipeline_V2(remarked_files{j},paths,lowBP,highBP,overwrite,task,study,eeg_age,ses)
        catch e
            errorProcessing(j,:) = {remarked_files{j}, e.message};
        end
    end
    delete(gcp('nocreate')) % clear parpool
    
elseif strcmp(par_option,'n')
    % displaying waitbar
    w = waitbar(0,sprintf("Starting %s preprocessing...",task),"Name",sprintf("%s preprocessing pipeline",task));
    
    for j = 1:n
        inputfile = remarked_files{j};
        % updating waitbar
        waitbar_filename = split(inputfile,"/");
        waitbar_name = waitbar_filename{end};
        split_name = split(waitbar_name,"_");
        lunaid = split_name{1};
        scandate = split_name{2};
        eeg_age = [];
        ses=[];
        waitbar(j/n,w,sprintf("%s %s",lunaid,scandate))
        try 
            subtable = age_df(subidx,:);
            eeg_age = subtable.eeg_age;
            ses = subtable.ses;
        catch e
            fprintf('Error adding age "%s": %s\n',inputfile, e.message)
            errorAddingAge(j,:) = {remarked_files{j}, e.message};
        end
        try
            preprocessing_pipeline_V2(inputfile,paths,lowBP,highBP,overwrite,task,study,eeg_age,ses)
        catch e
            fprintf('Error processing "%s": %s\n',inputfile, e.message)
            errorProcessing{j,1} = remarked_files{j};
            errorProcessing{j,2} = e.message;
        end
    end
    close(w)
end
errorProcessing = errorProcessing(~cellfun(@isempty,errorProcessing(:,1)),:);
allErrors.processing = errorProcessing;
errorAddingAge = errorAddingAge(~cellfun(@isempty,errorAddingAge(:,1)),:);
allErrors.addingage = errorAddingAge;
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
errorEpoch = cell(n,2);

% view_events_eeg = pop_loadset(fullfile(cleanICA_path, EEGfileNames(1).name));
% disp({view_events_eeg.event.type});

revisar = {};
if task ~= "resting_state"
    event_marker = input(sprintf('Select event(s) to epoch around for %s (comma-separated): ', task),'s');
    event_marker = strtrim(split(event_marker, ','));
    event_marker = cellstr(event_marker);
    
    while true
        epochTimes = input('Enter epoch limits (e.g. [-2 1]): ');
        if isnumeric(epochTimes) && numel(epochTimes) == 2 && epochTimes(1) < epochTimes(2)
            break;
        end
        fprintf('Invalid input. Please enter a vector like [-2 1].\n');
    end
    
    for currentEEG=1:n
        filename=[EEGfileNames(currentEEG).name];
        inputfile = fullfile(cleanICA_path,filename);
        try
            revisar{currentEEG} = epochclean(inputfile,epoch_folder,marked_epoch_folder,...
                kept_epoch_folder,event_marker,epochTimes);
        catch e
            fprintf('Error processing "%s": %s\n',inputfile, e.message)
            errorEpoch{currentEEG,1} = EEGfileNames(currentEEG).name;
            errorEpoch{currentEEG,2} = e.message;
        end
    end
end

errorEpoch = errorEpoch(~cellfun(@isempty,errorEpoch(:,1)),:);
allErrors.epoch = errorEpoch;

%% for anti-saccade add trial score to EEG.event of epoched data

if task == "anti"
    renamed_files = dir(fullfile(paths.renamedtrials ,'*.set'));
    epoch_files = dir(fullfile(paths.kept_epoch,'*kept_2.set'));
    
    n = size(epoch_files,1);
    errorScore = cell(n,2);

    for currentepochEEG = 1:n
        try
            anti_trial_scoring
        catch e
            fprintf('Error adding score "%s": %s\n',epochfilename, e.message)
            errorScore{currentepochEEG,1} = epoch_files(currentepochEEG).name;
            errorScore{currentepochEEG,2} = e.message;
        end
    end
    errorScore = errorScore(~cellfun(@isempty,errorScore(:,1)),:);
    allErrors.score = errorScore;
end

%% create report with data from all QC files
% if task == "resting_state"
%     if resting_state_type == 1
%         QCfiles = dir(fullfile(paths.qualityCheck, '*Open*.mat'));
%     elseif resting_state_type == 0
%         QCfiles = dir(fullfile(paths.qualityCheck, '*Closed*.mat'));
%     end
%     task_label = sprintf('%s_%s', task, state);
% else
%     task_label = task;
%     QCfiles = dir(fullfile(paths.qualityCheck, '*.mat'));
% end

task_label = task;
QCfiles = dir(fullfile(paths.qualityCheck, '*.mat'));
nFiles = length(QCfiles);

masterQC = table(zeros(nFiles,1),zeros(nFiles,1), zeros(nFiles,1), zeros(nFiles,1),...
    zeros(nFiles,1), zeros(nFiles,1), zeros(nFiles,1), zeros(nFiles,1),...
    'VariableNames', {'subid','scandate','num_ICs_rej','num_chans_rej',...
    'original_var', 'percent_var_removed', ...
    'final_rank', 'rank_percent'});

for i = 1:nFiles
    
    data = load(fullfile(QCfiles(i).folder, QCfiles(i).name));
    loadQC = data.data;
    
    masterQC.subid(i) = loadQC.subid;
    masterQC.scandate(i) = loadQC.scandate;
    masterQC.num_ICs_rej(i) = loadQC.num_ICs_reject;
    masterQC.num_chans_rej(i) = loadQC.num_removed_channels;
    masterQC.original_var(i) = loadQC.original_variance;
    masterQC.percent_var_removed(i) = loadQC.percent_variance_removed;
    masterQC.final_rank(i) = loadQC.final_rank;
    masterQC.rank_percent(i) = 100*(loadQC.final_rank/64);
end

save(fullfile(paths.main, [task_label '_masterQualityCheck.mat']),'masterQC')

end