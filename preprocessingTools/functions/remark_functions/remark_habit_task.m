%% Habit task EEGs
function [] = remark_habit_task(EEG,currentName, preprocVer, outputFolder)
addpath('/Volumes/Hera/Projects/7TBrainMech/scripts/eeg/eog_cal') % need to run eeg_data.m

% if events are characters convert to numeric
types = {EEG.event(:).type};
ischartype = cellfun(@ischar, types);
numerictypes = types;
numerictypes(ischartype) = cellfun(@str2double, types(ischartype), 'UniformOutput',false);
[EEG.event(:).type] = numerictypes{:};
EEG = eeg_checkset(EEG, 'eventconsistency');

% some EEGs have 16128 as the first event others have 16256
% ^ should be 16128 for correct remarking with make_photodiodevector()
firsttype = EEG.event(1).type;
if firsttype == 16256
    EEG.event(1).type = 16128;
end

mark = [EEG.event(:).type];
markmin = min(mark);
if markmin ~= 16128
    error("Cannot remark; min mark prior to remarking is not 16128")
else
    % use photodiode to get simple marks
    [micromed_time, mark] = make_photodiodevector(EEG);
end

% change timing to photodiodes then remove photodiode events
% photodiode is the actual timing of the events
% ideal times for iti, choice, and waiting should be moved back the the photodiode trigger
idxPD = find(mark == 1);
origlatency = [EEG.event(:).latency]';

% reassign latency to remaining events
for k = idxPD
    prev_idx = k-1;
    if prev_idx >= 1
        EEG.event(prev_idx).latency = origlatency(k);
    end                
end
% remove photodiode from events
idxPD = sort(idxPD,'descend');
EEG = pop_editeventvals(EEG,'delete',idxPD);            
mark(idxPD) = [];
EEG = eeg_checkset(EEG, 'eventconsistency');

% 15 trigger did not get encoded so fix
% this occurs for these sequences: [14 24 2 164 224] 
%                                  [14 24 2 164 214]
%       ^ this should actually be: [14 24 2 165 225]
%                                   [14 24 2 165 215]

% want to find when left and up are the choices (24) and they choose left (2)
%             seq = [14 24 2];
seq = [24 2];
starting_idx = strfind(mark, seq);
for i = starting_idx
   x = mark(i:end);
   % find the next time mark is between 160 and 168
   choice = find(x>= 160 & x <= 168,1,'first');
   if x(choice) ~= 165
        x(choice) = x(choice) + 1;
   end
   % find the next time mark is between 210 and 228
   feedback = find(x>= 210 & x<= 228,1,'first');
   if x(feedback) ~= 225 || x(feedback) ~= 215
        x(feedback) = x(feedback) +1;
   end
   mark(i:end) = x;               
end

% make simple marks
simple = nan(size(mark));
% button pushes (change to how they are coded for waiting and feedback)            
simple(mark==2) = 1; % left button
simple(mark==3) = 2; % up button
simple(mark==4) = 3; % right button
% iti
simple(mark>=10 & mark<=15) = 10;
% choice
simple(mark >=23 & mark <=25) = mark(mark>=23 & mark<=25);
% waiting (indicate direction they picked)
simple(mark == 163 | mark == 165) = 31; % left choice
simple(mark == 166 | mark == 164) = 32; % up choice
simple(mark == 168 | mark == 167) = 33; % right choice
% feedback (indicate whether it was rewarded or not)
simple(mark>=213 & mark <=218) = 100; % no reward
simple(mark>= 223 & mark <= 228) = 200; % reward
% timeout (70s)
simple(mark>=70 & mark <80) = 70;
% survey
simple(mark==230) = 230;
simple(isnan(simple)) = 999;

% rename types to simple values
EEG = pop_editeventfield(EEG, 'type', simple);
EEG = eeg_checkset(EEG,'eventconsistency'); 

% add trial number to EEG event structure (for later analyses)
events = [EEG.event(:).type]';
% end of a single trial denoted by reward, no reward, or time-out
end_trial_idx = find(events == 200 | events == 100 | events == 70);

% define first trial start index
curr_start_idx = 1;
% define trial 1 (to be increased over for loop)
trial = 1;
for curr_end_idx = end_trial_idx'     
    % add current trial number to EEG event structure
    [EEG.event(curr_start_idx:curr_end_idx).trial] = deal(trial);
    curr_start_idx = curr_end_idx +1;
    trial = trial +1;                
end

% check that adding trials worked
check_trials = unique([EEG.event.trial]);
num_trials = max(check_trials);

if length(check_trials) < 216
    error('Did not correctly add trial number to event field')
else
    EEG.num_trials = num_trials;
    EEG = pop_saveset( EEG, 'filename',[currentName '_' preprocVer '_Rem.set'],'filepath',char(outputpath));
end

end