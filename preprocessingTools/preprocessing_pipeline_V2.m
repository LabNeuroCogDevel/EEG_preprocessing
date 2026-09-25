function [] = preprocessing_pipeline_V2(inputfile, outpath, lowBP, highBP, overwrite, task, study, eeg_age, ses)
% sanvi korsapathy 06.05.2026
% abby beatt
% history of edits: see bottom of file
% runs from run_preprocessing function, or run_par_preprocessing function 

arguments
    inputfile
    outpath
    lowBP
    highBP
    overwrite
    task
    study
    eeg_age (1,1) double = []
    ses (1,1) double = []
end

% find file we are using
if ~exist(inputfile,"file")
    error('inputfile "%s" does not exist!', inputfile)
end

%% initialize

[~, currentName, ~ ] = fileparts(inputfile);
parts = split(currentName,'_');
subid = str2double(parts{1});
scandate = str2double(parts{2});
task_type = parts{3};
preprocVer = parts{4};
 
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
fprintf('==========\n%d %d:\n\t Initial Preprocessing(%.1f,%.1f,%s)\n',...
    subid, scandate,lowBP, highBP, task)

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
if overwrite ==  0
    if exist(QC_file, 'file')
        warning('%s already complete! todo load from file', currentName)
        return
    end
end

%% loading filtered EEG if created
% making filtered EEG current EEG if already did filtering
if overwrite ==  0 && exist(filteredFile, 'file')
    warning('%s already filtered! Skipping filtering step.', currentName)
    EEG = pop_loadset(filteredFile);
    
    % making sure Flag128 is set if skipping filtering
    if size(EEG.data,1) < 100
        % [65 66] are mastoid externals
        Flag128 = 0;
    elseif size(EEG.data,1) > 100
        Flag128 = 1;
    end
    
else % if filtered EEG does not exist running rereferencing, filtering, and resampling
    overwrite = 1; % since new file is created, rerun preproc on new file
    run_filtering
end

%% add age and session number to EEG structure
EEG.eeg_age = eeg_age;
EEG.session = ses;

%% Notch filter at 60Hz for line noise
if overwrite == 0 && exist(lineNoisefile, 'file')
    warning('%s already removed line noise! Skipping notch step.', currentName)
    EEG = pop_loadset(lineNoisefile);
else
    overwrite = 1; % since new file is created, rerun preproc on new file
    EEG = pop_eegfiltnew(EEG, 59, 61, [], 1, [], 0);
    EEG = pop_editset(EEG,'setname',linenoise_name);
    EEG = pop_saveset(EEG, 'filename', linenoise_name, 'filepath', outpath.removeLineNoise);
end

%% Channels
if overwrite == 0 && exist(chanrjfile, 'file')
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
if overwrite == 0 && exist(interpfile, 'file')
    warning('%s already interpolated! Skipping interpolation step.', currentName)
    EEG = pop_loadset(interpfile);
else
    overwrite = 1; % since new file is created, rerun preproc on new file
    run_channel_interpolation
end

%% Re-reference: Average Reference
if overwrite == 0 && exist(rerefFile, 'file')
    warning('%s already rereferenced! Skipping rereferencing step.', currentName)
    EEG = pop_loadset(rerefFile);
else
    overwrite = 1; % since new file is created, rerun preproc on new file
    run_rereference
end

%% run ICA on downsampled data
% Compute ICA components on downsampled data (for speed)
if overwrite == 0 && exist(runICAFile, 'file')
    warning('%s already ran ICA! Skipping ICA decomposition step.\nLoading in rereferenced file', currentName)
    EEG = pop_loadset(rerefFile); % need to load in referenced file b/c if ICA decomp worked but error in applying to non-downsampled data new EEG saved will have 256 Hz sampling rate
else
    overwrite = 1; % since new file is created, rerun preproc on new file
%     icawholein = fullfile(outpath.rerefwhole, [rerefwhole_name '.set']);
%     wholeout = outpath.ICAwhole;
    
    % create copy of rereferenced file and downsample to 256Hz to run ICA
    EEG_down = EEG;
    EEG_down = pop_resample(EEG_down, 256, 0.8, 0.4); % why 0.8 and 0.4?
    inputRank = EEG_down.nbchan - EEG_down.channels_rj_nr-1;
    tic
    EEG_down = pop_runica(EEG_down,'icatype','runica','extended',1,'PCA',inputRank); 
    toc
    EEG_down = pop_saveset(EEG_down, 'filename', runICA_name, 'filepath', outpath.runICA);
end

% 
if overwrite == 0 && exist(WholeICAFile, 'file')
    warning('%s already applied ICA! Skipping ICA application step.', currentName)
    EEG = pop_loadset(WholeICAFile);
else
    overwrite = 1;
    % apply ICA decomposition from downsampled data to 512Hz data
    EEG_down = pop_loadset(runICAFile); % load in runICAFile to apply ICA decomp to non-downsampled rereferenced data
    EEG.icaweights = EEG_down.icaweights;
    EEG.icasphere = EEG_down.icasphere;
    EEG.icawinv = EEG_down.icawinv;
    EEG.icachansind = EEG_down.icachansind;
    EEG = pop_saveset(EEG, 'filename', icawholeout_name, 'filepath', outpath.ICAwhole);
end


%% select ICA components to reject
if overwrite == 0 && exist(CleanICAFile, 'file')
    warning('%s already automatically rejected ICs! Skipping IC rejection step.', currentName)
    EEG = pop_loadset(CleanICAFile);
else
    overwrite = 1; % since new file is created, rerun preproc on new file
    run_autoICArejection
end


%% Homogenize Chanloc

if strcmp(study,'7T')
    if overwrite == 0 && exist(HomogenizedFile, 'file')
        warning('%s already automatically homogenized! Skipping homogenize step.', currentName)
        EEG = pop_loadset(HomogenizedFile);
    else
%         datapath = outpath.ICAwholeclean;
%         savepath = outpath.ICAwholeclean_homogenize;
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
        overwrite = 1;
    end
end

%% Create QC figure (spectrum of each channel)
if overwrite == 1
    figure;
    spectopo(EEG.data,0,EEG.srate, 'freqrange', [2 70]);
    title(sprintf('SubID: %d, Scan Date: %d', subid,scandate));
%     savefig(fullfile(outpath.finalSpectra,[currentName '.fig']));
    exportgraphics(gcf,fullfile(outpath.finalSpectra,[currentName '.png']));
    close all;
end

%% Create QC file
qc = struct();

% general information
qc.preproc_ver = preprocVer;
qc.task = task_type;
qc.subid = subid;
qc.scandate = scandate;
qc.removed_chans = EEG.channels_rj;
qc.num_removed_chans = EEG.channels_rj_nr;
qc.removed_data = EEG.data_rj;
qc.num_removed_data = EEG.data_rj_nr;

% ICA component informaiton
EEGICA = pop_loadset(MarkedICAFile);
rejectedICs = find(EEGICA.reject.gcompreject);
qc.num_ICs_reject = numel(rejectedICs);
% define the IC class label the components removed got
ICclass = EEGICA.etc.ic_classification.ICLabel.classifications;
rejectedICs_classes = ICclass(rejectedICs,:);
% names of classes
classNames = EEGICA.etc.ic_classification.ICLabel.classes;
[~,classIdx] = max(rejectedICs_classes,[],2); % just get class which the component ranked the highest in

for i = 1:numel(rejectedICs) % add info to qc struct
    qc.ICs_reject(i).IC = rejectedICs(i);
    qc.ICs_reject(i).ICs_reject_classification = ICclass(rejectedICs(i),:);
    qc.ICs_reject(i).ICs_reject_main_class = classNames{classIdx(i)};
end

% add variance before and after ICA
qc.original_variance= EEG.etc.varBeforeICArej;
qc.final_variance = EEG.etc.varAfterICArej;
removedVar = qc.original_variance-qc.final_variance;
percentVarRemoved = 100*removedVar/qc.original_variance;
qc.percent_variance_removed = percentVarRemoved;

% add final rank of the data
qc.final_rank = rank(EEG.data');
save(fullfile(QC_file),'qc');

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


