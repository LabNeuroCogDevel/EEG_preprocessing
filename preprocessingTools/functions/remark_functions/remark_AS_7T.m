%% Anti-saccade remark function
function [] = remark_AS_7T(EEG,currentName, preprocVer, outputFolder)
addpath('/Volumes/Hera/Projects/7TBrainMech/scripts/eeg/eog_cal') % need to run eeg_data.m
currentNameSplit = split(currentName,'_');
subjectID = [currentNameSplit{1} '_' currentNameSplit{2}]; % need for eeg_data.m
eegData = eeg_data('#anti',{'Status'},'subjs',{subjectID}); % loading fixed status channel
triggers = unique(eegData.Status); 

% Trigger Values:
% 254 = ITI
% 101-105 = Fixation
% 151-155 = Anti Target

itiLoc = find(eegData.Status == 254); % Find location of ITI in raw status channel
itiDiff = diff(itiLoc); % Don't want locations from the same trial
itiDiffIndex = [1 (find(itiDiff > 1)+1)]; % Need to manually force location 1
itiOnset = itiLoc(itiDiffIndex); % Only want iti at the start of each trial

fixationLoc = find(eegData.Status > 100 & eegData.Status < 106); % Find location of fixation in raw status channel
fixationDiff = diff(fixationLoc); % Don't want locations from the same trial
fixationDiffIndex = [1 (find(fixationDiff > 1) +1)]; % Need to manually force location 1
fixationOnset = fixationLoc(fixationDiffIndex); % Only want fixation at the start of each trial

targetLoc = find(eegData.Status > 150 & eegData.Status < 156); % Find location of target in raw status channel
targetDiff = diff(targetLoc); % Don't want locations from the same trial
targetDiffIndex = [1 (find(targetDiff >1)+1)]; % Need to manually force location 1
targetOnset = targetLoc(targetDiffIndex); % Only want target at the start of each trial

% EEG.event.latency gives index of event in raw EEG signal
% Finding when the latency matches the indicies found above, changing event
% type when latency and index match
eventOnsetIndex = cell2mat({EEG.event(:).latency}); 
for i=1:length(itiOnset)
    itiLatencyIndex(i) = find(eventOnsetIndex == itiOnset(i));
    EEG = pop_editeventvals(EEG,'changefield',{itiLatencyIndex(i),'type',1});
end

for j=1:length(fixationOnset)
    fixationLatencyIndex(j) = find( eventOnsetIndex== fixationOnset(j));
    EEG = pop_editeventvals(EEG,'changefield',{fixationLatencyIndex(j),'type',2});
end

for k = 1:length(targetOnset)
    targetLatencyIndex(k) = find( eventOnsetIndex == targetOnset(k));
    EEG = pop_editeventvals(EEG,'changefield',{targetLatencyIndex(k),'type',3});
end

if ischar(EEG.event(1).type)
    for curr_end_idx = 1:length({EEG.event(:).type})
        EEG.event(curr_end_idx).type = str2num(EEG.event(curr_end_idx).type);
    end
end
eventTypesAfter = cell2mat({EEG.event(:).type}); % getting new event types after remarking

% Some events do not correspond to ITI, fixation or target -> delete event
for b = 1:length(eventTypesAfter)
    if eventTypesAfter(b) > 3
        EEG = pop_editeventvals(EEG,'delete',b);
    end
end


% checking to make sure remarking was done correctly (should have 40 of each mark)
% may get 41 ITI marks
countItiMarks = sum(cell2mat({EEG.event(:).type})==1);
countFixationMarks = sum(cell2mat({EEG.event(:).type})==2);
countTargetMarks = sum(cell2mat({EEG.event(:).type})==3);
fprintf('# ITI Marks: %d\n# Fixation Marks: %d\n# Target Marks: %d\n',countItiMarks,countFixationMarks,countTargetMarks)

clear i j k

%% Renaming AS trials (to include score)
% add path to load AS scores
addpath('/Volumes/Hera/Projects/7TBrainMech/scripts/eeg/eog_cal/trial_data/anti/') % need to load AS score data table
ASscore_filename = sprintf("%d_%d.mat",subid,scandate);
try
    load(ASscore_filename,'thisdata')
catch e
    error('prog:input',...
        "failed to load %s AS score table",ASscore_filename)
end

% thisdata [lunaid, scandate, trial#, intcodes, latency, iscorrect,
%               meanEOG/calslope, veldis/calslope, cal.r2, cal.slope,
%               trialOnsetIndex, dropReason]
% ^^ only care about cols 1,2,3,6, and 11
% just need lunaid, scandate, trial, correct, and trial onset index
subTrialTable = thisdata(:,[1 2 3 6 11]);

trialMatrix = subTrialTable(:,3:5); % col1 = trial #, col2 = score, col3 = trial onset index
ntrials = length(trialMatrix);

% 11537 for some reason has two runs of AS task (i think they are the
% same run)
if ntrials > 40
    trialMatrix = trialMatrix(1:40,:);
    ntrials = 40;
end

% making all event types strings
for nevents=1:length({EEG.event(:).type})
    if ischar(EEG.event(nevents).type)
        continue
    else
        EEG.event(nevents).type = num2str(EEG.event(nevents).type);
    end
end

 % renaming events if trial was correct, error corrected, incorrect, or dropped 
 % trialMatrix: [trial#, score, trialonsetindex]
for triali = 1:ntrials
    % getting this trial's onset index
    trialOnsetIdx = trialMatrix(triali,3);

    % getting this trial's offset index
    if triali ~= 40  % set trial offset index to the next trial's onset index -1
        trialOffsetIdx = trialMatrix(triali+1,3)-1;
    elseif triali == 40 % if last trial set offset index to last index of EEG.data
        trialOffsetIdx = length(EEG.data);
    end

    % subsetting just this trial in EEG.event       
    eventIdx = find(cell2mat({EEG.event(:).latency}) >= trialOnsetIdx & cell2mat({EEG.event(:).latency}) <= trialOffsetIdx);
    trialEvents = EEG.event(eventIdx);
    prepEventIdxTrial = find(cell2mat({trialEvents.type})=='2');
    prepEventIdxWhole = eventIdx(prepEventIdxTrial);

    % getting this trial's score
    trialScore = trialMatrix(triali,2);

    if trialScore == -1
        EEG.event(prepEventIdxWhole).type = '2_drop';
    elseif trialScore == 0
        EEG.event(prepEventIdxWhole).type = '2_incor';
    elseif trialScore == 1
        EEG.event(prepEventIdxWhole).type = '2_cor';
    elseif trialScore == 2
        EEG.event(prepEventIdxWhole).type = '2_errcor';
    end
end

% check that renaming worked
eeg_events = unique({EEG.event.type});
valid_events = {'2_cor','2_errcor','2_incor','2_drop'};
% at least one valid event is present
isValidEvents = any(ismember(eeg_events,valid_events)) & ~ismember('2',eeg_events);

if isValidEvents
    fprintf('Renaming ran correctly\n')
else
    error('Renaming trials did not work')
end

% save EEG structure with newly renamed trial types to look back and check that named trials match with actual trial scores
EEG = pop_saveset( EEG, 'filename',[currentName preprocVer '_Rem.set'],'filepath',char(outputpath));

end