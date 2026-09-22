[~, currentName, ~ ] = fileparts(EEG.filename);
parts = split(currentName,'_');
subid = str2double(parts{1});
scandate = str2double(parts{2});
task_type = parts{3};
preprocVer = parts{4};

data = struct();

data.preprocessing_ver = preprocVer;
data.task = task_type;
data.subid = subid;
data.scandate = scandate;
data.removed_channels = EEG.channels_rj;
data.num_removed_channels = EEG.channels_rj_nr;

EEGICA = pop_loadset(MarkedICAFile);
rejectedICs = find(EEGICA.reject.gcompreject);
data.num_ICs_reject = numel(rejectedICs);

ICclass = EEGICA.etc.ic_classification.ICLabel.classifications;
rejectedICs_classes = ICclass(rejectedICs,:);
classNames = EEGICA.etc.ic_classification.ICLabel.classes;
[~,classIdx] = max(rejectedICs_classes,[],2);

for i = 1:numel(rejectedICs)
    data.ICs_reject(i).IC = rejectedICs(i);
    data.ICs_reject(i).ICs_reject_classification = ICclass(rejectedICs(i),:);
    data.ICs_reject(i).ICs_reject_main_class = classNames{classIdx(i)};
end

originalVar = var(double(EEGICA.data(:)));
cleanVar = var(double(EEG.data(:)));
removedVar = originalVar-cleanVar;
percentVarRemoved = 100*removedVar/originalVar;

data.original_variance = originalVar;
data.final_variance = cleanVar;
data.percent_variance_removed = percentVarRemoved;

data.final_rank = rank(EEG.data');

save(fullfile(QC_file),'data');
