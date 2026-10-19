EEG = pop_loadset(WholeICAFile);

% add IC labels (even though doing manual rejection)
EEG = pop_iclabel(EEG, 'default');

% to reject ICs in GUI need to make sure the base workspace has THIS subject's EEG
assignin('base','EEG',EEG)

pop_selectcomps(EEG, 1:size(EEG.icaweights,1));
pop_eegplot(EEG,0,1,1);

% add breakpoint before saving marked ICs to reject
% mark components in the GUI, click "Accept" (or close) then type "return" in command window
keyboard;

% pull in the GUI's updated flags back into the local EEG
EEG = evalin('base','EEG');

% save flagged components in one file
EEG = pop_saveset(EEG, 'filename', icawholemarked_name, 'filepath', outpath.MarkedICAwhole);
eeglab redraw

% In MarkedICAwhole folder create new subject folder to save figures for QC
markedICA_subfolder = [ char(string(subid)) '_' char(string(scandate))];
markedICA_subpath = fullfile(outpath.MarkedICAwhole, markedICA_subfolder);
if isfolder(markedICA_subpath)
    fprintf("%d %d already has marked ICA folder\n",subid,scandate)
else
    mkdir(markedICA_subpath)
end

% find components marked for rejection
comps2remove = find([EEG.reject.gcompreject] == 1);
fprintf('Removing %d components: %s\n', numel(comps2remove), mat2str(comps2remove));

% plot removed components
icaact_removecomps = eeg_getdatact(EEG, 'component', comps2remove);
figure
spectopo(icaact_removecomps,0,EEG.srate,'freqrange',[0.5 70]);
legend(string(comps2remove))
title(sprintf('SubID: %d, Scan Date: %d', subid,scandate));
exportgraphics(gcf,fullfile(markedICA_subpath,[icawholemarked_name '_rmcompspec.png']));
close all;

% plot topography of removed components
for icacomp = 1:length(comps2remove)
    figure
    pop_topoplot(EEG, 0, comps2remove(icacomp),sprintf('SubID: %d, Scan Date: %d', subid,scandate),[1 1] ,0,'electrodes','on');
    exportgraphics(gcf,fullfile(markedICA_subpath,[icawholemarked_name '_IC' char(string(comps2remove(icacomp))) '.png']));
    close all;
end

% plot EEG data before and after ICA component rejection
figure
plot(EEG.times./1000,EEG.data,'color','k')
hold on

% remove marked components
EEG = pop_subcomp(EEG, [], 0);

% on same figure plot after ICA component rejection
plot(EEG.times ./ 1000, EEG.data,'color','r')
xlabel('Time (s)'); ylabel("Voltage (uV)");
xlim([EEG.times(1) EEG.times(end)] ./ 1000);
title(sprintf('SubID: %d, Scan Date: %d\nVar before: %.1f, Var after: %.1f', subid,scandate, EEG.etc.varBeforeICArej,EEG.etc.varAfterICArej));
exportgraphics(gcf,fullfile(markedICA_subpath,[icawholemarked_name '_befaftICA.png']));
close all;

% save EEG with removed components
EEG = pop_saveset(EEG, 'filename', icawholeclean_name, 'filepath', outpath.ICAwholeclean);