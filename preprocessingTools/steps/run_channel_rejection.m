% define channel locations

if strcmp(study, '7T') || strcmp(study,'Habit')
    % just need to remove external channels
    EEG = pop_chanedit(EEG, 'lookup', cap_location);
    
    % remove external channels
    EEG = pop_select( EEG,'nochannel',{'EX3' 'EX4' 'EX5' 'EX6' 'EX7' 'EX8' 'EXG1' 'EXG2' 'EXG3' 'EXG4' 'EXG5' 'EXG6' 'EXG7' 'EXG8' 'GSR1' 'GSR2' 'Erg1' 'Erg2' 'Resp' 'Plet' 'Temp' 'FT7' 'FT8' 'TP7' 'TP8' 'TP9' 'TP10'});

elseif strcmp(study,'SPA')
    % SPA caps
    % Channel --> Label
    % AF1 (2) --> AF3
    % AF5 (3) --> AF7
    % TP7 --> NA
    % FT9 (11) --> FT7
    % AF2 (35) --> AF4
    % AF6 (36) --> AF8
    % FT10 (46) --> FT8
    % I2 (64) --> Iz
    % TP8 --> NA
    % Not using:
    % PO9, PO10, or I1

    % JUST SPA:
    EEG.chanlocs(2).labels = 'AF3';
    EEG.chanlocs(3).labels = 'AF7';
    EEG.chanlocs(11).labels = 'FT7';
    EEG.chanlocs(35).labels = 'AF4';
    EEG.chanlocs(36).labels = 'AF8';
    EEG.chanlocs(46).labels = 'FT8';
    EEG.chanlocs(64).labels = 'Iz';
    
    EEG = pop_chanedit(EEG, 'lookup', cap_location);
    
    % remove external channels and non-used channels
    EEG = pop_select( EEG,'nochannel',{'EX3' 'EX4' 'EX5' 'EX6' 'EX7' 'EX8' 'TP7' 'TP8' 'PO9' 'I1' 'PO10'});

end

% fixing if 128 channel setup
if size(EEG.data,1) > 100
    EEG = pop_select( EEG,'channel',commonPlus);
    EEG = pop_chanedit(EEG, 'load', {correction_cap_location 'filetype' 'autodetect'});
    % 128    'AF8' --> 64    'AF6'
    % 128    'AF7' --> 64    'AF5'
    % 128    'AF4' --> 64    'AF2'
    % 128    'AF3' --> 64    'AF1'
end

%% Bad Channel Rejection
% bad channels are in general the channels that you can't save even if you reject 5-10% of your datapoints
% from eeglab wiki: plot channel spectrum and ID outliers with spectopo()
% 3 options for channel rejection:
% 1. look at standard deviation in bar plots and remove the channels
% 2. kurtosis
% 3. clean_rawdata - this method removed events from EEG set and lost individual anti trials
% maybe use clean_rawdata but need to tweak from original pipeline

% originalEEG has channel locations and external channels removed- need for determining which channels have been rejected
originalEEG = EEG;

EEG = clean_rawdata(EEG, 8, -1, 0.7, 5, 15, 0.3);
% clean_rawdata inputs:
% (EEG, arg_flatline, arg_highpass, arg_channel, arg_noisy, arg_burst,arg_window)
% see clean_rawdata for description of what inputs mean
% arg_highpass = -1 : already highpassed data do not need to do again
% LOOK AT OTHER PARAMETERS

%change setname
EEG = pop_editset(EEG,'setname', chrm_name);

EEG = pop_saveset( EEG,'filename', chrm_name, ...
    'filepath', outpath.channels_rejected);

% what is clean_channel_mask???
if ~any(find(cellfun (@any,regexpi (fieldnames(EEG.etc), 'clean_channel_mask'))))
    EEG.etc.clean_channel_mask=42;
end

%save the channels that were rejected in a variable
channels_removed{1} = chrm_name; %setname
channels_removed{2} = setdiff({originalEEG.chanlocs.labels},{EEG.chanlocs.labels}, 'stable');
channels_removed{3} = find(EEG.etc.clean_channel_mask==0);

%also save the channels that were rejected in the EEG struct
EEG.channels_rj = channels_removed{2};
EEG.channels_rj_nr = length(EEG.channels_rj);

%save the proportion of the dataset that were rejected in a variable
data_removed{1} = datarm_name; %setname
data_removed{2} = length(find(EEG.etc.clean_sample_mask==0))/EEG.srate;%
data_removed{3} = length(find(EEG.etc.clean_sample_mask==0))/length(EEG.etc.clean_sample_mask);%

%also save the data that were rejected in the EEG struct
EEG.data_rj    = data_removed{2};
EEG.data_rj_nr = data_removed{3};