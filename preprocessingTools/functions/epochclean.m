function [revisar] = epochclean(input_file,epoch_folder,marked_epoch_folder,kept_epoch_folder,overwrite,epoch_event, epoch_limits)

%% function inputs
% input_file = EEG file to be epoched
% epoch_folder = folder to save epoched data before rejection
% marked_epoch_folder = folder to save epochs marked to be rejected
% kept_epoch_folder = folder to save epochs remaining after rejection
% epoch_event = string vector of events to be epoched to
% epoch_limits =  before and after the event (in seconds)

arguments
    input_file
    epoch_folder
    marked_epoch_folder
    kept_epoch_folder
    overwrite
    epoch_event (1,:) string    
    epoch_limits (1,2) double = []
end

if isempty(epoch_limits)
    warning('No epoch_limits specified, using default [-1 1]');
    epoch_limits = [-1 1];
end

revisar = {};
% what file are we using
if ~exist(input_file,'file')
    error('inputfile "%s" does not exist!', input_file) 
end

[~, currentName, ~] = fileparts(input_file);

% start and end time of epoch 
before = epoch_limits(1);
after = epoch_limits(2);

% defining file save names
marked_epochname = [currentName '_epochs_marked_' strjoin(epoch_event,'-') '.set'];
kept_epochname = [currentName '_epochs_kept_' strjoin(epoch_event,'-') '.set'];
epoch_name = [currentName '_epochs_' strjoin(epoch_event,'-') '.set'];

% skip if kept epoch file exists
if exist(fullfile(kept_epoch_folder, kept_epochname),'file') && overwrite == 0
    fprintf('skipping; already created %s\n',kept_epochname)
    return
end

% where to find eeglab stuff
% eeglabpath = fileparts(which('eeglab'));
% [ALLEEG EEG CURRENTSET ALLCOM] = eeglab("nogui");

EEG = pop_loadset(input_file);
if EEG.nbchan~=64
    error('prog:input',"%s does not have 64 channels",currentName)
end

% [ALLEEG EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);


%% epoching
% make all EEG.event.type strings
for i = 1:length(EEG.event)
   if isnumeric(EEG.event(i).type)
       EEG.event(i).type = num2str(EEG.event(i).type);
   elseif iscell(EEG.event(i).type)
       EEG.event(i).type = string(EEG.event(i).type);
   end
end
EEG = eeg_checkset(EEG,'eventconsistency');

% For anti: epoch to fixation onset and get -1 to 1 seconds
EEG = pop_epoch(EEG, epoch_event, [before after], 'newname', epoch_name,'epochinfo','yes');
% [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 4,'overwrite','on','gui','off');

%save epoched eegsets
EEG = pop_saveset( EEG,'filename',[epoch_name], ...
    'filepath',epoch_folder);
% [ALLEEG EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);

% ~10% should be rejected.

%Two options for epoch rejection: 2nd option is used.

%1. kurtosis
%kurtosis (not recommended): default 5 for maximum threshold limit. Try that, check how many
%epochs removed, otherwise higher to 8-10.
% EEG = pop_autorej(EEG, 'nogui','on','eegplot','off');

%2.Use improbability and thresholding
%Apply amplitude threshold of -500 to 500 uV to remove big
% artifacts(don't capture eye blinks)
EEG = pop_eegthresh(EEG,1,[1:EEG.nbchan],-500,500,0,EEG.xmax,0,1);

%apply improbability test with 6SD for single channels and 2SD for all channels,
EEG = pop_jointprob(EEG,1,[1:EEG.nbchan],6,2,0,0,0,[],0);

%save marked epochs (to check later if you agree with the removed opochs)
EEG = pop_editset(EEG,'setname',[currentName marked_epochname]);
% [ALLEEG EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);

EEG = pop_saveset( EEG,'filename',[currentName marked_epochname], ...
    'filepath',marked_epoch_folder);
% [ALLEEG EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);

%reject epochs
EEG = pop_rejepoch(EEG, find(EEG.reject.rejjp), 0);

%save epochs rejected EEG data
%this saves the non-rejected epochs
EEG = pop_editset(EEG, 'setname', kept_epochname);
% [ALLEEG EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);

EEG = pop_saveset(EEG, 'filename', kept_epochname, 'filepath',kept_epoch_folder);
% [ALLEEG EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);