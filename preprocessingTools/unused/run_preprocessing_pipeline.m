function [] = run_preprocessing_pipeline(task,maindir,rawdir)
% task = character of task preprocessing
% maindir = main path where new data will be saved e.g. /Volumes/Hera/Abby/preprocessed_data/
% rawdir = path where raw eeg files are found e.g./Volumes/Hera/Raw/EEG/7tBrainMech/

% load in paths to feildtrip and eeglab
% addpath(genpath('/Volumes/Hera/Projects/7TBrainMech/scripts/eeg/Shane/Preprocessing_Functions/'));
addpath(genpath('/resources/Euge/'))
addpath('/Volumes/Hera/Projects/7TBrainMech/scripts/fieldtrip-20180926/')
addpath(genpath('/Volumes/Hera/Abby/Lindsay/preprocessingFunctions/'))
run('/Volumes/Hera/Abby/Resources/eeglab_current/eeglab2024.2/eeglab.m')

% Outpath
% maindir = hera('Abby/Lindsay/preprocessed_data');

disp(["i am running" task])

taskdirectory = [maindir '/' task];

% initial values
lowBP = 0.5;
highBP = 70;
FLAG = 1;

% settings
only128 = 0; % 0==do all, 1==only 128 channel subjects
condition = 1; %0 - if you want to overwrite an already existing file; 1- if you want it to skip subjects who have already been run
dryrun = 0;

%% remarking
% chages trials to be a single digit
remark(taskdirectory,dryrun,task,rawdir);


%% gather all file paths for subjects remarked data
setfilesDir = [taskdirectory, '/remarked/*.set'];
setfiles = all_remarked_set(setfilesDir);
n = length(setfiles);%number of EEG sets to preprocess

if task == "anti"
    % rename AS trials
    errorRenaming = {};
    for i = 1:n
        remarked_inputfile = setfiles{i};
        try
            rename_AStrials(remarked_inputfile);
        catch e
            fprintf("Error renaming %s : %s\n",remarked_inputfile,e.message)
            errorRenaming{end+1,1}= {remarked_inputfile};
            for s=e.stack
                disp(s)
            end
        end    
    end
    
    % get all renamed files
    setfilesDir = [taskdirectory,'/renamedtrials/*.set'];
    setfiles = all_remarked_set(setfilesDir);
    n = length(setfiles);
end
aybe use clean_rawdata but need
%% loop through every subject to preprocess
% saving input files that failed to be preprocessed
errorProcessing={};
% displaying waitbar
w = waitbar(0,sprintf("Starting %s preprocessing...",task),"Name",sprintf("%s preprocessing pipeline",task));
for i = 1:n
    inputfile = setfiles{i};
    % updating waitbar
    waitbar_filename = split(inputfile,"/");
    waitbar_name = waitbar_filename{end};
    split_name = split(waitbar_name,"_");
    lunaid = split_name{1};
    scandate = split_name{2};
    waitbar(i/n,w,sprintf("%s %s",lunaid,scandate))
    try
        preprocessing_pipeline(inputfile,taskdirectory,lowBP,highBP,FLAG,condition,task)
    catch e
        fprintf('Error processing "%s": %s\n',inputfile, e.message)
        errorProcessing{end+1,1} = {inputfile};
        for s=e.stack
            disp(s)
        end
    end
end

%% select ICA components to reject

ICA_Path = [taskdirectory '/ICAwhole'];
CleanICApath = [taskdirectory '/AfterWhole/ICAwholeclean/'];
MarkedICApath = [taskdirectory '/AfterWhole/MarkedICAwhole/'];

EEGfileNames = dir([ICA_Path '/*.set']);

for fidx = 1:length(EEGfileNames)
    filename = EEGfileNames(fidx).name;
    locs = file_locs(fullfile(ICA_Path,filename), taskdirectory, task);
    if exist(locs.ICAwholeClean, 'file')
        fprintf('skipping; already created %s\n', locs.ICAwholeClean);
        continue
    end
    % BREAK POINT IN selectcompICA !!!
    selectcompICA
end


%% Homogenize Chanloc
datapath = [taskdirectory '/AfterWhole/ICAwholeclean'];
savepath = [taskdirectory '/AfterWhole/ICAwholeclean_homogenize'];

setfiles0 = dir([datapath,'/*icapru.set']);
setfiles = {};
for epo = 1:length(setfiles0)
    setfiles{epo,1} = fullfile(datapath, setfiles0(epo).name); % cell array with EEG file names
end

correction_cap_location = hera('Projects/7TBrainMech/scripts/eeg/Shane/resources/ELchanLoc.ced');
for i = 1:length(setfiles)
    homogenizeChanLoc(setfiles{i},correction_cap_location,savepath, taskdirectory, task)
end

%% filter out the 60hz artifact from electronics
datapath = [taskdirectory '/AfterWhole/ICAwholeclean_homogenize'];

setfiles0 = dir([datapath,'/*icapru.set']);
setfiles = {};
for epo = 1:length(setfiles0)
    setfiles{epo,1} = fullfile(datapath, setfiles0(epo).name); % cell array with EEG file names
end

for i = 1:length(setfiles)
    inputfile = setfiles{i};
    [filepath,filename ,ext] =  fileparts((setfiles{i}));

    EEG = pop_loadset(inputfile);
    EEG = pop_eegfiltnew(EEG, 59, 61, [], 1, [], 0);
    EEG = pop_saveset(EEG, 'filename', filename, 'filepath', datapath);
end

%% Clean epochs and remove ones that are bad
cleanICA_path = [taskdirectory '/AfterWhole/ICAwholeclean_homogenize/'];
epoch_folder = [taskdirectory '/AfterWhole/epoch/'];
marked_epoch_folder = [taskdirectory '/AfterWhole/marked_epoch/'];
kept_epoch_folder = [taskdirectory '/AfterWhole/kept_epoch/'];

EEGfileNames = dir([cleanICA_path, '/*_icapru.set']);

revisar = {};

for currentEEG=1:size(EEGfileNames,1)
    filename=[EEGfileNames(currentEEG).name];
    inputfile = [cleanICA_path,filename];
    try
        if task == "anti"
            revisar{currentEEG} = epochclean(inputfile,epoch_folder,marked_epoch_folder,kept_epoch_folder,task,"eventtype","prep","asscore",1);
        elseif task == "vgs"
            revisar{currentEEG} = epochclean(inputfile,epoch_folder,marked_epoch_folder,kept_epoch_folder,task);
        end
    catch e
        fprintf('Error processing "%s": %s\n',inputfile, e.message)
        for s=e.stack
            disp(s)
        end
    end
end

end