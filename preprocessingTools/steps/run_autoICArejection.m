EEG = pop_loadset(WholeICAFile);
EEG = pop_iclabel(EEG, 'default');
% first number is lower threshold for rejection, second number of upper
% threshold for rejection, never rejects based on brain or other
EEG = pop_icflag(EEG, [0 0; ... % brain
    0.5 1; ...  % muscle
    0.5 1; ...  % eye
    0.5 1; ...  % heart
    0.8 1; ...  % line noise
    0.5 1; ...  % channel noise
    0 0]);      % other

% save flagged components in one file
EEG = pop_saveset(EEG, 'filename', icawholemarked_name, 'filepath', outpath.MarkedICAwhole);

% remove marked components
EEG = pop_subcomp(EEG, [], 0);

% now remove those components
EEG = pop_saveset(EEG, 'filename', icawholeclean_name, 'filepath', outpath.ICAwholeclean);