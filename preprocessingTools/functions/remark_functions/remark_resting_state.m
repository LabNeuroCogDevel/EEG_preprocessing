%% Remark resting state EEGs
function [] = remark_resting_state(EEG,currentName, preprocVer, outputFolder)

% use photodiode to get correct mark numbers
[micromed_time, mark]=make_photodiodevector(EEG);

% check event consistency             
EEG = pop_editeventfield(EEG, 'type', mark);
EEG = eeg_checkset(EEG,'eventconsistency');

% check that remarking worked
unique_marks = unique(mark);

if any(unique_marks == 1) && any(unique_marks == 0)
    % save EEG
    savename = [currentName '_' preprocVer '_Rem.set'];
    EEG = pop_saveset( EEG, 'filename',savename,'filepath',outputFolder);
else
    error("New marks do not contain 1s and 0s")
end

end