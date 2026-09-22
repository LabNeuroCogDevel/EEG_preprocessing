function allErrors = run_par_preprocessing_V2(task,maindir,rawdir,resting_state_type)
% recent edits - sanvi korsapathy, 06.05.26
% same as the run_preprocessing function but configured to run in parallel
% change number of workers on line 157!!!

%% function inputs
% task = character of task preprocessing, e.g. 'resting_state'
% maindir = main path to save new data, e.g. '/Volumes/Hera/Abby/preprocessed_data'
% rawdir = raw file location, e.g.'/Volumes/Hera/Raw/EEG/7tBrainMech'
% resting_state_type = used if preprocessing resting state
    % automatically set to 1 (aka preprocess eyes open)
    % change to 0 preprocess eyes closed
    
arguments
    task
    maindir
    rawdir
    resting_state_type (1,1) double {mustBeMember(resting_state_type,[0 1])} = 1
end

if resting_state_type == 1
    state = 'EyesOpen';
else
    state = 'EyesClosed';
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

%% initalize
% preprocessing pipeline version!
preprocVer = '0626';

% initial values
lowBP = 0.5;
highBP = 70;
FLAG = 1;

% settings
only128 = 0; % 0 = do all subjects, 1 = only 128 channel subjects
condition = 1; % 0 = overwrite existing files; 1 = skip completed files
dryrun = 0;

fprintf('\n===== PREPROCESSING SETTINGS =====\n');
fprintf('Task                   : %s\n', task);
fprintf('Preprocessed directory : %s\n', maindir);
fprintf('Raw files directory    : %s\n', rawdir);

if task == "resting_state"
    fprintf('Resting state type : %s\n', state);
end

fprintf('==================================\n');

reply = input('Proceed? (y/n): ','s');

if ~strcmpi(reply,'y')
    error('Preprocessing aborted by user.');
end

% load in paths to fieldtrip and eeglab
addpath(genpath('/resources/Euge/'))
addpath('/Volumes/Hera/Projects/7TBrainMech/scripts/fieldtrip-20180926/')
addpath(genpath('/Volumes/Hera/EEG_toolkit/preprocessingTools'))
run('/Volumes/Hera/EEG_toolkit/Resources/eeglab_current/eeglab2024.2/eeglab.m')

msg = "I am running " + task + " with preprocessing pipeline version " + preprocVer;
disp(msg)

% create outpaths, create subfolders if they don't exist
paths = create_output_paths(maindir, task);

%% remarking
% changes trials to be a single digit
remark(paths.remarked,dryrun,task,rawdir,preprocVer);

%% gather all file paths for subjects remarked data
setfilesDir = [paths.remarked, '/*.set'];
remarked_files = all_remarked_set(setfilesDir);
n = length(remarked_files); %number of EEG sets to preprocess

if task == "anti"
    % rename AS trials
    errorRenaming = cell(n,2);
    for i = 1:n
        remarked_inputfile = remarked_files{i};
        try
            rename_AStrials(remarked_inputfile,paths.renamedtrials);
        catch e
            fprintf("Error renaming %s : %s\n",remarked_inputfile,e.message)
            errorRenaming{i,1} = remarked_files{i};
            errorRenaming{i,2} = e.message;
            for s=e.stack
                disp(s)
            end
        end    
    end
    
    % get all renamed files
    setfilesDir = [paths.remarked, '/*.set'];
    remarked_files = all_remarked_set(setfilesDir);
    n = length(remarked_files);
    
    errorRenaming = errorRenaming(~cellfun(@isempty,errorRenaming(:,1)),:);
    allErrors.renaming = errorRenaming;
end
%maybe use clean_rawdata but need

%% loop through every subject to preprocess
% saving input files that failed to be preprocessed
% displaying waitbar
w = waitbar(0,sprintf("Starting %s preprocessing...",task),"Name",sprintf("%s preprocessing pipeline",task));
if task == "resting_state"
    errorTrimming = cell(n,2);
    for i = 1:n
        inputfile = remarked_files{i};
        % updating waitbar
        waitbar_filename = split(inputfile,"/");
        waitbar_name = waitbar_filename{end};
        split_name = split(waitbar_name,"_");
        lunaid = split_name{1};
        scandate = split_name{2};
        waitbar(i/n,w,sprintf("%s %s",lunaid,scandate))
        try
            trim_resting_state(inputfile, paths.trimmed)
        catch e
            fprintf('Error trimming "%s": %s\n', inputfile, e.message)
            errorTrimming{i,1} = remarked_files{i};
            errorTrimming{i,2} = e.message;
        end
    end
    if resting_state_type == 1
        setfilesDir = [paths.trimmed,'/*EyesOpen.set'];
    elseif resting_state_type == 0
        setfilesDir = [paths.trimmed,'/*EyesClosed.set'];
    end
    remarked_files = all_remarked_set(setfilesDir);
    n = length(remarked_files);
    
    errorTrimming = errorTrimming(~cellfun(@isempty,errorTrimming(:,1)),:);
    allErrors.trimming = errorTrimming;
end

errorProcessing = cell(n,2);

delete(gcp('nocreate')) % clear any existing parpool
parpool(20);
parfor j = 1:n
    try
        preprocessing_pipeline_V2(remarked_files{j},paths,lowBP,highBP,FLAG,condition,task)
    catch e
        errorProcessing(j,:) = {remarked_files{j}, e.message};
    end
end
delete(gcp('nocreate')) % clear parpool

errorProcessing = errorProcessing(~cellfun(@isempty,errorProcessing(:,1)),:);
allErrors.processing = errorProcessing;

%% Clean epochs and remove ones that are bad
cleanICA_path = paths.ICAwholeclean_homogenize;
epoch_folder = paths.epoch;
marked_epoch_folder = paths.marked_epoch;
kept_epoch_folder = paths.kept_epoch;

EEGfileNames = dir([cleanICA_path, '/*_CleanICA_Homogenize.set']);

revisar = {};
errorEpoch = cell(1,length(EEGfileNames));
for currentEEG=1:size(EEGfileNames,1)
    filename=[EEGfileNames(currentEEG).name];
    inputfile = fullfile(cleanICA_path,filename);
    try
        if task ~= "resting_state"
            event_marker = input(sprintf('Select trigger to epoch around for %s: ', task),'s');
            revisar{currentEEG} = epochclean(inputfile,epoch_folder,marked_epoch_folder,...
                kept_epoch_folder,event_marker,[-1 1]);
        end
    catch e
        fprintf('Error epoching "%s": %s\n',inputfile, e.message)
        errorEpoch(currentEEG,:) = {EEGfileNames{currentEEG}, e.message};
    end
end
errorEpoch = errorEpoch(~cellfun(@isempty,errorEpoch(:,1)),:);
allErrors.epoch = errorEpoch;

%% create report with data from all QC files
if task == "resting_state"
    if resting_state_type == 1
        QCfiles = dir(fullfile(paths.qualityCheck, '*Open*.mat'));
    elseif resting_state_type == 0
        QCfiles = dir(fullfile(paths.qualityCheck, '*Closed*.mat'));
    end
    task_label = sprintf('%s_%s', task, state);
else
    task_label = task;
    QCfiles = dir(fullfile(paths.qualityCheck, '*.mat'));
end

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