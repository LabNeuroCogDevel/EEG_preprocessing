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

% In MarkedICAwhole folder create new subject folder to save figures for QC
markedICA_subfolder = [ char(string(subid)) '_' char(string(scandate))];
markedICA_subpath = fullfile(outpath.MarkedICAwhole, markedICA_subfolder);
if isfolder(markedICA_subpath)
    fprintf("%d %d already has marked ICA folder; skipping\n",subid,scandate)
else
    mkdir(markedICA_subpath)
end

% find components marked for rejection
comps2remove = find([EEG.reject.gcompreject] == 1);

% plot removed components
icaact_removecomps = eeg_getdatact(EEG, 'component', comps2remove);
figure
spectopo(icaact_removecomps,0,EEG.srate,'freqrange',[0.5 70])
legend(string(comps2remove))
title(sprintf('SubID: %d, Scan Date: %d', subid,scandate));
exportgraphics(gcf,fullfile(markedICA_subpath,[icawholemarked_name '_rmcompspec.png']));
close all;

% plot topography of removed components
for icacomp = 1:length(comps2remove)
    figure
    pop_topoplot(EEG, 0, comps2remove(icacomp),sprintf('SubID: %d, Scan Date: %d', subid,scandate),[1 1] ,0,'electrodes','on');
%     savefig(fullfile(markedICA_subpath,[icawholemarked_name '_IC' char(string(comps2remove(icacomp))) '.fig']));
    exportgraphics(gcf,fullfile(markedICA_subpath,[icawholemarked_name '_IC' char(string(comps2remove(icacomp))) '.png']));
    close all;
end

% plot EEG data before and after ICA component rejection
figure
plot(EEG.times./1000,EEG.data,'color','k')
hold on

% Save specific component number removed

% remove marked components
EEG = pop_subcomp(EEG, [], 0);

plot(EEG.times ./ 1000, EEG.data,'color','r')
xlabel('Time (s)'); ylabel("Voltage (uV)");
xlim([EEG.times(1) EEG.times(end)] ./ 1000);
title(sprintf('SubID: %d, Scan Date: %d\nVar before: %.1f, Var after: %.1f', subid,scandate, EEG.etc.varBeforeICArej,EEG.etc.varAfterICArej));
% savefig(fullfile(markedICA_subpath,[icawholemarked_name '_befaftICA.fig']));
exportgraphics(gcf,fullfile(markedICA_subpath,[icawholemarked_name '_befaftICA.png']));
close all;

% save EEG with removed components
EEG = pop_saveset(EEG, 'filename', icawholeclean_name, 'filepath', outpath.ICAwholeclean);