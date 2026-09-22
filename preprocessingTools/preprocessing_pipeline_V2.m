function [] = preprocessing_pipeline_V2(inputfile, outpath, lowBP, highBP, FLAG, condition, task, varargin)
% sanvi korsapathy 06.05.2026
% history of edits: see bottom of file
% runs from run_preprocessing function, or run_par_preprocessing function 

% find file we are using
if ~exist(inputfile,"file")
    error('inputfile "%s" does not exist!', inputfile)
end

%% initialize

% TO DO: Extract study from file path so that the correct cap can be select

[~, currentName, ~ ] = fileparts(inputfile);
parts = split(currentName,'_');
subid = str2double(parts{1});
scandate = str2double(parts{2});
task_type = str2double(parts{3});
preprocVer = str2double(parts{4});
% 
% if task ~= "resting_state"
%     currentName = strjoin(parts(1:end-1), '_');
% end

%% cap locations
eeglabpath = fileparts(which('eeglab'));
cap_location = fullfile(eeglabpath,'/plugins/dipfit/standard_BESA/standard-10-5-cap385.elp');
if ~exist(cap_location, 'file'), error('cannot find file for 64 channel cap: %s', cap_location), end
correction_cap_location = hera('Projects/7TBrainMech/scripts/eeg/Shane/resources/ChanLocMod128to64.ced');
if ~exist(correction_cap_location, 'file'), error('cannot find file for correction 128 channel cap: %s', correction_cap_location), end

%% Files
% to know how far your script is with running
fprintf('==========\n%s:\n\t Initial Preprocessing(%s,%f,%f,%s,%s)\n',...
    currentName, inputfile, lowBP, highBP, outpath.main, task)

% filenames
filter_name = [currentName '_filtered'];
chrm_name   = [currentName '_badchannelrj'];
datarm_name = [currentName '_baddatarj'];
interp_name = [currentName '_interp'];
linenoise_name = [currentName '_removeLineNoise'];
rerefwhole_name = [currentName '_rerefwhole'];
runICA_name = [currentName '_runICA'];
icawholeout_name = [currentName '_ICAwhole'];
icawholemarked_name = [currentName '_MarkedAutoICA'];
icawholeclean_name = [currentName '_CleanICA'];
homogenize_name = [currentName '_CleanICA_Homogenize'];

% file names to check for existing files
icawholeoutFile = fullfile(outpath.ICAwholeclean_homogenize, [homogenize_name '.set']);
filteredFile = fullfile(outpath.filtered, [filter_name '.set']);
lineNoisefile = fullfile(outpath.removeLineNoise, [linenoise_name '.set']);
chanrjfile = fullfile(outpath.channels_rejected, [chrm_name '.set']);
interpfile = fullfile(outpath.interpolated, [interp_name '.set']);
rerefFile = fullfile(outpath.rerefwhole, [rerefwhole_name '.set']);
runICAFile = fullfile(outpath.runICA, [runICA_name '.set']);
WholeICAFile = fullfile(outpath.ICAwhole, [icawholeout_name '.set']);
MarkedICAFile = fullfile(outpath.MarkedICAwhole, [icawholemarked_name '.set']);
CleanICAFile = fullfile(outpath.ICAwholeclean, [icawholeclean_name '.set']);
HomogenizedFile = fullfile(outpath.ICAwholeclean_homogenize, [homogenize_name '.set']);
QC_file = fullfile(outpath.qualityCheck, [currentName '_QC.mat']);

%% channel names
commonPlus = {'AFz','C1','C2','C3','C4','C5','C6','CP1','CP2','CP3','CP4',...
    'CP5','CP6','CPz','Cz','F1','F2','F3','F4','F5','F6','F7','F8','FC1',...
    'FC2','FC3','FC4','FC5','FC6','FCz','Fp1','Fp2','FT10','FT9','Fz','I1',...
    'I2','O1','O2','Oz','P1','P10','P2','P3','P4','P5','P6','P7','P8','P9',...
    'PO10','PO3','PO4','PO7','PO8','PO9','POz','Pz','T7','T8',...
    'AF8','AF7','AF4','AF3'};

%% checking whether or not to rerun
% checking if quality check file already exists (subject already preprocessed)
if condition == 1
    if exist(QC_file, 'file')
        warning('%s already complete! todo load from file', currentName)
        return
    end
end

%% loading filtered EEG if created
% making filtered EEG current EEG if already did filtering
if condition == 1 && exist(filteredFile, 'file')
    warning('%s already filtered! Skipping filtering step.', currentName)
    EEG = pop_loadset(filteredFile);
    
    % making sure Flag128 is set if skipping filtering
    if size(EEG.data) < 100
        % [65 66] are mastoid externals
        Flag128 = 0;
    else
        Flag128 =1;
    end
    
else % if filtered EEG does not exist running rereferencing, filtering, and resampling
    condition = 0; % since new file is created, rerun preproc on new file
    run_filtering
end

%% Notch filter at 60Hz for line noise
if condition == 1 && exist(lineNoisefile, 'file')
    warning('%s already removed line noise! Skipping notch step.', currentName)
    EEG = pop_loadset(lineNoisefile);
else
    condition = 0; % since new file is created, rerun preproc on new file
    EEG = pop_eegfiltnew(EEG, 59, 61, [], 1, [], 0);
    EEG = pop_saveset(EEG, 'filename', linenoise_name, 'filepath', outpath.removeLineNoise);
end

% %% Zap line to remove electrical noise
% if condition == 1 && exist(lineNoisefile, 'file')
%         warning('%s already removed line noise! Skipping ZapLine step.', currentName)
%         EEG = pop_loadset(lineNoisefile);
%     else
%         condition = 0; % since new file is created, rerun preproc on new file
% 
%         EEG = clean_data_with_zapline_plus_eeglab_wrapper(EEG, struct('noisefreqs', [60]));
%         zapReportPath = fullfile(outpath.removeLineNoise, linenoise_name);
%         saveas(gcf, zapReportPath, 'png'); % save ZapLine report to same folder as data
% 
%         % save data without line noise
%         EEG = pop_saveset(EEG, 'filename', linenoise_name, 'filepath', outpath.removeLineNoise);
% end

%% Channels
if condition == 1 && exist(chanrjfile, 'file')
    warning('%s already removed bad channels! Skipping channel rejection step.', currentName)
    EEG = pop_loadset(chanrjfile);
else
    condition = 0; % since new file is created, rerun preproc on new file
    run_channel_rejection
end

%% Interpolate Channels
% POSSIBLE PROBLEMS
%  - injecting extra channels ontop of expected 64 (n>64)
%  - 128 missing expected labels, adding too few back (n<64)
if condition == 1 && exist(interpfile, 'file')
    warning('%s already interpolated! Skipping interpolation step.', currentName)
    EEG = pop_loadset(interpfile);
else
    condition = 0; % since new file is created, rerun preproc on new file
    run_channel_interpolation
end

%% Re-reference: Average Reference
if condition == 1 && exist(rerefFile, 'file')
    warning('%s already rereferenced! Skipping rereferencing step.', currentName)
    EEG = pop_loadset(rerefFile);
else
    condition = 0; % since new file is created, rerun preproc on new file
    run_rereference
end

%% run ICA on downsampled data
if condition == 1 && exist(runICAFile, 'file')
    warning('%s already ran ICA! Skipping ICA decomposition step.', currentName)
    EEG = pop_loadset(runICAFile);
else
    condition = 0; % since new file is created, rerun preproc on new file
    icawholein = fullfile(outpath.rerefwhole, [rerefwhole_name '.set']);
    wholeout = outpath.ICAwhole;
    
    % create copy of rereferenced file and downsample to 256Hz to run ICA
    EEG_down = EEG;
    EEG_down = pop_resample(EEG_down, 256, 0.8, 0.4); % why 0.8 and 0.4?
    inputRank = EEG_down.nbchan - EEG_down.channels_rj_nr-1;
    tic
    EEG_down = pop_runica(EEG_down,'icatype','runica','extended',1,'PCA',inputRank); 
    toc
    EEG_down = pop_saveset(EEG_down, 'filename', runICA_name, 'filepath', outpath.runICA);
end

if condition == 1 && exist(WholeICAFile, 'file')
    warning('%s already applied ICA! Skipping ICA application step.', currentName)
    EEG = pop_loadset(WholeICAFile);
else
    condition = 0;
    % apply ICA decomposition from downsampled data to 512Hz data
    EEG_down = pop_loadset(runICAFile);
    EEG.icaweights = EEG_down.icaweights;
    EEG.icasphere = EEG_down.icasphere;
    EEG.icawinv = EEG_down.icawinv;
    EEG.icachansind = EEG_down.icachansind;
    EEG = pop_saveset(EEG, 'filename', icawholeout_name, 'filepath', outpath.ICAwhole);

end


%% select ICA components to reject
if condition == 1 && exist(CleanICAFile, 'file')
    warning('%s already automatically rejected ICs! Skipping IC rejection step.', currentName)
    EEG = pop_loadset(CleanICAFile);
else
    condition = 0; % since new file is created, rerun preproc on new file
    run_autoICArejection
end


%% Homogenize Chanloc
if condition == 1 && exist(HomogenizedFile, 'file')
    warning('%s already automatically homogenized! Skipping homogenize step.', currentName)
    EEG = pop_loadset(HomogenizedFile);
else
    datapath = outpath.ICAwholeclean;
    savepath = outpath.ICAwholeclean_homogenize;
    correction_cap_location = hera('Projects/7TBrainMech/scripts/eeg/Shane/resources/ELchanLoc.ced');
    CL = importdata(correction_cap_location);
    CL.n = CL.textdata(2:end-2,1);
    CL.name = CL.textdata(2:end-2,2);
    
    EEG_old  = EEG;
    CL_old.name = {EEG_old.chanlocs.labels}';
    CL_old.n = {EEG_old.chanlocs.urchan}';
    
    differ = find(~strcmp(CL.name, CL_old.name(1:64)));
    for idealIDX = differ'
        previousIDX = find(strcmp(CL.name(idealIDX), CL_old.name));
        EEG.chanlocs(idealIDX) = EEG_old.chanlocs(previousIDX);     % update ChanLoc
        EEG.chanlocs(idealIDX).urchan  = idealIDX;                  % update number *maybe not mandatory
        EEG.data(idealIDX,:) = EEG_old.data(previousIDX,:);         % move data
    end
    EEG = pop_saveset(EEG, 'filename', homogenize_name, 'filepath', outpath.ICAwholeclean_homogenize);
    condition = 0;
end

if condition == 0
    figure;
    spectopo(EEG.data,0,EEG.srate, 'freqrange', [2 70]);
    title(sprintf('SubID: %s, Scan Date: %s', parts{1}, parts{2}));
    savefig(fullfile(outpath.finalSpectra,[currentName '.fig']));
    exportgraphics(gcf,fullfile(outpath.finalSpectra,[currentName '.png']));
    close all;
end

create_eeg_qc_file

end

%% History of Edits
%06.05.26 SK
% modifications made to original pipeline

% runICA evaluates number of components based on the current rank of the
% data (number of original channels - number of channels interpolated - 1)
% - additional -1 because we average reref

% reference separate scripts for most preprocessing steps to simplify

% implement automatic ICA rejection, see run_autoICArejection for the
% defined parameters for rejection

% create Quality Check file to check the quality of the automatically
% processed data

% also saves a spectra of the preprocessed to check data quality

% remove instances of saving to ALLEEG (unnecessary and will interfere
% with parallel processing)


