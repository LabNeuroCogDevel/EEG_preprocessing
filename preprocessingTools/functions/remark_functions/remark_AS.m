%% Anti-saccade remark function
function [EEG] = remark_AS(output_folder,dryrun,task,rawdir,preprocVer,condition)
% to run eeg_data.m 
addpath('/Volumes/Hera/Projects/7TBrainMech/scripts/eeg/eog_cal') % need to run eeg_data.m

% define file paths
path_file = rawdir;
outputpath = output_folder;

d = path_file;

% all raw EEG files from study
namesOri = dir(fullfile(d, '*', '*.bdf'));

% find all habit task EEGs
IDX = find (cellfun (@any,regexpi ( {namesOri.name}.', 'anti')));

for idx = IDX'
    % define current EEG
    currentName = regexprep(namesOri(idx).name,'\.bdf$','');
    splitname = split(currentName,'_');
    lunaid = str2double(splitname{1});
    eeg_date = str2double(splitname{2});
    d = [namesOri(idx).folder '/'];
    % skip if already been remarked
    finalfile=fullfile(outputpath, [currentName '_' preprocVer '_Rem.set']);
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
    
    
    
end

end