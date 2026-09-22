function [] = rename_AStrials(remarked_inputfile,outpath)

% find file we are using
if ~exist(remarked_inputfile,"file")
    error('remarked_inputfile "%s" does not exist!', remarked_inputfile)
end

[d, currentName, ext ] = fileparts(remarked_inputfile);
parts = split(currentName,'_');
subid = str2double(parts{1});
scandate = str2double(parts{2});
task = str2double(parts{3});
preprocVer = str2double(parts{4});

currentName = [parts{1} '_' parts{2} '_' parts{3} '_' parts{4}];

% save names and where to save
outpath = outpath;
renamed_filename = [currentName '_renamedtrials.set'];

% if file exists skip
if isfile(fullfile(outpath,renamed_filename)) % if renamed file exists making that current EEG
    fprintf("skipping; Renamed %s \n",currentName)
    return
else
    %% Renaming anti-saccade trials
    % load EEG
    EEG = pop_loadset('filename',remarked_inputfile);
    
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

    % save EEG structure with newly renamed trial types to look back and
    % check that named trials match with actual trial scores
    EEG = pop_saveset(EEG,'filename',renamed_filename,'filepath',outpath);


end
