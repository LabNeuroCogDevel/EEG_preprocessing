function [EEG] = remark(output_folder,dryrun,task,rawdir,preprocVer,condition)
% abby updated 6/9/26 to remark across all studies
% add condition to inputs - abby beatty 07.06.2026
% fixing habit remarking 07.07.2026 - abby beatty

addpath('/Volumes/Hera/Projects/7TBrainMech/scripts/eeg/eog_cal') % need to run eeg_data.m

path_file = rawdir;
outputpath = output_folder;

d = path_file;

preprocVer = ['_preprocVer' preprocVer];

namesOri = dir(fullfile(d, '*', '*.bdf'));

if lower(task) == "mgs"
    %% Memory-guided saccade
    mgsIDX = find (cellfun (@any,regexpi ( {namesOri.name}.', 'mgs')));

    for idx = mgsIDX'
        
        currentName = regexprep(namesOri(idx).name,'\.bdf$','');
        d = [namesOri(idx).folder '/'];

        %% skip if we've already done
        finalfile=fullfile(outputpath, [currentName preprocVer '_Rem.set']);
        if exist(finalfile,'file') && condition == 1
            fprintf('already have %s\n', finalfile)
            continue
        end
        if dryrun
            fprintf('want to run %s; set dryrun=0 to actually run\n', finalfile)
            continue
        end
        fprintf('making %s\n',finalfile);

        %% load EEG set
        EEG = pop_biosig([d currentName '.bdf']);
        EEG.setname=[currentName 'Rem']; %name the EEGLAB set (this is not the set file itself)

        eeglab redraw

        [micromed_time,mark]=make_photodiodevector(EEG);

%         mark = mark - min(mark(mark>0));
%         mark(mark>65000) = 0;
        % isi (150+x) and iti (254) are different
        %    event inc in 50: (50-200: cue=50,img=100,isi=150,mgs=200)
        %    category inc in 10 (10->30: None,Outdoor,Indoor)
        %    side inc in 1 (1->4: Left -> Right)
        %        61 == cue:None,Left
        %        234 == mgs:Indoor,Right
        %1 254 = ITI
        %2 50<cue<100 [50+(c 10,20,30)+(s,1-4)]
        %3 100<img.dot<150 [100+(c 10,20,30)+(s,1-4)] +/-
        %4 150<delay<200 [150+(c 10,20,30)]
        %5 200<mgs<250 [200+(c 10,20,30)+(s,1-4)]

        ending = mod(mark',10);

        simple = nan(size(mark));
        simple(mark == 254)= 1;
        simple(mark>=50 & mark<100)= 2;
        simple(mark>=100 & mark<150 & ((ending == 1) + (ending == 2))')= -3;
        simple(mark>=100 & mark<150 & ((ending == 3) + (ending == 4))')= 3;

        simple(mark>=150 & mark<200)= 4;
        simple(mark>=200 & mark<250 & ((ending == 1) + (ending == 2))')= -5;
        simple(mark>=200 & mark<250 & ((ending == 3) + (ending == 4))')= 5;

        for i=unique(simple)
            mmark=find(simple==i);
            if ~isempty(mmark)
                for j = 1:length(mmark)
                    EEG = pop_editeventvals(EEG,'changefield',{mmark(j) 'type' i});
                end
            end
        end

        EEG = pop_saveset( EEG, 'filename',[currentName preprocVer '_Rem.set'],'filepath',outputpath);

    end


elseif lower(task) == "anti"
    %% Anti-saccade
    antiIDX = find (cellfun (@any,regexpi ( {namesOri.name}.', 'anti')));

        for idx = antiIDX'

            currentName = namesOri(idx).name(1:end-4);
            currentNameSplit = split(currentName,'_');
            subjectID = [currentNameSplit{1} '_' currentNameSplit{2}]; % need for eeg_data.m
            d = [namesOri(idx).folder '/'];

            % skipping 11834_20210628 b/c anti trial is 1545 secs (most are ~120 secs)
            if currentName == "11834_20210628_anti"
                warning(sprintf('subject %s has and AS run of 1544 seconds',currentName))
                continue
            end

            % skip if already been remarked
            finalfile=fullfile(outputpath, [currentName preprocVer '_Rem.set']);
             if exist(finalfile,'file') && condition == 1
                 fprintf('already have %s\n', finalfile)
                 continue
             end
             if dryrun
                 fprintf('want to run %s; set dryrun=0 to actually run\n', finalfile)
                 continue
             end
            fprintf('making %s\n',finalfile);

            % loading EEG data
            f = [d currentName '.bdf'];
            EEG = pop_biosig(f);
            EEG.setname=[currentName 'Rem']; %name the EEGLAB setclc (this is not the set file itself)
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

            EEG = pop_saveset( EEG, 'filename',[currentName preprocVer '_Rem.set'],'filepath',char(outputpath));

        % checking to make sure remarking was done correctly (should have 40 of each mark)
        % may get 41 ITI marks
            countItiMarks = sum(cell2mat({EEG.event(:).type})==1);
            countFixationMarks = sum(cell2mat({EEG.event(:).type})==2);
            countTargetMarks = sum(cell2mat({EEG.event(:).type})==3);
            fprintf('# ITI Marks: %d\n# Fixation Marks: %d\n# Target Marks: %d\n',countItiMarks,countFixationMarks,countTargetMarks)

            clear i j k
        end
    
elseif lower(task) == "resting_state"
    %% Resting state

    restIDX = find (cellfun (@any,regexpi ( {namesOri.name}.', 'rest')));
    %test_restIDX = restIDX(1:11);
    for idx = restIDX'
        
        currentName = regexprep(namesOri(idx).name,'\.bdf$','');
        d = [namesOri(idx).folder '/'];

        %% skip if we've already done
        finalfile=fullfile(outputpath, [currentName preprocVer '_Rem.set']);
        if exist(finalfile,'file') && condition == 1
            fprintf('already have %s\n', finalfile)
            continue
        end
        if dryrun
            fprintf('want to run %s; set dryrun=0 to actually run\n', finalfile)
            continue
        end
        fprintf('making %s\n',finalfile);

        %% load EEG set
        EEG = pop_biosig([d currentName '.bdf']);
        EEG.setname=[currentName 'Rem']; %name the EEGLAB set (this is not the set file itself)

%         eeglab redraw

        [micromed_time,mark]=make_photodiodevector(EEG);
        
        % check that remarking worked                
        EEG = pop_editeventfield(EEG, 'type', mark);
        EEG = eeg_checkset(EEG,'eventconsistency');
        
%         for i=unique(mark)
%             mmark=find(mark==i);
%             if ~isempty(mmark)
%                 for j = 1:length(mmark)
%                     %             EEG.event(mmark).type = cond{i+1};
%                     EEG = pop_editeventvals(EEG,'changefield',{mmark(j) 'type' i});
%                 end
%             end
%         end

        EEG = pop_saveset( EEG, 'filename',[currentName preprocVer '_Rem.set'],'filepath',outputpath);

    end

elseif task == "SNR"
    %% Auditory steady state

    AudSSIDX = find (cellfun (@any,regexpi ( {namesOri.name}.', 'ss')));

    for idx = AudSSIDX'

        currentName = namesOri(idx).name(1:end-4);
        d = [namesOri(idx).folder '/'];

        % skip if we've already done
        finalfile=fullfile(outputpath, [currentName preprocVer '_Rem.set']);
        if exist(finalfile,'file') && condition == 1
            fprintf('already have %s\n', finalfile)
            continue
        end

        fprintf('making %s\n',finalfile);

        %% load EEG set
        EEG = pop_biosig([d currentName '.bdf']);
        if isempty(EEG.event)
            continue
        else
            EEG.setname=[currentName '_Rem']; %name the EEGLAB set (this is not the set file itself)

            eeglab redraw

            [micromed_time,mark]=make_photodiodevector(EEG); % micromed_time: the time the trigger goes off; mark: the trigger value

            %changes the triggers to be single digit numbers
            for i=unique(mark)
                mmark=find(mark==i);
                if ~isempty(mmark)
                    for j = 1:length(mmark)
                        %             EEG.event(mmark).type = cond{i+1};
                        EEG = pop_editeventvals(EEG,'changefield',{mmark(j) 'type' i});
                    end
                end
            end

            EEG = pop_saveset(EEG, 'filename',[currentName preprocVer '_Rem.set'],'filepath',outputpath);
        end
    end

elseif task == "switch"
    %% Switch task

    [micromed_time,mark]=make_photodiodevector(EEG); % micromed_time: the time the trigger goes off; mark: the trigger value

    mark = mark - min(mark(mark>0)) + 2;

    for i=unique(mark)
        mmark=find(mark==i);
        if ~isempty(mmark)
            for j = 1:length(mmark)
                %             EEG.event(mmark).type = cond{i+1};
                EEG = pop_editeventvals(EEG,'changefield',{mmark(j) 'type' i});
            end
        end
    end

elseif lower(task) == "vgs"
    %% Visually guided saccade
    vgsIDX = find (cellfun (@any,regexpi ( {namesOri.name}.', 'vgs')));
    for idx = vgsIDX'
        
        currentName = regexprep(namesOri(idx).name,'\.bdf$','');
        d = [namesOri(idx).folder '/'];

        %% skip if we've already done
        finalfile=fullfile(outputpath, [currentName preprocVer '_Rem.set']);
        if exist(finalfile,'file') && condition == 1
            fprintf('already have %s\n', finalfile)
            continue
        end
        if dryrun
            fprintf('want to run %s; set dryrun=0 to actually run\n', finalfile)
            continue
        end
        
        fprintf('making %s\n',finalfile);
        %% load EEG set
        EEG = pop_biosig([d currentName '.bdf']);
        EEG.setname=[currentName 'Rem']; %name the EEGLAB setclc (this is not the set file itself)
    
        % eeglab redraw
        % 11668_202206003 already has correct triggers but as strings
        if class(EEG.event(1).type) == "char"
            for i = 1:max(size(EEG.event))
                eventType = EEG.event(i).type;
                if eventType == "254"
                    EEG.event(i).type = 1; % new ITI
                elseif eventType == "condition 5" || eventType == "condition 4" || eventType == "condition 3" || eventType == "condition 2" || eventType == "condition 1"
                    EEG.event(i).type = 2; % new VGS cue, fixation cross
                elseif eventType == "condition 51" || eventType == "condition 52" || eventType == "condition 53" || eventType == "condition 54" || eventType == "condition 55"
                    EEG.event(i).type = 3; % new dot on, look at dot
                end
            end
        else
    
            [micromed_time, mark]=make_photodiodevector(EEG);
            % add one to mark if marks are one less than they should be 
            if any(mark==253)
                mark = mark +1;                
            end
            
            simple = nan(size(mark));
            simple(mark == 254)= 1; % (New ITI)
            simple(mark <=5 & mark >=1) = 2; % new vgs cue- red fixation cross, prepatory
            simple(mark <= 55 & mark >= 51) = 3; % new dot on, look at dot
            
            for i=unique(simple)
                mmark=find(simple==i);
                if ~isempty(mmark)
                    for j = 1:length(mmark)
                        EEG = pop_editeventvals(EEG,'changefield',{mmark(j) 'type' i});
                    end
                end
            end
        end

        EEG = pop_saveset( EEG, 'filename',[currentName preprocVer '_Rem.set'],'filepath',outputpath);
    end
elseif lower(task) == "dr"
    %% Reward antisaccade
    drIDX = find (cellfun (@any,regexpi ( {namesOri.name}.', 'dr')) | ...
        cellfun(@any, regexpi({namesOri.name}.','dollarreward')));

    for idx = drIDX'

        currentName = regexprep(namesOri(idx).name,'\.bdf$','');
        d = [namesOri(idx).folder '/'];

        %% skip if we've already done
        finalfile=fullfile(outputpath, [currentName preprocVer '_Rem.set']);
        if exist(finalfile,'file') && condition == 1
            fprintf('already have %s\n', finalfile)
            continue
        end
        if dryrun
            fprintf('want to run %s; set dryrun=0 to actually run\n', finalfile)
            continue
        end
        fprintf('making %s\n',finalfile);

        %% load EEG set
        EEG = pop_biosig([d currentName '.bdf']);
        EEG.setname=[currentName 'Rem']; %name the EEGLAB set (this is not the set file itself)

%         eeglab redraw

        [micromed_time,mark]=make_photodiodevector(EEG);   
       
        % sometimes the marks are 50 off from expected (need to add 50)
        % ^ occurs when all marks are less that 200
        if max(mark) < 200
            mark = mark + 50;
        end
        
        ending = mod(mark',10);

        % from github:
        % rew_look = {'neu': 100, 'rew': 200}
        % evt_look = {'iti': 10, 'ring': 20, 'prep': 20,
        %             'cue': 30,  'dot': 40}
        
        % does the trigger for neutral ring cue exist (between 120 and 126)
        if ~any(mark >= 120 & mark <=126) % does not exist
            % find indicies of prep cues for reward and neutral
            rewprepIDX = find(mark >= 230 & mark <= 236)';
            neuprepIDX = find(mark >= 130 & mark <= 136)';
            
            % indicies of ring cues are 1 before the prep cue
            neuringIDX = neuprepIDX -1;
            rewringIDX = rewprepIDX -1;
            
            % does reward ring cue exist
            if ~any(mark >= 230 & mark <= 226) % does not exist
                mark(neuringIDX) = 120 + ending(neuprepIDX);
                mark(rewringIDX) = 220 + ending(rewprepIDX);
            elseif any(mark>=220 & mark<=226) % exists
                mark(neuringIDX) = 120 + ending(neuprepIDX);                
            end
        end

        % overall order iti -> ring cue (#s or $s) -> prep cue (red cross) -> dot
        
        % 50 = ITI : 3
        % In the 100s = neutral trial : 1#
        %   120 = neutral ring cue : 11
        %   130 = neutral prep cue : 12
        %   140 = neutral dot : 13
        % In the 200s = reward trial : 2#
        %   220 = reward ring cue : 21
        %   230 = reward prep cue : 22
        %   240 = reward dot : 23
        % Ones column indicates position of dot (only matters for dot cue 140s or 240s)
        % ^ ignoring for now during remarking (only matters for scoring)
        %   141/241 = -0.97 degrees (far left) 
        %   142/242 = -0.66 degrees (mid left) 
        %   143/243 = -0.33 degrees (close left) 
        %   144/244 = 0.33 degrees (close right)
        %   145/245 = 0.66 degrees (mid right) 
        %   146/246 = 0.97 degrees (far right) 

        % trigger as 2 digit numbers
        simple = nan(size(mark));
        dot_position = nan(size(mark));
        simple(mark==50) = 3;
        simple(mark>=120 & mark<=126) = 11;
        simple(mark>=130 & mark<=136) = 12;
        simple(mark>=140 & mark<=146) = 13;
        
        simple(mark>=220 & mark<=226) = 21;
        simple(mark>=230 & mark<=236) = 22;
        simple(mark>=240 & mark<=246) = 23;
                
        % add ending of the dot trigger to save position of the dot
        new_ending = mod(mark,10)';
        dot_position(mark >= 140 & mark <= 146) = new_ending(mark >= 140 & mark <= 146);
        dot_position(mark >= 240 & mark <= 246) = new_ending(mark >= 240 & mark <= 246);
        
        for i=unique(simple)
            mmark=find(simple==i);
            if ~isempty(mmark)
                for j = 1:length(mmark)
                    EEG = pop_editeventvals(EEG,'changefield',{mmark(j) 'type' i});
                end
            end
        end
        
        % add dot position to EEG.event
        dot_position_cell = num2cell(dot_position);
        [EEG.event.dotposition] = dot_position_cell{:};

        EEG = pop_saveset( EEG, 'filename',[currentName preprocVer '_Rem.set'],'filepath',outputpath);

    end    
elseif lower(task) == "habit" 
    habitIDX = find (cellfun (@any,regexpi ( {namesOri.name}.', 'habit')));
    % load habit eeg behav trial level data
    habit_df =  readtable('/Volumes/Hera/Projects/Habit/task/results/lab.data.tsv', 'FileType','text', 'Delimiter','\t');
        for idx = habitIDX'

            currentName = regexprep(namesOri(idx).name,'\.bdf$','');
            splitname = split(currentName,'_');
            lunaid = str2double(splitname{1});
            eeg_date = str2double(splitname{2});
            d = [namesOri(idx).folder '/'];

            %% skip if we've already done
            finalfile=fullfile(outputpath, [currentName preprocVer '_Rem.set']);
            if exist(finalfile,'file') && condition == 1
                fprintf('already have %s\n', finalfile)
                continue
            end
            if dryrun
                fprintf('want to run %s; set dryrun=0 to actually run\n', finalfile)
                continue
            end
            fprintf('making %s\n',finalfile);

            % loading EEG data
            %% load EEG set
            EEG = pop_biosig([d currentName '.bdf']);
            EEG.setname=[currentName 'Rem']; %name the EEGLAB set (this is not the set file itself)           
            
            if isempty(EEG.event)
                continue
            end
            
            % if events are characters convert to numeric
            types = {EEG.event(:).type};
            ischartype = cellfun(@ischar, types);
            numerictypes = types;
            numerictypes(ischartype) = cellfun(@str2double, types(ischartype), 'UniformOutput',false);
            [EEG.event(:).type] = numerictypes{:};
            EEG = eeg_checkset(EEG, 'eventconsistency');
        
            mark = [EEG.event(:).type];
            markmin = min(mark);
            if markmin == 16129
                mark = mark - min(mark) + 1;
            elseif markmin == 16128
                mark = mark - min(mark);
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
%             seq = [14 1 24 1 2];
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
            
                       
            % triggers:
            % overall: left = 1; up = 2; right = 3; photodiode = 1
            %   right + up = 5
            %       potential waiting triggers:
            %           166 (chose up) or 168 (chose right)
            %       potential feedback triggers:
            %           216 (chose up and not rewarded)
            %           226 (chose up and rewarded)
            %           218 (chose right and not rewarded)
            %           228 (chose right and rewarded)            
            %   left + right = 4
            %       potential waiting triggers:
            %           165 (chose left) or 167 (chose right)
            %       potential feedback triggers:
            %           215 (chose left and not rewarded)
            %           225 (chose left and rewarded)
            %           217 (chose right and not rewarded)
            %           227 (chose right and rewarded)         
            %   left + up = 3  
            %       potential waiting triggers:
            %           163 (chose left) or 164 (chose up)
            %       potential feedback triggers:
            %           213 (chose left and not rewarded)
            %           223 (chose left and rewarded)
            %           214 (chose up and not rewarded)
            %           224 (chose up and rewarded)  
            %   
            %   button pushes:
            %       2 = left
            %       3 = up
            %       4 = right
            
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
            
            EEG = pop_editeventfield(EEG, 'type', simple);
            EEG = eeg_checkset(EEG,'eventconsistency');
            
            % load subject trial level data frame
            subtable = habit_df(habit_df.id == lunaid & habit_df.timepoint == eeg_date,:);
            if isempty(subtable)
                warning('%d %d does not have trial level data table',lunaid, eeg_date)
                continue
            end
            ntrls_trialdata = height(subtable);
            event_trials = [EEG.event(:).type]';
            end_trial_idx = find(event_trials == 200 | event_trials == 100 | event_trials == 70);
            ntrls_eeg = length(end_trial_idx);
            
            % check: ntrls_trialdata = ntrls_eeg
            if ntrls_eeg ~= ntrls_trialdata
               warning('%d eeg trials != %d trials from trial data table',ntrls_eeg, ntrls_trialdata)
               continue
            end
            
            curr_start_idx = 1;
            trial = 1;
            for curr_end_idx = end_trial_idx'               
                [EEG.event(curr_start_idx:curr_end_idx).trial] = deal(trial);
                curr_start_idx = curr_end_idx +1;
                trial = trial +1;                
            end
            
            EEG = pop_saveset( EEG, 'filename',[currentName preprocVer '_Rem.set'],'filepath',char(outputpath));
        
        end

end
end