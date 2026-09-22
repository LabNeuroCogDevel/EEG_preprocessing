if Flag128 == 1 % no clue what is going on here using from original pipeline
    nchan = 64;
    ngood = length(EEG.chanlocs);
    %  128 cap doesn't have exactly the same postions as 64
    % remove 4 that are in the wrong place and reinterpret
    % AND interp any bad channels
    % do this by removing the 4 128weirdos
    % from the already trimmed (no bad channels) in EEG.chanlocs
    
    need_128interp = [2  3  35  36 ];
    % get the names of those to remove
    n128name = {originalEEG.chanlocs(need_128interp).labels};
    % should always be {'AF5','AF1','AF2','AF6'} ??
    
    % find where they are in current EEG files (if they haven't already been removed)
    n128here_idx = find(ismember({EEG.chanlocs.labels},n128name));
    % keep those that aren't the ones we matched
    % remove from chanlocs, data and update nbcan
    % WARNING -- who knows what else we should have changed to update the set info!
    keep_idx = setdiff(1:ngood, n128here_idx);
    EEG.chanlocs = EEG.chanlocs(keep_idx);
    EEG.data = EEG.data(keep_idx,:);
    EEG.nbchan = length(keep_idx);
    
    %EEG_i = pop_interp(EEG, interp_ch, 'spherical');
    fprintf('%d channels in orig; want to interpolate %d bad and move %d\n',...
        originalEEG.nbchan, nchan - ngood, length(need_128interp))
    EEG_i = pop_interp(EEG, originalEEG.chanlocs, 'spherical');
    
    % could swap these channels (they're close, but not the same)
    % BUT WE DONT
    % 128    'AF7' --> 64    'AF5' In this point channel 2
    % 128    'AF3' --> 64    'AF1' In this point channel 3
    % 128    'AF4' --> 64    'AF2' In this point channel 35
    % 128    'AF8' --> 64    'AF6' In this point channel 36
    % lines above modify channel information and pocition in data to make
    %  it the same for 64 and 128 cap
    
    % need to do destructive swapping. need a copy
    EEG = EEG_i;
    EEG.chanlocs(2) = EEG_i.chanlocs(3);%EEG.chanlocs(2) must by 'AF1' in 64 cap
    EEG.chanlocs(3) = EEG_i.chanlocs(2);%EEG.chanlocs(3) must by 'AF5' in 64 cap
    %     EEG.chaninfo.filecontent(4,:) = EEG_i.chaninfo.filecontent(3,:); This
    %     is not necessary i think, but just in case...
    %     EEG.chaninfo.filecontent(4,1) = '3';
    %     EEG.chaninfo.filecontent(3,:) = EEG_i.chaninfo.filecontent(4,:);
    %     EEG.chaninfo.filecontent(3,1) = '2';
    EEG.data(2,:) = EEG_i.data(3,:);% ALERT ALERT Lines latelly added
    EEG.data(3,:) = EEG_i.data(2,:);% ATERT ALERT Lines latelly added
else
    EEG = pop_interp(EEG, originalEEG.chanlocs, 'spherical');
    EEG = pop_saveset( EEG,'filename', interp_name, ...
        'filepath', outpath.interpolated);
end