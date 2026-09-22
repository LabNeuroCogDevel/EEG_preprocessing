function [] = preprocessing_pipelineSK(inputfile, outpath, lowBP, highBP, FLAG, condition, task, varargin)
% sanvi korsapathy 05.29.2026
% find file we are using
if ~exist(inputfile,"file")
    error('inputfile "%s" does not exist!', inputfile)
end

%% initialize
[~, currentName, ~ ] = fileparts(inputfile);
parts = split(currentName,'_');
subid = str2double(parts{1});
scandate = str2double(parts{2});
task_type = str2double(parts{3});
preprocVer = str2double(parts{4});

if task ~= "resting_state"
    currentName = strjoin(parts(1:end-1), '_');
end

%% cap locations
eeglabpath = fileparts(which('eeglab'));
cap_location = fullfile(eeglabpath,'/plugins/dipfit/standard_BESA/standard-10-5-cap385.elp');
if ~exist(cap_location, 'file'), error('cannot find file for 128 channel cap: %s', cap_location), end
correction_cap_location = hera('Projects/7TBrainMech/scripts/eeg/Shane/resources/ChanLocMod128to64.ced');
if ~exist(correction_cap_location, 'file'), error('cannot find file for correction 128 channel cap: %s', correction_cap_location), end

%% Files
subj_files = file_locs(inputfile, outpath.main, task);

% to know how far your script is with running
fprintf('==========\n%s:\n\t Initial Preprocessing(%s,%f,%f,%s,%s)\n',...
    currentName, inputfile, lowBP, highBP, outpath.main, task)

% filenames
filter_name = [currentName '_filtered'];
chrm_name   = [currentName '_badchannelrj'];
datarm_name = [currentName '_baddatarj'];
interp_name = [currentName '_interp'];
linenoise_name = [currentName '_removeLineNoise'];
rerefwhole_name = [currentName '_rerefwhole'];
icawholeout_name = [currentName '_ICA'];
icawholemarked_name = [currentName '_MarkedAutoICA'];
icawholeclean_name = [currentName '_CleanICA'];
homogenize_name = [currentName '_CleanICA_Homogenize'];

% file names to check for existing files
icawholeoutFile = fullfile(outpath.ICAwholeclean_homogenize, [homogenize_name '.set']);
filteredFile = fullfile(outpath.filtered, [filter_name '.set']);
lineNoisefile = fullfile(outpath.removeLineNoise, [linenoise_name '.set']);
chanrjfile = fullfile(outpath.channels_rejected, [chanrm_name '.set']);
interpfile = fullfile(outpath.interpolated, [interp_name '.set']);
rerefFile = fullfile(outpath.rerefwhole, [rerefwhole_name '.set']);
WholeICAFile = fullfile(outpath.icawholeout, [icawholeout_name '.set']);
CleanICAFile = fullfile(outpath.ICAwholeclean, [icawholeclean_name '.set']);
HomogenizedFile = fullfile(outpath.ICAwholeclean_homogenize, [homogenize_name '.set']);

%% channel names
commonPlus = {'AFz','C1','C2','C3','C4','C5','C6','CP1','CP2','CP3','CP4',...
    'CP5','CP6','CPz','Cz','F1','F2','F3','F4','F5','F6','F7','F8','FC1',...
    'FC2','FC3','FC4','FC5','FC6','FCz','Fp1','Fp2','FT10','FT9','Fz','I1',...
    'I2','O1','O2','Oz','P1','P10','P2','P3','P4','P5','P6','P7','P8','P9',...
    'PO10','PO3','PO4','PO7','PO8','PO9','POz','Pz','T7','T8',...
    'AF8','AF7','AF4','AF3'};

%% checking whether or not to rerun
% checking if whole ICA run already exists (subject already preprocessed)
if condition == 1
    if exist(icawholeoutFile, 'file')
        warning('%s already complete (have "%s")! todo load from file', currentName, icawholeout_name)
        return
    end
end

%% loading filtered EEG if created
% making filtered EEG current EEG if already did filtering
if condition == 1
    if exist(filteredFile, 'file')
        warning('%s already filtered! Skipping filtering step.', currentName)
        EEG = pop_loadset(filteredFile);
        
        % making sure Flag128 is set if skipping filtering
        if size(EEG.data) < 100
            % [65 66] are mastoid externals
            Flag128 = 0;
        else
            Flag128 =1;
        end
        
    else % if filtered EEG does not exist running rereferencing, filtering, and resampling
        condition = 0; % since new file is created, rerun preproc on new file
        %% load EEG set and re-reference to mastoids
        EEG = pop_loadset(inputfile);
        
        if size(EEG.data,1) < 100
            % [65 66] are mastoid externals
            Flag128 = 0;
            EEG = pop_reref(EEG, [65 66]);
            EEG = eeg_checkset(EEG);
        else
            Flag128 = 1;
            %[129 130] are the mastoid externals for the 128 electrode
            EEG = pop_reref(EEG, [129 130]);
            EEG = eeg_checkset(EEG);
        end
        
        %stores EEG set in ALLEEG, give setname
        ALLEEG = [];
        [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 0,...
            'setname',currentName,...
            'gui','on');
        [ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, EEG);
        
        EEG.subject = currentName(1:findstr(currentName,'anti')-2);
        EEG.condition = currentName(findstr(currentName,'anti'):end);
        
        %% Filtering
        
        EEG = pop_eegfiltnew(EEG, lowBP, highBP, 3380, 0, [], 0);
        % inputs: (EEG, locutoff, hicutoff, filtorder, revfilt, usefft, plotfreqz, minphase);
        % revfilt- reverse filter 0=bandpass, 1=notch
        % usefft- [] ignore (use fft to filter)
        % plotfreqz- plot frequency bode plots for filter 0=don't plot, 1=plot
        % filtorder = 3380 - filter order (filter length - 1). Mandatory even. performing 3381 point bandpass filtering.
        
        % give a new setname and overwrite unfiltered data
        EEG = pop_editset(EEG,'setname',[currentName '_bandpass_filtered']);
        [ALLEEG, EEG CURRENTSET] = eeg_store(ALLEEG, EEG);
        
        %% Resample Data
        % Downsample the data to 512 Hz using anti-aliasing filter
        EEG = pop_resample(EEG, 512, 0.8, 0.4);
        %0.8 is fc and 0.4 is df. Default is .9 and .2. We dont know why Alethia changed them
        % df = anti-aliasing filter transition band width
        % fc = anti-aliasing filter cutoff
        EEG = eeg_checkset(EEG);
        
        %change setname
        EEG = pop_editset(EEG,'setname',filter_name);
        [ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);
        
        %save filtered data
        EEG = pop_saveset(EEG, 'filename',filter_name, ...
            'filepath',outpath.filtered);
        [ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, EEG);
    end
end

%% Notch filter at 60Hz for line noise
if condition == 1
    if exist(lineNoisefile, 'file')
        warning('%s already removed line noise! Skipping notch step.', currentName)
        EEG = pop_loadset(lineNoisefile);
    else
        condition = 0; % since new file is created, rerun preproc on new file
        EEG = pop_eegfiltnew(EEG, 59, 61, [], 1, [], 0);
        EEG = pop_saveset(EEG, 'filename', linenoise_name, 'filepath', outpath.removeLineNoise);
    end
end

% %% Zap line to remove electrical noise
% if condition == 1
%     if exist(lineNoisefile, 'file')
%         warning('%s already removed line noise! Skipping ZapLine step.', currentName)
%         EEG = pop_loadset(lineNoisefile);
%     else
%         condition = 0; % since new file is created, rerun preproc on new file
%         
%         EEG = clean_data_with_zapline_plus_eeglab_wrapper(EEG, struct('noisefreqs', [60]));
%         zapReportPath = fullfile(outpath.removeLineNoise, linenoise_name);
%         saveas(gcf, zapReportPath, 'png'); % save ZapLine report to same folder as data
%         
%         % save data without line noise
%         EEG = pop_saveset(EEG, 'filename', linenoise_name, 'filepath', outpath.removeLineNoise);
%     end
% end

%% Channels
if condition == 1
    if exist(chanrjfile, 'file')
        warning('%s already removed bad channels! Skipping channel rejection step.', currentName)
        EEG = pop_loadset(chanrjfile);
    else
        condition = 0; % since new file is created, rerun preproc on new file
        % remove external channels
        EEG = pop_select( EEG,'nochannel',{'EX3' 'EX4' 'EX5' 'EX6' 'EX7' 'EX8' 'EXG1' 'EXG2' 'EXG3' 'EXG4' 'EXG5' 'EXG6' 'EXG7' 'EXG8' 'GSR1' 'GSR2' 'Erg1' 'Erg2' 'Resp' 'Plet' 'Temp' 'FT7' 'FT8' 'TP7' 'TP8' 'TP9' 'TP10'});
        [ALLEEG EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
        
        %import channel locations
        EEG=pop_chanedit(EEG, 'lookup', cap_location);
        
        % fixing if 128 channel setup
        if size(EEG.data,1) > 100
            EEG = pop_select( EEG,'channel',commonPlus);
            EEG = pop_chanedit(EEG, 'load', {correction_cap_location 'filetype' 'autodetect'});
            % 128    'AF8' --> 64    'AF6'
            % 128    'AF7' --> 64    'AF5'
            % 128    'AF4' --> 64    'AF2'
            % 128    'AF3' --> 64    'AF1'
        end
        [ALLEEG EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
        
        %% Bad Channel Rejection
        % bad channels are in general the channels that you can't save even if you reject 5-10% of your datapoints
        % from eeglab wiki: plot channel spectrum and ID outliers with spectopo()
        % 3 options for channel rejection:
        % 1. look at standard deviation in bar plots and remove the channels
        % 2. kurtosis
        % 3. clean_rawdata - this method removed events from EEG set and lost individual anti trials
        % maybe use clean_rawdata but need to tweak from original pipeline
        
        % loading rejected channels if already done
        % if condition == 1
        %     xEEG = load_if_exists(subj_files.chanrj);
        % end
        % originalEEG has channel locations and external channels removed- need for determining which channels have been rejected
        originalEEG = EEG;
        %
        % if isstruct(xEEG) % if channels have already been rejected, setting that set as current EEG
        %     [ALLEEG EEG] = eeg_store(ALLEEG, xEEG, CURRENTSET);
        % else
        EEG = clean_rawdata(EEG, 8, -1, 0.7, 5, 15, 0.3);
        % clean_rawdata inputs:
        % (EEG, arg_flatline, arg_highpass, arg_channel, arg_noisy, arg_burst,arg_window)
        % see clean_rawdata for description of what inputs mean
        % arg_highpass = -1 : already highpassed data do not need to do again
        % LOOK AT OTHER PARAMETERS
        
        %change setname
        EEG = pop_editset(EEG,'setname', chrm_name);
        [ALLEEG EEG] = eeg_store(ALLEEG, EEG);
        
        EEG = pop_saveset( EEG,'filename', chrm_name, ...
            'filepath', outpath.channels_rejected);
        % end
        %
        % if condition == 1 % loading average re-referenced EEG set if already created
        %     xEEG = load_if_exists(subj_files.rerefwhole_name);
        % end
        %
        % if isstruct(xEEG) % if already re-referenced don't do again
        %     [ALLEEG EEG] = eeg_store(ALLEEG, xEEG, CURRENTSET);
        % else
        [ALLEEG EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
        
        % what is clean_channel_mask???
        if ~any(find(cellfun (@any,regexpi (fieldnames(EEG.etc), 'clean_channel_mask'))))
            EEG.etc.clean_channel_mask=42;
        else
        end
        
        %save the channels that were rejected in a variable
        channels_removed{1} = chrm_name; %setname
        channels_removed{2} = setdiff({originalEEG.chanlocs.labels},{EEG.chanlocs.labels}, 'stable');
        channels_removed{3} = find(EEG.etc.clean_channel_mask==0);
        %also save the channels that were rejected in the EEG struct
        EEG.channels_rj = channels_removed{2};
        EEG.channels_rj_nr = length(EEG.channels_rj);
        
        %save the proportion of the dataset that were rejected in a variable
        data_removed{1} = datarm_name; %setname
        data_removed{2} = length(find(EEG.etc.clean_sample_mask==0))/EEG.srate;%
        data_removed{3} = length(find(EEG.etc.clean_sample_mask==0))/length(EEG.etc.clean_sample_mask);%
        %also save the data that were rejected in the EEG struct
        EEG.data_rj    = data_removed{2};
        EEG.data_rj_nr = data_removed{3};
    end
end

%% Interpolate Channels
% POSSIBLE PROBLEMS
%  - injecting extra channels ontop of expected 64 (n>64)
%  - 128 missing expected labels, adding too few back (n<64)
if condition == 1
    if exist(interpfile, 'file')
        warning('%s already interpolated! Skipping interpolation step.', currentName)
        EEG = pop_loadset(interpfile);
    else
        condition = 0; % since new file is created, rerun preproc on new file
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
    end
end
%% Re-reference: Average Reference
if condition == 1
    if exist(rerefFile, 'file')
        warning('%s already rereferenced! Skipping rereferencing step.', currentName)
        EEG = pop_loadset(rerefFile);
    else
        condition = 0; % since new file is created, rerun preproc on new file
        % not sure what FLAG is
        if FLAG
            EEG = pop_reref(EEG, []);
            [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 1,...
                'setname',[currentName '_avref'],...
                'gui','off');
        end
        
        %save whole rereferenced data for ICA whole
        %save epochs rejected EEG data
        EEG = pop_editset(EEG, 'setname', rerefwhole_name);
        [ALLEEG EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
        
        EEG = pop_saveset(EEG, 'filename', rerefwhole_name, 'filepath', outpath.rerefwhole);
        [ALLEEG EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
    end
end

%% Whole ICA run
if condition == 1
    if exist(WholeICAFile, 'file')
        warning('%s already ran ICA! Skipping ICA step.', currentName)
        EEG = pop_loadset(WholeICAFile);
    else
        condition = 0; % since new file is created, rerun preproc on new file
        icawholein = fullfile(outpath.rerefwhole, [rerefwhole_name '.set']);
        wholeout = outpath.ICAwhole;
        runICAs(icawholein,outpath.ICAwhole,task)
    end
end

%% select ICA components to reject
if condition == 1
    if exist(CleanICAFile, 'file')
        warning('%s already automatically rejected ICs! Skipping IC rejection step.', currentName)
        EEG = pop_loadset(CleanICAFile);
    else
        condition = 0; % since new file is created, rerun preproc on new file
        EEGfileNames = dir([outpath.ICAwhole '/*.set']);
        for fidx = 1:length(EEGfileNames)
            filename = EEGfileNames(fidx).name;
            autoICArejection
        end
    end
end

%% Homogenize Chanloc
if condition == 1
    if exist(HomogenizedFile, 'file')
        warning('%s already automatically homogenized! Skipping homogenize step.', currentName)
        EEG = pop_loadset(HomogenizedFile);
    else
        condition = 0; % since new file is created, rerun preproc on new file
        datapath = outpath.ICAwholeclean;
        savepath = outpath.ICAwholeclean_homogenize;
        
        setfiles0 = dir([datapath,'/*CleanICA.set']);
        setfiles = {};
        
        for epo = 1:length(setfiles0)
            setfiles{epo,1} = fullfile(datapath, setfiles0(epo).name); % cell array with EEG file names
        end
        correction_cap_location = hera('Projects/7TBrainMech/scripts/eeg/Shane/resources/ELchanLoc.ced');
        for i = 1:length(setfiles)
            EEG = homogenizeChanLoc(setfiles{i},correction_cap_location,savepath, outpath.main, task);
            EEG = pop_saveset(EEG, 'filename', homogenize_name, 'filepath', outpath.ICAwholeclean_homogenize);
        end
        
    end
end

end
