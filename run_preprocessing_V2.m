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
%       - Option to skip remarking (for files that continue to fail)
%   3. start preprocessing
%       1. reref to mastoids, bandpass filter, notch filter, and downsample
%           - run_filtering()
%       2. channel rejection
%           - run_channel_rejection()
%       3. channel interpolation
%           - run_channel_interpolation()
%       4. reref to average
%           - run_rereference()
%       5. generate ICA
%           - within preprocessing_pipeline_V2()
%       6. apply ICA weights
%           - within preprocessing_pipeline_V2()
%       7. IC rejection
%           - Default: run_autoICArejection()
%           - Option to use run_manualICArejection() on individual subjects
%       7b. homogenize chan locs (For 7T)
%           - within preprocessing_pipeline_V2()
%       8. generate individual QC figure (power spectrum)
%           - within preprocessing_pipeline_V2()
%   4. generate QC report
%   5. option to epoch
%       - run_epoching()

%% initialize
% define allErrors 
allErrors = [];

% preprocessing pipeline version!
preprocVer = '20260922';

% filter settings and run only subjects with 128 channels option
lowBP = 0.5;
highBP = 70;
only128 = 0; % 0 = do all subjects, 1 = only 128 channel subjects

% check if main directory exists
while ~isfolder(maindir)
    maindir = input('maindir does not exist! Enter main directory: ','s');
end

% check if raw directory exists
while ~isfolder(rawdir)
    rawdir = input('rawdir does not exist! Enter raw directory: ','s');
end

% Print setting for user approval
fprintf('\n===== PREPROCESSING SETTINGS =====\n');
fprintf('Task                   : %s\n', task);
fprintf('Preprocessed directory : %s\n', maindir);
fprintf('Task directory         : %s\n',fullfile(maindir,task));
fprintf('Raw files directory    : %s\n', rawdir);
fprintf('==================================\n');

reply = input('Proceed? (y/n): ','s');

if ~strcmpi(reply,'y')
    error('Preprocessing aborted by user.');
end

% load in paths to fieldtrip and eeglab
addpath('/Volumes/Hera/Projects/7TBrainMech/scripts/fieldtrip-20180926/')
addpath(genpath('/Volumes/Hera/EEG_toolkit/preprocessingTools'))
run('/Volumes/Hera/EEG_toolkit/Resources/eeglab_current/eeglab2024.2/eeglab.m')

% Print task and preproc version
msg = "I am running " + task + " with preprocessing pipeline version " + preprocVer;
disp(msg)

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

% create outpaths, create subfolders if they don't exist
paths = create_output_paths(maindir, task, study);

% load in file with demographic information (for age and session/visit)
if strcmp(study,'7T')
    age_df = readtable('/Volumes/Hera/Projects/7TBrainMech/scripts/txt/merged_7t.csv');
    age_df.ses = age_df.visitno;
elseif strcmp(study,'Habit')
    % TODO: update habit age table
    age_df = readtable('/Volumes/Hera/Projects/Habit/redcap/data/eeg_mr_vdate.csv');
    age_df.eeg_date = age_df.eeg;
elseif strcmp(study,'SPA')
    % TODO!!! add SPA ages
end

%% Remarking
% Run remarking?
runRemarking_reply = input("Run remarking? (note: if no remarked files exisit processing will fail) (y/n): ",'s');
if strcmp(runRemarking_reply,'n') % skip remarking
    fprintf("Skipping remarking step\n")
elseif strcmp(runRemarking_reply,'y') % run remarking
    % User enters whether to use parallel processing for remarking or not
    par_option = NaN; 

    % Parallel process remarked data?
    while isnan(par_option)
        par_option = input('Use parallel processing for remarking? (y/n): ','s');
    end

    if strcmp(par_option,'y')
        num_workers = NaN; % if using parallel, prompt user to select number of workers
        while isnan(num_workers)
            worker_text = 'Enter number of workers to use (number of files to remark in parallel): ';
            num_workers = str2double(input(worker_text , 's'));
        end
        fprintf('Will remark %d files at a time...', num_workers);
    elseif strcmp(par_option,'n')
        disp('Will remark each file one at a time...');
    end

    % overwrite remarked files?
    % User input whether to overwrite existing files
    overwrite_reply = input('Overwrite existing remarked files? (y/n): ','s');

    if strcmp(overwrite_reply,'y') % y = overwrite existing files; n = skip completed files
        fprintf("Will overwrite existing files\n")
        overwrite = 1;
    elseif strcmp(overwrite_reply,'n')
        fprintf('Will skip files already remarked\n')
        overwrite = 0;
    else
        error('Preprocessing aborted by user.')
    end

    % changes trials to be a single digit
    addpath('/Volumes/Hera/EEG_toolkit/preprocessingTools/functions/remark_functions/')
    % all raw EEGs from study
    rawEEGs = dir(fullfile(rawdir,'*','*.bdf'));
    % raw EEGs for specific task being preprocessed
    IDX = find(cellfun(@any,regexpi ( {rawEEGs.name}.', task))); % IDX = index of EEGfiles that is the task being processed
    % set up error cell
    n = length(IDX);
    errorRemarking = cell(n,4);

    % loop over all specific task EEGs
    if strcmp(par_option,'y')

        % start parallel pool
        if isempty(gcp('nocreate')) % no parallel pool exists
            parpool(num_workers)
        elseif ~isempty(gcp('nocreate')) % parallel pool exists
            p = gcp('nocreate'); % getting parpool object
            if p.NumWorkers == num_workers % keep exisiting parpool if workers are the same number as workers specified
                fprintf("Parallel pool already running with specified number of workers\n")
            else % delete current parpool and create new parpool if current does not match specified number of workers
                fprintf("Parallel pool running has %d workers; not %d workers specified...\nDeleting and starting new parallel pool with %d workers",...
                    p.NumWorkers, num_workers, num_workers)         
                delete(gcp('nocreate'))
                parpool(num_workers)
            end        
        end

        parfor idxIDX = 1:length(IDX) % idxIDX = current index of IDX (to correctly align with errorRemark)
            idx = IDX(idxIDX); % idx = to get the correct EEG file
            % define current EEG
            currentName = regexprep(rawEEGs(idx).name,'\.bdf$','');
            d = [rawEEGs(idx).folder '/'];
            % skip if already created
            finalfile = fullfile(paths.remarked, [currentName '_' preprocVer '_Rem.set']);

            if exist(finalfile,'file') && overwrite == 0
                fprintf('already have %s\n', finalfile)
                continue
            end
            fprintf('making %s\n',finalfile);

            % load EEG set
            EEG = pop_biosig([d currentName '.bdf']);
            EEG.setname=[currentName 'Rem'];

            % each task has its own remark function
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
                    case "vgs"
                        remark_vgs(EEG,currentName,preprocVer, paths.remarked);
                end
            catch e
                % extract error details
                errorMessage = e.message;
                errorLine = e.stack(1).line;
                errorName = e.stack(1).name;

                % print error details
                fprintf("Error occured in %s at line %d.\n",errorName, errorLine)
                fprintf("Error remarking %s: %s\n",currentName,errorMessage)

                % save error details
                errorRemarking(idxIDX,:) = {rawEEGs(idx).name, errorMessage, errorLine, errorName};

            end
        end

    elseif strcmp(par_option,'n')
        for idxIDX = 1:length(IDX) % idxIDX = current index of IDX (to correctly align with errorRemark)
            idx = IDX(idxIDX); % idx = to get the correct EEG file
            % define current EEG
            currentName = regexprep(rawEEGs(idx).name,'\.bdf$','');
            d = [rawEEGs(idx).folder '/'];
            % skip if already created
            finalfile = fullfile(paths.remarked, [currentName '_' preprocVer '_Rem.set']);
            if exist(finalfile,'file') && overwrite == 0
                fprintf('already have %s\n', finalfile)
                continue
            end
            fprintf('making %s\n',finalfile);

            % load EEG set
            EEG = pop_biosig([d currentName '.bdf']);
            EEG.setname=[currentName 'Rem'];

            % each task has its own remark function
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
                    case "vgs"
                        remark_vgs(EEG,currentName,preprocVer, paths.remarked);
                end
            catch e
                % extract error details
                errorMessage = e.message;
                errorLine = e.stack(1).line;
                errorName = e.stack(1).name;

                % print error details
                fprintf("Error occured in %s at line %d.\n",errorName, errorLine)
                fprintf("Error remarking %s: %s\n",currentName,errorMessage)

                % save error details
                errorRemarking(idxIDX,:) = {rawEEGs(idx).name, errorMessage, errorLine, errorName};
            end
        end
    end

    errorRemarking = errorRemarking(~cellfun(@isempty,errorRemarking(:,1)),:);
    allErrors.remarking = errorRemarking;
else
    error("Did not select y/n")    
end

%% gather all file paths for subjects remarked data
setfilesDir = [paths.remarked, '/*.set'];
remarked_files = all_remarked_set(setfilesDir);
n = length(remarked_files); % number of EEG sets to preprocess

%% start preprocessing_pipeline_V2()
% overwrite preprocessing files?
% User input whether to overwrite existing files
overwrite_reply = input('Overwrite existing preprocessed files? (y/n): ','s');

if strcmp(overwrite_reply,'y') % y = overwrite existing files; n = skip completed files
    fprintf("Will overwrite existing files\n")
    overwrite = 1;
elseif strcmp(overwrite_reply,'n')
    fprintf('Will skip files already preprocessed\n')
    overwrite = 0;
else
    error('Preprocessing aborted by user.')
end

% User input to determine if running on entire dataset or a particular subject
fullrun_response = input("Run preprocessing on full dataset? (y/n): ",'s');

if strcmp(fullrun_response,'n')
    %% Run on specified subject
    file_match = [];
    while ~any(file_match)
        subid_response = NaN;
        scandate_response = NaN;
        
        % get specific subject to run
        while isnan(subid_response)
            subid_response = input("Input subject ID to run preprocessing on: ",'s');
            if str2double(subid_response) < 10000
                fprintf("Subject ID too small; retry\n")
                subid_response = NaN;
            end
        end
        
        % get specific date to run
        while isnan(scandate_response)
            scandate_response = input("Input scan date to run preprocessing on: ",'s');
            if str2double(scandate_response) < 20000000
                fprintf("Subject ID too small; retry\n")
                scandate_response = NaN;
            end
        end
        
        % find file corresponding to that subject
        file_match = contains(remarked_files, subid_response) & contains(remarked_files, scandate_response);
        if ~any(file_match)
            fprintf("No file matched specified subject ID and date; retry\n")
        end
    end
    
    % match for age and visit
    % get lunaid and eeg date
    splitfilename = split(remarked_files{file_match},"/");
    filename = splitfilename{end};
    splitname = split(filename,"_");
    lunaid = str2double(splitname{1});
    scandate = str2double(splitname{2});
    % find age from demo info
    subidx = find(age_df.lunaid == lunaid & age_df.eeg_date == scandate);

    % set age to NA if unable to find a match
    if isempty(subidx)
        eeg_age = NaN;
        ses = NaN;
        warning("No age found for %d %d!!!",lunaid,scandate)
    else
        eeg_age = age_df(subidx,:).eeg_age;
        ses = age_df(subidx,:).ses;
    end
    
    % restart from beginning or pick up from a particular step?
    step_response = input("Run entire preprocessing pipeline (y/n)?: ",'s');
    if strcmp(step_response,'y') % run entire preprocessing and if overwrite = 0 will not overwrite subject's files
        %% run on specified subject for all preprocessing steps
        % run preprocessing pipeline on subject    
        try
            preprocessing_pipeline_V2(remarked_files{file_match},paths,lowBP,highBP,overwrite,task,study,eeg_age,ses)
        catch e
            % extract error details
            errorMessage = e.message;
            errorLine = e.stack(1).line;
            errorName = e.stack(1).name;
            
            % print error details
            fprintf("Error occured in %s at line %d.\n",errorName, errorLine)
            fprintf("Error processing %s: %s\n",remarked_files{file_match},errorMessage)
        end
    elseif strcmp(step_response,'n')
        %% run on specified subject for a specified step
        % prompt user to chose step to start from 
        stepChoice_msg = sprintf("Steps:\n  (1) Reference to mastoids, filter (bandpass and notch), and downsample \n  (2) Channel rejection\n  (3) Channel interpolation\n  (4) Rerefernce to average\n  (5) Generate ICs\n  (6) Apply ICs\n  (7) IC rejection\n  (8) QC figure\nSelection: ");
        stepChoice_response = input(stepChoice_msg);
        
        % prompt user to say if they want to do manual or auto ICA rejection
        rejIC_response = NaN;
        while isnan(rejIC_response)
            rejIC_response = input("Specify manual or automatic IC rejection: ",'s');
            
            if strcmpi(rejIC_response,'manual') || strcmpi(rejIC_response,'m')
                FLAG_manualICrej = 1;
                fprintf("Running manual IC rejection\n")
            elseif strcmpi(rejIC_response,'automatic') || strcmpi(rejIC_response,'auto') || strcmpi(rejIC_response,'a')
                FLAG_manualICrej = 0;
                fprintf("Running automatic IC rejection\n")
            else
                fprintf("Unable to determine if manual/automatic rejection was selected; retry\n")
                rejIC_response = NaN;
            end
            
        end
        
        % run preprocessing pipeline on subject from step chosen    
        try
            preprocessing_pipeline_V2(remarked_files{file_match},paths,lowBP,highBP,overwrite,task,study,eeg_age,ses,stepChoice_response,FLAG_manualICrej) % run preprocessing from step specified, overwriting if overwrite = 1
        catch e
            % extract error details
            errorMessage = e.message;
            errorLine = e.stack(1).line;
            errorName = e.stack(1).name;
            
            % print error details
            fprintf("Error occured in %s at line %d.\n",errorName, errorLine)
            fprintf("Error processing %s: %s\n",remarked_files{file_match},errorMessage)
        end
        
    else
        
    end
elseif strcmp(fullrun_response,'y')
    %% Loop through every subject to preprocess
    par_option = NaN; % user enters whether to use parallel processing or not

    % Parallel process preproc data?
    while isnan(par_option)
        par_option = input('Use parallel processing for preprocessing? (y/n): ','s');
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
    
    % TODO: add ability to specify step in parallel and non parallel full dataset runs
    % restart from beginning or pick up from a particular step?
    step_response = input("Run entire preprocessing pipeline (y/n)?: ",'s');
    if strcmp(step_response,'n') % run entire preprocessing pipeline
        %% Run entire preprocessing pipeline over entire dataset
        % saving input files that failed to be preprocessed
        errorProcessing = cell(n,4);
        if strcmp(par_option,'y')
            %% Parallel

            % start parallel pool
            if isempty(gcp('nocreate')) % no parallel pool exists
                parpool(num_workers)
            elseif ~isempty(gcp('nocreate')) % parallel pool exists
                p = gcp('nocreate'); % getting parpool object
                if p.NumWorkers == num_workers % keep exisiting parpool if workers are the same number as workers specified
                    fprintf("Parallel pool already running with specified number of workers\n")
                else % delete current parpool and create new parpool if current does not match specified number of workers
                    fprintf("Parallel pool running has %d workers; not %d workers specified...\nDeleting and starting new parallel pool with %d workers",...
                        p.NumWorkers, num_workers, num_workers)         
                    delete(gcp('nocreate'))
                    parpool(num_workers)
                end        
            end

            parfor j = 1:n
                % get lunaid and eeg date
                splitfilename = split(remarked_files{j},"/");
                filename = splitfilename{end};
                splitname = split(filename,"_");
                lunaid = str2double(splitname{1});
                scandate = str2double(splitname{2});
                % find age from demo info
                subidx = find(age_df.lunaid == lunaid & age_df.eeg_date == scandate);

                % set age to NA if unable to find a match
                if isempty(subidx)
                    eeg_age = NaN;
                    ses = NaN;
                    warning("No age found for %d %d!!!",lunaid,scandate)
                else
                    eeg_age = age_df(subidx,:).eeg_age;
                    ses = age_df(subidx,:).ses;
                end

                try
                    preprocessing_pipeline_V2(remarked_files{j},paths,lowBP,highBP,overwrite,task,study,eeg_age,ses)
                catch e
                    % extract error details
                    errorMessage = e.message;
                    errorLine = e.stack(1).line;
                    errorName = e.stack(1).name;

                    % print error details
                    fprintf("Error occured in %s at line %d.\n",errorName, errorLine)
                    fprintf("Error processing %s: %s\n",remarked_files{j},errorMessage)

                    % save error details
                    errorProcessing(j,:) = {remarked_files{j}, errorMessage, errorLine, errorName};
                end
            end
            delete(gcp('nocreate')) % clear parpool

        elseif strcmp(par_option,'n')
            %% Non-parallel
            % displaying waitbar
            w = waitbar(0,sprintf("Starting %s preprocessing...",task),"Name",sprintf("%s preprocessing pipeline",task));

            for j = 1:n
                % get lunaid and eeg_date
                waitbar_filename = split(remarked_files{j},"/");
                waitbar_name = waitbar_filename{end};
                split_name = split(waitbar_name,"_");
                lunaid = str2double(split_name{1});
                scandate = str2double(split_name{2});
                % update waitbar
                waitbar(j/n,w,sprintf("%d %d",lunaid,scandate))
                subidx = find(age_df.lunaid == lunaid & age_df.eeg_date == scandate);

                % set age to NA if unable to find a match
                if isempty(subidx)
                    eeg_age = NaN;
                    ses = NaN;
                    warning("No age found for %d %d!!!",lunaid,scandate)
                else
                    eeg_age = age_df(subidx,:).eeg_age;
                    ses = age_df(subidx,:).ses;
                end

                % try to run preproc pipeline
                try
                    preprocessing_pipeline_V2(remarked_files{j},paths,lowBP,highBP,overwrite,task,study,eeg_age,ses)
                catch e
                    % extract error details
                    errorMessage = e.message;
                    errorLine = e.stack(1).line;
                    errorName = e.stack(1).name;

                    % print error details
                    fprintf("Error occured in %s at line %d.\n",errorName, errorLine)
                    fprintf("Error processing %s: %s\n",remarked_files{j},errorMessage)

                    % save error details
                    errorProcessing(j,:) = {remarked_files{j}, errorMessage, errorLine, errorName};
                end
            end
            close(w)
        end
        errorProcessing = errorProcessing(~cellfun(@isempty,errorProcessing(:,1)),:);
        allErrors.processing = errorProcessing; 
    elseif strcmp(step_response,'y')
        %% Run preprocessing pipeline from a specific step over all subjects
        % prompt user to chose step to start from 
        stepChoice_msg = sprintf("Steps:\n  (1) Reference to mastoids, filter (bandpass and notch), and downsample \n  (2) Channel rejection\n  (3) Channel interpolation\n  (4) Rerefernce to average\n  (5) Generate ICs\n  (6) Apply ICs\n  (7) IC rejection\n  (8) QC figure\nSelection: ");
        stepChoice_response = input(stepChoice_msg);
        % saving input files that failed to be preprocessed
        errorProcessing = cell(n,4);
        if strcmp(par_option,'y')
            %% Parallel
            % start parallel pool
            if isempty(gcp('nocreate')) % no parallel pool exists
                parpool(num_workers)
            elseif ~isempty(gcp('nocreate')) % parallel pool exists
                p = gcp('nocreate'); % getting parpool object
                if p.NumWorkers == num_workers % keep exisiting parpool if workers are the same number as workers specified
                    fprintf("Parallel pool already running with specified number of workers\n")
                else % delete current parpool and create new parpool if current does not match specified number of workers
                    fprintf("Parallel pool running has %d workers; not %d workers specified...\nDeleting and starting new parallel pool with %d workers",...
                        p.NumWorkers, num_workers, num_workers)         
                    delete(gcp('nocreate'))
                    parpool(num_workers)
                end        
            end

            parfor j = 1:n
                % get lunaid and eeg date
                splitfilename = split(remarked_files{j},"/");
                filename = splitfilename{end};
                splitname = split(filename,"_");
                lunaid = str2double(splitname{1});
                scandate = str2double(splitname{2});
                % find age from demo info
                subidx = find(age_df.lunaid == lunaid & age_df.eeg_date == scandate);

                % set age to NA if unable to find a match
                if isempty(subidx)
                    eeg_age = NaN;
                    ses = NaN;
                    warning("No age found for %d %d!!!",lunaid,scandate)
                else
                    eeg_age = age_df(subidx,:).eeg_age;
                    ses = age_df(subidx,:).ses;
                end

                try
                    preprocessing_pipeline_V2(remarked_files{j},paths,lowBP,highBP,overwrite,task,study,eeg_age,ses,stepChoice_response)
                catch e
                    % extract error details
                    errorMessage = e.message;
                    errorLine = e.stack(1).line;
                    errorName = e.stack(1).name;

                    % print error details
                    fprintf("Error occured in %s at line %d.\n",errorName, errorLine)
                    fprintf("Error processing %s: %s\n",remarked_files{j},errorMessage)

                    % save error details
                    errorProcessing(j,:) = {remarked_files{j}, errorMessage, errorLine, errorName};
                end
            end
            delete(gcp('nocreate')) % clear parpool

        elseif strcmp(par_option,'n')
            %% Non-parallel
            % displaying waitbar
            w = waitbar(0,sprintf("Starting %s preprocessing...",task),"Name",sprintf("%s preprocessing pipeline",task));

            for j = 1:n
                % get lunaid and eeg_date
                waitbar_filename = split(remarked_files{j},"/");
                waitbar_name = waitbar_filename{end};
                split_name = split(waitbar_name,"_");
                lunaid = str2double(split_name{1});
                scandate = str2double(split_name{2});
                % update waitbar
                waitbar(j/n,w,sprintf("%d %d",lunaid,scandate))
                subidx = find(age_df.lunaid == lunaid & age_df.eeg_date == scandate);

                % set age to NA if unable to find a match
                if isempty(subidx)
                    eeg_age = NaN;
                    ses = NaN;
                    warning("No age found for %d %d!!!",lunaid,scandate)
                else
                    eeg_age = age_df(subidx,:).eeg_age;
                    ses = age_df(subidx,:).ses;
                end

                % try to run preproc pipeline
                try
                    preprocessing_pipeline_V2(remarked_files{j},paths,lowBP,highBP,overwrite,task,study,eeg_age,ses,stepChoice_response)
                catch e
                    % extract error details
                    errorMessage = e.message;
                    errorLine = e.stack(1).line;
                    errorName = e.stack(1).name;

                    % print error details
                    fprintf("Error occured in %s at line %d.\n",errorName, errorLine)
                    fprintf("Error processing %s: %s\n",remarked_files{j},errorMessage)

                    % save error details
                    errorProcessing(j,:) = {remarked_files{j}, errorMessage, errorLine, errorName};
                end
            end
            close(w)
        end
        errorProcessing = errorProcessing(~cellfun(@isempty,errorProcessing(:,1)),:);
        allErrors.processing = errorProcessing;    
    end
    
else
    error("Did not select y or n")
end

%% create report with data from all QC files
QCfiles = dir(fullfile(paths.qualityCheck, '*.mat'));
nFiles = length(QCfiles);

masterQC = table(zeros(nFiles,1),zeros(nFiles,1), zeros(nFiles,1), zeros(nFiles,1),...
    zeros(nFiles,1), zeros(nFiles,1), zeros(nFiles,1),...
    zeros(nFiles,1), zeros(nFiles,1), zeros(nFiles,1), zeros(nFiles,1),zeros(nFiles,1),zeros(nFiles,1),...
    'VariableNames', {'subid','scandate','eeg_age','session','num_ICs_rej','num_chans_rej',...
    'sec_data_rej','percent_data_rej',...
    'original_var','final_var', 'percent_var_removed', ...
    'final_rank', 'rank_percent'});

for i = 1:nFiles
    
    data = load(fullfile(QCfiles(i).folder, QCfiles(i).name));
    loadQC = data.qc;
    
    masterQC.subid(i) = loadQC.subid;
    masterQC.scandate(i) = loadQC.scandate;
    masterQC.eeg_age(i) = loadQC.eeg_age;
    masterQC.session(i) = loadQC.session;
    % ICs and channles rejected
    masterQC.num_ICs_rej(i) = loadQC.num_ICs_reject;
    masterQC.num_chans_rej(i) = loadQC.num_removed_chans;
    % data rejected
    masterQC.sec_data_rej(i) = loadQC.removed_data; % seconds of removed data
    masterQC.percent_data_rej(i) = loadQC.num_removed_data; % percent of data removed
    % Variance from ICA
    masterQC.original_var(i) = loadQC.original_variance;
    masterQC.final_var(i) = loadQC.final_variance;
    masterQC.percent_var_removed(i) = loadQC.percent_variance_removed;
    masterQC.final_rank(i) = loadQC.final_rank;
    masterQC.rank_percent(i) = 100*(loadQC.final_rank/64);
end

save(fullfile(paths.main, [task '_masterQualityCheck.mat']),'masterQC')

%% option to epoch (run_epoching)
epoch_response = NaN;
while isnan(epoch_response)
    epoch_response = input('Epoch preprocessed data now? (y/n): ','s');
end

if strcmp(epoch_response,'y')
    fprintf("Starting run_epoching()...\n")
    allErrors.epoch = run_epoching(task,maindir);
else
    fprintf("Ending run_preprocessing_V2()...\nTo epoch in future use run_epoching()\n")
end

end