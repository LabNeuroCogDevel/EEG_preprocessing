function [paths] = create_output_paths(maindir_old,task)
%% Creates folders to save all preprocessing files
%                            Saves paths as struct to reference later

maindir = fullfile(maindir_old, task);
mkdir(maindir);

% names for subfolders
subfolders = {'qualityCheck', 'finalSpectra', 'runICA', 'remarked', 'filtered', 'removeLineNoise', 'channels_rejected', 'interpolated', 'rerefwhole', 'ICAwhole', 'AfterWhole'};

% additional folders based on task type
% if task == "resting_state"
%     subfolders = [subfolders, {'trimmed'}];
% else
%     subfolders = [subfolders, {'renamedtrials'}];
% end
    
% add all folders to directory
for i = 1:numel(subfolders)
    folderPath = fullfile(maindir, subfolders{i});
    paths.(subfolders{i}) = folderPath;
    if isfolder(folderPath)
        fprintf("%s folder already exists; skipping\n", folderPath)
        continue
    else
        mkdir(folderPath);
    end
end

% create subfolders for AfterWhole
AfterWholeDir = fullfile(maindir, 'AfterWhole');
AfterWhole_folders = {'epoch', 'ICAwholeclean', 'ICAwholeclean_homogenize', 'kept_epoch', 'marked_epoch', 'MarkedICAwhole'};

% add all folders to directory
for i = 1:numel(AfterWhole_folders)
    folderPath = fullfile(AfterWholeDir, AfterWhole_folders{i});
    paths.(AfterWhole_folders{i}) = folderPath;
    if isfolder(folderPath)
        fprintf("%s folder already exists; skipping\n", folderPath)
        continue
    else
        mkdir(folderPath);
    end
end

paths.main = maindir;

end

