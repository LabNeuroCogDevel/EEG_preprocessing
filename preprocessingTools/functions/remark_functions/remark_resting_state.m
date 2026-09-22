%% Remark resting state EEGs
function [EEG] = remark_resting_state(output_folder,dryrun,task,rawdir,preprocVer,condition)

% define file paths
path_file = rawdir;
outputpath = output_folder;

d = path_file;

% preprocVer = ['_preprocVer' preprocVer];

% all raw EEG files from study
namesOri = dir(fullfile(d, '*', '*.bdf'));

% find all resting state EEGs
IDX = find (cellfun (@any,regexpi ( {namesOri.name}.', 'rest')));

% loop over all resting EEGs
for idx = IDX'
    % define current EEG
    currentName = regexprep(namesOri(idx).name,'\.bdf$','');
    d = [namesOri(idx).folder '/'];
    
    % skip if already created
    finalfile = fullfile(outputpath, [currentName '_' preprocVer '_Rem.set']);
    if exist(finalfile,'file') && condition == 1
        fprintf('already have %s\n', finalfile)
        continue
    end
    if dryrun
        fprintf('want to run %s; set dryrun=0 to actually run\n', finalfile)
        continue
    end
    fprintf('making %s\n',finalfile);
    
    % load EEG set
    EEG = pop_biosig([d currentName '.bdf']);
    EEG.setname=[currentName 'Rem'];
    
    % use photodiode to get correct mark numbers
    [micromed_time,mark]=make_photodiodevector(EEG);
    
    % check event consistency             
    EEG = pop_editeventfield(EEG, 'type', mark);
    EEG = eeg_checkset(EEG,'eventconsistency');
    
    % check that remarking worked
    unique_marks = unique(mark);
    
    if any(unique_marks == 1) && any(unique_marks == 0)
        % save EEG
        savename = [currentName '_' preprocVer '_Rem.set'];
        EEG = pop_saveset( EEG, 'filename',savename,'filepath',outputpath);
    else
        fprintf("New marks do not contain 1s and 0s\n")
    end  
    
end

end