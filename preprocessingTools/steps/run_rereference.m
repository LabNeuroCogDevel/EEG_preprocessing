% not sure what FLAG is
if FLAG
    EEG = pop_reref(EEG, []);
end

%save whole rereferenced data for ICA whole
%save epochs rejected EEG data
EEG = pop_editset(EEG, 'setname', rerefwhole_name);

EEG = pop_saveset(EEG, 'filename', rerefwhole_name, 'filepath', outpath.rerefwhole);