function [setfiles] = all_remarked_set(setfilesDir,varargin)
% ALL_REMARKED_SET - return cell array of paths to initial set files
% handle options
% p = inputParser;
% p.addOptional('only128',0, @(x) validateattributes(x,{'logical'},{'scalar'}))
% p.addOptional('only64', 0, @(x) validateattributes(x,{'logical'},{'scalar'}))
% p.addOptional('struct', 0, @(x) validateattributes(x,{'logical'},{'scalar'}))
% p.parse(varargin{:})

filesDir = dir(setfilesDir);
for i = 1:length(filesDir)
    folder = filesDir(i).folder;
    name = filesDir(i).name;
    setfiles{i} = [folder,'/',name];
end
end