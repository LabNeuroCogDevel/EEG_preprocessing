% not sure what FLAG is
% if FLAG
%     EEG = pop_reref(EEG, []);
% end
% reref to average
EEG = pop_reref(EEG, []); % reference: [] = convert to average reference
%save whole rereferenced data for ICA whole
EEG = pop_editset(EEG, 'setname', rerefwhole_name);

EEG = pop_saveset(EEG, 'filename', rerefwhole_name, 'filepath', outpath.rerefwhole);