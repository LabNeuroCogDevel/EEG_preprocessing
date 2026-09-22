function loc = file_locs(filepath, savedir, task)
% From any file in the eeg pipeline, get all paths used
if task == "MGS"
    id_task_regexp='(?<id>\d{5}_\d{8})_(?<task>MGS)_(?<extra>.*)';

elseif task == "SNR"
    id_task_regexp='(?<id>\d{5}_\d{8})_(?<task>ss)_(?<extra>.*)';

elseif task == "resting_state"
    id_task_regexp='(?<id>\d{5}_\d{8})_(?<task>REST)_(?<extra>.*)';

elseif task == "anti"
    id_task_regexp='(?<id>\d{5}_\d{8})_(?<task>anti)_(?<extra>.*)';
    
elseif task == "vgs"
    id_task_regexp = '(?<id>\d{5}_\d{8})_(?<task>vgs)_(?<extra>.*)';

end

[filedir, filename, filext ] = fileparts(filepath);


% todo maybe this isn't a problem.
if ~exist(filepath, 'file'), error('file "%s" does not exist', filepath), end
if ~strmatch(filext, 'set'), error('file "%s" is not a .set file', filepath), end

% identify name
parts = regexp(filename, id_task_regexp, 'ignorecase','names');
if isempty(parts),error('%s failed to match id_task pattern (%s)', filename, id_task_regexp), end

subj_task = [parts(1).id '_' parts(1).task];

%% define file locations
mkname=@(f, ext) fullfile(savedir, f, [subj_task ext '.set']);
if task == "anti" % have extra step which is renaming trials 
    loc.remarked        = mkname('remarked',          '_Rem');
    loc.filter          = mkname('filtered',          '_filtered');
    loc.filterbp        = mkname('bandpass_filtered', '_bandpass_filtered') ;
    loc.chanrj          = mkname('channels_rejected', '_badchannelrj');
    loc.rerefwhole_name = mkname('rerefwhole',        '_rerefwhole');
    loc.epoch           = mkname('epoched',           '_epochs');
    loc.epoch_rj_marked = mkname('marked_epochs',     '_epochs_marked');
    loc.epochrj         = mkname('rejected_epochs',   '_epochs_rj');
    loc.icaout          = mkname('ICA',               '_epochs_rj_ICA');
    loc.icawhole        = mkname('ICAwhole',          '__ICA');
    loc.SASICA          = mkname('ICA',               '_ICA_SAS');
else
    loc.remarked        = mkname('remarked',          '_Rem');
    loc.filter          = mkname('filtered',          '_filtered');
    loc.filterbp        = mkname('bandpass_filtered', '_bandpass_filtered') ;
    loc.chanrj          = mkname('channels_rejected', '_badchannelrj');
    loc.rerefwhole_name = mkname('rerefwhole',        '_rerefwhole');
    loc.epoch           = mkname('epoched',           '_epochs');
    loc.epoch_rj_marked = mkname('marked_epochs',     '_epochs_marked');
    loc.epochrj         = mkname('rejected_epochs',   '_epochs_rj');
    loc.icaout          = mkname('ICA',               '_epochs_rj_ICA');
    loc.icawhole        = mkname('ICAwhole',          '_ICA');
    loc.SASICA          = mkname('ICA',               '_ICA_SAS');
%TODO: add rerefwhole_name
end
%% stats and logic on files in/completed
loc.allfiles = fieldnames(loc);
files_exist = cellfun(@(x) exist(loc.(x),'file'), loc.allfiles);
loc.missing = loc.allfiles(~files_exist);
loc.ncomplete = sum(files_exist);
loc.is_finished = exist(loc.icaout, 'file') ~= 0;

% not single subject 
loc.epochClean      = mkname('AfterWhole/epoch', '_epochs');
loc.ICAwholeClean   = mkname('AfterWhole/ICAwholeclean', '_CleanICA');
loc.ICACleanHomogenize  = mkname('AfterWhole/ICAwholeClean_homogenize', '_CleanICA_Homogenize');


end
