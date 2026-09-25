%% load EEG set and re-reference to mastoids
EEG = pop_loadset(inputfile);

if size(EEG.data,1) < 100
    % [65 66] are mastoid externals
    Flag128 = 0;
    EEG = pop_reref(EEG, [65 66]);
    EEG = eeg_checkset(EEG);
else
    Flag128 = 1;
    %[129 130] are the mastoid externals for the 128 electrode
    EEG = pop_reref(EEG, [129 130]);
    EEG = eeg_checkset(EEG);
end

EEG.subject = subid;
EEG.scandate = scandate;
EEG.task = task_type;

%% Filtering
EEG = pop_eegfiltnew(EEG, lowBP, highBP, 3380, 0, [], 0);
% inputs: (EEG, locutoff, hicutoff, filtorder, revfilt, usefft, plotfreqz, minphase);
% revfilt- reverse filter 0=bandpass, 1=notch
% usefft- [] ignore (use fft to filter)
% plotfreqz- plot frequency bode plots for filter 0=don't plot, 1=plot
% filtorder = 3380 - filter order (filter length - 1). Mandatory even. performing 3381 point bandpass filtering.

% give a new setname and overwrite unfiltered data
EEG = pop_editset(EEG,'setname',[currentName '_bandpass_filtered']);

%% Resample Data
% Downsample the data to 512 Hz using anti-aliasing filter if raw data was collected at a higher sampling frequency
if EEG.srate > 512
    EEG = pop_resample(EEG, 512, 0.8, 0.4);
    %0.8 is fc and 0.4 is df. Default is .9 and .2. We dont know why Alethia changed them
    % df = anti-aliasing filter transition band width
    % fc = anti-aliasing filter cutoff
end

EEG = eeg_checkset(EEG);

%change setname
EEG = pop_editset(EEG,'setname',filter_name);

%save filtered data
EEG = pop_saveset(EEG, 'filename',filter_name, ...
    'filepath',outpath.filtered);
