function [] = epochclean(input_file,epoch_folder,marked_epoch_folder,kept_epoch_folder,overwrite,epoch_event, epoch_limits)

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
    epoch_event (1,:) cell    
    epoch_limits (1,2) double = []
end

if isempty(epoch_limits)
    warning('No epoch_limits specified, using default [-1 1]');
    epoch_limits = [-1 1];
end

% what file are we using
if ~exist(input_file,'file')
    error('inputfile "%s" does not exist!', input_file) 
end

[~, currentName, ~] = fileparts(input_file);

% start and end time of epoch 
before = epoch_limits(1);
after = epoch_limits(2);

% defining file save names
marked_epochname = [currentName '_epochs_marked_' char(strjoin(epoch_event,'-')) '.set'];
kept_epochname = [currentName '_epochs_kept_' char(strjoin(epoch_event,'-')) '.set'];
epoch_name = [currentName '_epochs_' char(strjoin(epoch_event,'-')) '.set'];

% skip if kept epoch file exists
if exist(fullfile(kept_epoch_folder, kept_epochname),'file') && overwrite == 0
    fprintf('skipping; already created %s\n',kept_epochname)
    return
end

EEG = pop_loadset(input_file);
if EEG.nbchan~=64
    error('prog:input',"%s does not have 64 channels",currentName)
end

% if processing resting state need to rename starting eyes open and eyes closed blocks
% if resting_state
%     % can only epoch to eyes open or eyes closed for resting state
%     if length(epoch_event) > 1
%         error("Choose either 0/1 for epoching resting state EEG")
%     end   
%     
%     og_epoch_event_num = str2double(epoch_event);
%     
%     % Identify block boundaries
%     in_block = false;
%     blocks = [];
%     
%     % find boundary events
%     types = string({EEG.event(:).type})';
%     boundary_idx = strcmp(types,"boundary");
%     types(boundary_idx) = "999"; % dummy number for boundary events
%     
%     % make types numeric
%     types = str2double(types);
%     
%     for i = 1:length(types)
%         % getting current event type
%         current = types(i);        
%         
%         % look for valid EO/EC marker
%         % is current type the event we are epoching to or a boundary event?
%         if current == og_epoch_event_num || current == 999
%             
%             % if a boundary event outside of a current block do not make new block
%             if ~in_block && current == 999
%                 continue
%             end
%             
%             % start new block if currently not in a block
%             if ~in_block
%                 block_start = i;
%                 block_type = current;
%                 in_block = true;
%             % continue same block
%             elseif current ~= block_type && current ~= 999
%                 blocks(end+1,:) = [block_start i-1 block_type];
%                 block_start = i;
%                 block_type = current;                
%             end
%             
%         % if other marker found -> end block
%         else
%             if in_block
%                 blocks(end+1,:) = [block_start i-1 block_type];
%                 in_block = false;                
%             end
%         end        
%     end
%     
%     % close final block
%     if in_block
%         blocks(end+1,:) = [block_start length(types) block_type];
%     end
%     
%     % 4 blocks should have been found
%     if size(blocks,1) ~= 4
%         error("Expected 4 blocks, found %d",size(blocks,1))
%     end
%     
%     % define new event to start block
%     if og_epoch_event_num == 1
%         epoch_event = {'11'};
%     elseif og_epoch_event_num == 0
%         epoch_event = {'10'};
%     end
%     
%     % chagne EEG structure
%     start_block_idx = blocks(:,1);
%     for idx = start_block_idx'
%         EEG.event(idx).type = string(epoch_event);
%     end
%     EEG = eeg_checkset(EEG,'eventconsistency');        
% end

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

% epoch!
% if there boundary events in the the epoch is not kept
%   => if resting state epoch to 0/1 -4 to +4 instead of getting entire block
EEG = pop_epoch(EEG, epoch_event, [before after], 'newname', epoch_name,'epochinfo','yes');

% save epoched eegsets
EEG = pop_saveset( EEG,'filename',[epoch_name], ...
    'filepath',epoch_folder);

% ~10% should be rejected.

% Two options for epoch rejection: 2nd option is used.

% 1. kurtosis
% kurtosis (not recommended): default 5 for maximum threshold limit. Try that, check how many epochs removed, otherwise higher to 8-10.
% EEG = pop_autorej(EEG, 'nogui','on','eegplot','off');

% 2.Use improbability and thresholding
% Apply amplitude threshold of -500 to 500 uV to remove big artifacts(don't capture eye blinks)
EEG = pop_eegthresh(EEG,1,[1:EEG.nbchan],-500,500,0,EEG.xmax,0,1);

% apply improbability test with 6SD for single channels and 2SD for all channels,
EEG = pop_jointprob(EEG,1,[1:EEG.nbchan],6,2,0,0,0,[],0);

% save marked epochs (to check later if you agree with the removed opochs)
EEG = pop_editset(EEG,'setname',[currentName marked_epochname]);

EEG = pop_saveset( EEG,'filename',[currentName marked_epochname], ...
    'filepath',marked_epoch_folder);

% reject epochs
EEG = pop_rejepoch(EEG, find(EEG.reject.rejjp), 0);

% save epochs rejected EEG data
% this saves the non-rejected epochs
EEG = pop_editset(EEG, 'setname', kept_epochname);

EEG = pop_saveset(EEG, 'filename', kept_epochname, 'filepath',kept_epoch_folder);
end