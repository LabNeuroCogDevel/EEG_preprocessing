%% define channel locations
spastudy_habitcap = 0; % default is 0 b/c normally correct cap is used for SPA
% load in eeg comments for study
if strcmp(study,'Habit')
    eeg_comments = readtable("/Volumes/Hera/EEG_toolkit/Resources/habit_eeg_comments.csv");
elseif strcmp(study,'SPA')
    eeg_comments = readtable("/Volumes/Hera/EEG_toolkit/Resources/spa_eeg_comments.csv");
    % convert current scandate to datetime variable that matches eeg_comments table      
    scandate_DATE = datetime(scandate,'ConvertFrom','yyyymmdd');
    scandate_DATE.Format = 'yyyy-MM-dd';
    % find if scandate and lunaid matches any row of eeg_comments
    match_idx = find(eeg_comments.record_id == lunaid & eeg_comments.eegscandate == scandate_DATE);
    if isempty(match_idx)
        fprintf("No eeg comments for %d %d\n",lunaid,scandate)
    else
        % get specific comments for current subject
        sub_comment = string(eeg_comments.eeg_comments(match_idx));
        % was Habit cap used?
        spastudy_habitcap = contains(sub_comment,'habit cap','IgnoreCase',true);
        if spastudy_habitcap
            warning("Habit cap used for %d %d\nChanging preproc to Habit for channel rejection step\n",lunaid,scandate)
            study = 'Habit';
        end
    end
end

% fixing if 128 channel setup for 7T
if size(EEG.data,1) > 100 && strcmp(study,'7T')
    EEG = pop_select( EEG,'channel',commonPlus);
    EEG = pop_chanedit(EEG, 'load', {correction_cap_location 'filetype' 'autodetect'});
    % 128    'AF8' --> 64    'AF6'
    % 128    'AF7' --> 64    'AF5'
    % 128    'AF4' --> 64    'AF2'
    % 128    'AF3' --> 64    'AF1'

else % less than 100 channels
    % Define cap layout for different studies
    if strcmp(study, '7T')
        %% 7T
        % just need to remove external channels
        EEG = pop_chanedit(EEG, 'lookup', cap_location);
       
        % remove external channels
        EEG = pop_select( EEG,'nochannel',{'EX3' 'EX4' 'EX5' 'EX6' 'EX7' 'EX8' 'EXG1' 'EXG2' 'EXG3' 'EXG4' 'EXG5' 'EXG6' 'EXG7' 'EXG8'});
    
    elseif strcmp(study,'Habit') && (scandate <= 20260129)
        %% Habit before new B band (20260129) and before new config file (20261012)
        % Matches old 7T -> just need to remove external channels
        EEG = pop_chanedit(EEG, 'lookup', cap_location);
       
        % remove external channels
        EEG = pop_select( EEG,'nochannel',{'EX3' 'EX4' 'EX5' 'EX6' 'EX7' 'EX8' 'EXG1' 'EXG2' 'EXG3' 'EXG4' 'EXG5' 'EXG6' 'EXG7' 'EXG8'});
        
    elseif strcmp(study,'Habit') && (scandate > 20260129) && (scandate < 20261012)
        %% Habit after new B band (20260129) and before new config file (20261012)
        % New B band does not have PO10 electrode lead
        % New B band has TP8 lead instead; TP8 lead plugged into TP8 on cap
        % In config file TP8 still labeled as PO10
        channel_labels = string({EEG.chanlocs(:).labels})';
        PO10_label_idx = find(channel_labels == "PO10");
        % PO10 channel label should always be 62
        if PO10_label_idx ~= 62
            error("PO10 label does not correspond with channel number 62")
        end
        EEG.chanlocs(PO10_label_idx).labels = 'TP8';
        
        % define channel locations
        EEG = pop_chanedit(EEG, 'lookup', cap_location);
        % remove external channels
        EEG = pop_select( EEG,'nochannel',{'EX3' 'EX4' 'EX5' 'EX6' 'EX7' 'EX8' 'EXG1' 'EXG2' 'EXG3' 'EXG4' 'EXG5' 'EXG6' 'EXG7' 'EXG8'});
        
    elseif strcmp(study,'Habit') && (scandate > 20260129) && (scandate >= 20261012)
        %% Habit after new B band (20260129) and after new config file (20261012)
        % New B band does not have PO10 electrode lead
        % New B band has TP8 lead instead; TP8 lead plugged into TP8 on cap
        % In new config file TP8 is labels -> do not need to change EEG.chanlocs.label
        
        % check that the label TP8 exists
        channel_labels = string({EEG.chanlocs(:).labels})';
        TP8_label_idx = find(channel_labels == "TP8");
        
        % Error if TP8 channel label does not exist
        if isempty(TP8_label_idx)
            error("TP8 channel label does not exist")
        end
        
        % TP8 channel label should always be 62
        if TP8_label_idx ~= 62
            error("TP8 label does not correspond with channel number 62")
        end
        
        % define channel locations
        EEG = pop_chanedit(EEG, 'lookup', cap_location);
        % remove external channels
        EEG = pop_select( EEG,'nochannel',{'EX3' 'EX4' 'EX5' 'EX6' 'EX7' 'EX8' 'EXG1' 'EXG2' 'EXG3' 'EXG4' 'EXG5' 'EXG6' 'EXG7' 'EXG8'});
                
    
    elseif strcmp(study,'SPA') && (scandate <= 20260129)
        %% SPA before new B band and before new config file      
        channel_labels = string({EEG.chanlocs(:).labels})';
        
        % Mislabeled channels:
        %   AF1 lead -> AF3 cap location (AF1 on config file)
        AF1_label_idx = find(channel_labels == "AF1");
        EEG.chanlocs(AF1_label_idx).labels = 'AF3';
        %   AF5 lead -> AF7 cap location (AF5 on config file)
        AF5_label_idx = find(channel_labels == "AF5");
        EEG.chanlocs(AF5_label_idx).labels = 'AF7';
        %   FT9 lead -> FT7 cap location (FT9 on config file)
        FT9_label_idx = find(channel_labels == "FT9");
        EEG.chanlocs(FT9_label_idx).labels = 'FT7';
        %   AF2 lead -> AF4 cap location (AF2 on config file)
        AF2_label_idx = find(channel_labels == "AF2");
        EEG.chanlocs(AF2_label_idx).labels = 'AF4';
        %   AF6 lead -> AF8 cap location (AF6 on config file)
        AF6_label_idx = find(channel_labels == "AF6");
        EEG.chanlocs(AF6_label_idx).labels = 'AF8';
        %   FT8 lead -> FT8 cap location (FT10 on config file)
        FT10_label_idx = find(channel_labels == "FT10");
        EEG.chanlocs(FT10_label_idx).labels = 'FT8';
        %   I2 lead -> Iz cap location (I2 on config file)
        I2_label_idx = find(channel_labels == "I2");
        EEG.chanlocs(I2_label_idx).labels = 'Iz';
        
        % Not recording data from:
        %   I1 lead (I1 in config file)  (to be plugged into TP7 with new config file)
        %   PO9 lead (PO9 in config file) (to be plugged into FP7 with new config file)
        %   TP8 lead (PO10 in config file) (to be plugged into TP8 with new B band)        
        % ^^ Cap locations TP7, FP7, and TP8 are empty
        I1_label_idx = find(channel_labels == "I1");
        EEG.chanlocs(I1_label_idx).labels = 'TP7';
        
        PO9_label_idx = find(channel_labels == "PO9");
        EEG.chanlocs(PO9_label_idx).labels = 'FPz';
        
        PO10_label_idx = find(channel_labels == "PO10");
        EEG.chanlocs(PO10_label_idx).labels = 'TP8';
        
        % now can put in channel locations
        EEG = pop_chanedit(EEG, 'lookup', cap_location);

        % remove external channels
        EEG = pop_select( EEG,'nochannel',{'EX3' 'EX4' 'EX5' 'EX6' 'EX7' 'EX8' 'EXG1' 'EXG2' 'EXG3' 'EXG4' 'EXG5' 'EXG6' 'EXG7' 'EXG8'});
        
        % interpolate 3 channels not being recorded from
        missing_chans = [I1_label_idx PO9_label_idx PO10_label_idx];
        
        EEG = pop_interp(EEG, missing_chans, "spherical");   
        
    elseif  strcmp(study,'SPA') && (scandate > 20260129) && (scandate < 20261012)
        %% SPA after new B band (20260129) and before new config file (20261012)     
        channel_labels = string({EEG.chanlocs(:).labels})';
        
        % Mislabeled channels:
        %   AF1 lead -> AF3 cap location (AF1 on config file)
        AF1_label_idx = find(channel_labels == "AF1");
        EEG.chanlocs(AF1_label_idx).labels = 'AF3';
        %   AF5 lead -> AF7 cap location (AF5 on config file)
        AF5_label_idx = find(channel_labels == "AF5");
        EEG.chanlocs(AF5_label_idx).labels = 'AF7';
        %   FT9 lead -> FT7 cap location (FT9 on config file)
        FT9_label_idx = find(channel_labels == "FT9");
        EEG.chanlocs(FT9_label_idx).labels = 'FT7';
        %   AF2 lead -> AF4 cap location (AF2 on config file)
        AF2_label_idx = find(channel_labels == "AF2");
        EEG.chanlocs(AF2_label_idx).labels = 'AF4';
        %   AF6 lead -> AF8 cap location (AF6 on config file)
        AF6_label_idx = find(channel_labels == "AF6");
        EEG.chanlocs(AF6_label_idx).labels = 'AF8';
        %   FT8 lead -> FT8 cap location (FT10 on config file)
        FT10_label_idx = find(channel_labels == "FT10");
        EEG.chanlocs(FT10_label_idx).labels = 'FT8';
        %   I2 lead -> Iz cap location (I2 on config file)
        I2_label_idx = find(channel_labels == "I2");
        EEG.chanlocs(I2_label_idx).labels = 'Iz';
        %   TP8 lead -> TP8 cap location (PO10 on config file)
        PO10_label_idx = find(channel_labels == "PO10");
        EEG.chanlocs(PO10_label_idx).labels = 'TP8';
        
        % Not recording data from:
        %   I1 lead (I1 in config file)  (to be plugged into TP7 with new config file)
        %   PO9 lead (PO9 in config file) (to be plugged into FP7 with new config file)  
        % ^^ Cap locations TP7 and FP7 are empty
        
        I1_label_idx = find(channel_labels == "I1");
        EEG.chanlocs(I1_label_idx).labels = 'TP7';
        
        PO9_label_idx = find(channel_labels == "PO9");
        EEG.chanlocs(PO9_label_idx).labels = 'FPz';
        
        % now can put in channel locations
        EEG = pop_chanedit(EEG, 'lookup', cap_location);

        % remove external channels
        EEG = pop_select( EEG,'nochannel',{'EX3' 'EX4' 'EX5' 'EX6' 'EX7' 'EX8' 'EXG1' 'EXG2' 'EXG3' 'EXG4' 'EXG5' 'EXG6' 'EXG7' 'EXG8'});
        
        % interpolate 2 channels not being recorded from
        missing_chans = [I1_label_idx PO9_label_idx];
        
        EEG = pop_interp(EEG, missing_chans, "spherical");   
    elseif strcmp(study,'SPA') && (scandate > 20260129) && (scandate >= 20261012)
        %% SPA after new B band (20260129) and after new config file (20261012) 
        % No changing labels need -> locations should match config file
        channel_labels = string({EEG.chanlocs(:).labels})';
        % check that Iz label exists
        Iz_label_idx = find(channel_labels == "Iz");
        if isempty(Iz_label_idx)
            error("Iz channel label not found")            
        end      
        
        % check that TP7 label exists
        TP7_label_idx = find(channel_labels == "TP7");
        if isempty(TP7_label_idx)
            error("TP7 channel label not found")            
        end 
        
        % now can put in channel locations
        EEG = pop_chanedit(EEG, 'lookup', cap_location);

        % remove external channels
        EEG = pop_select( EEG,'nochannel',{'EX3' 'EX4' 'EX5' 'EX6' 'EX7' 'EX8' 'EXG1' 'EXG2' 'EXG3' 'EXG4' 'EXG5' 'EXG6' 'EXG7' 'EXG8'});
        
    end    
end

%% Bad Channel Rejection
% bad channels are in general the channels that you can't save even if you reject 5-10% of your datapoints
% from eeglab wiki: plot channel spectrum and ID outliers with spectopo()
% 3 options for channel rejection:
% 1. look at standard deviation in bar plots and remove the channels
% 2. kurtosis
% 3. clean_rawdata - this method removed events from EEG set and lost individual anti trials
% maybe use clean_rawdata but need to tweak from original pipeline

% originalEEG has channel locations and external channels removed- need for determining which channels have been rejected
originalEEG = EEG;
EEG.origchanlocs = EEG.chanlocs;

EEG = clean_rawdata(EEG, 8, -1, 0.7, 5, 15, 0.3);
% clean_rawdata inputs:
% (EEG, arg_flatline, arg_highpass, arg_channel, arg_noisy, arg_burst,arg_window)
% see clean_rawdata for description of what inputs mean
% arg_highpass = -1 : already highpassed data do not need to do again
% LOOK AT OTHER PARAMETERS

% what is clean_channel_mask???
if ~any(find(cellfun (@any,regexpi (fieldnames(EEG.etc), 'clean_channel_mask'))))
    EEG.etc.clean_channel_mask=42;
end

%save the channels that were rejected in a variable
channels_removed{1} = chrm_name; %setname
channels_removed{2} = setdiff({EEG.origchanlocs.labels},{EEG.chanlocs.labels}, 'stable');
channels_removed{3} = find(EEG.etc.clean_channel_mask==0);

%also save the channels that were rejected in the EEG struct
EEG.channels_rj = channels_removed{2};
EEG.channels_rj_nr = length(EEG.channels_rj);

%save the proportion of the dataset that were rejected in a variable
data_removed{1} = datarm_name; %setname
data_removed{2} = length(find(EEG.etc.clean_sample_mask==0))/EEG.srate;% seconds of removed data
data_removed{3} = length(find(EEG.etc.clean_sample_mask==0))/length(EEG.etc.clean_sample_mask);% percent data removed

%also save the data that were rejected in the EEG struct
EEG.data_rj    = data_removed{2};
EEG.data_rj_nr = data_removed{3};

% In channels_rj folder create new subject folder to save figures for QC
channelsrj_subfolder = [ char(string(subid)) '_' char(string(scandate))];
channelsrj_subpath = fullfile(outpath.channels_rejected, channelsrj_subfolder);
if isfolder(channelsrj_subpath)
    fprintf("%d %d already has marked channel folder; skipping\n",subid,scandate)
else
    mkdir(channelsrj_subpath)
end

% visualize data removed and save interactive figure
% when no channels have been removed vis_artifacts fails FIX!!!
if isempty(EEG.channels_rj)
    fprintf("No channels removed; not running vis_artifacts\n")
else
    vis_artifacts(EEG,originalEEG,'DisplayMode','diff')
    savefig(fullfile(channelsrj_subpath,[char(string(subid)) '_' char(string(scandate)) '_chansrj.fig']))
    close all
end

% if changed to Habit because wrong cap was used switch study back to SPA
if spastudy_habitcap
   fprintf("Ran channel rejection for %d %d using habit cap\nSwitching study back to SPA",lunaid,scandate)
   study = 'SPA';
end

%change setname
EEG = pop_editset(EEG,'setname', chrm_name);
% save with all fields added
EEG = pop_saveset( EEG,'filename', chrm_name, ...
    'filepath', outpath.channels_rejected);