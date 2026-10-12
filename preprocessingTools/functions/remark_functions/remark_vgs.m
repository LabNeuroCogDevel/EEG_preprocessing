function [] = remark_vgs(EEG,currentName,preprocVer, outputFolder)

% a few VGS EEGs have events as strings "condition ##" or "254"
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
    % make vector of marks
    [micromed_time, mark]=make_photodiodevector(EEG);
    % add one to mark if marks are one less than they should be 
    if any(mark==253)
        mark = mark +1;                
    end

    % make simple marks
    simple = nan(size(mark));
    simple(mark == 254)= 1; % (New ITI)
    simple(mark <=5 & mark >=1) = 2; % new vgs cue- red fixation cross, prepatory
    simple(mark <= 55 & mark >= 51) = 3; % new dot on, look at dot

    % change events to simple marks
    EEG = pop_editeventfield(EEG,'type',simple);
    % check consistency
    EEG = eeg_checkset(EEG,'eventconsistency');
end
% save EEG
savename = [currentName '_' preprocVer '_Rem.set'];
EEG = pop_saveset( EEG, 'filename',savename,'filepath',outputFolder);

end