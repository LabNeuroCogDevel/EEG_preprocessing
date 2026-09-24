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

% plot removed components
comps2remove = find([EEG.reject.gcompreject] == 1);
icaact_comps = eeg_getdatact(EEG, 'component', comps2remove);
figure
spectopo(icaact_comps,0,EEG.srate,'freqrange',[0.5 70])
legend(string(comps2remove))
title(sprintf('SubID: %s, Scan Date: %s', subid,scandate));
savefig(fullfile(outpath.MarkedICAwhole,[icawholemarked_name '_rmcompspec.fig']));
exportgraphics(gcf,fullfile(outpath.MarkedICAwhole,[icawholemarked_name '_rmcompspec.png']));
close all;

% plot topography of removed components
for icacomp = 1:length(comps2remove)
    figure
    pop_topoplot(EEG, 0, comps2remove(icacomp),sprintf('SubID: %s, Scan Date: %s', subid,scandate),[1 1] ,0,'electrodes','on');
    savefig(fullfile(outpath.MarkedICAwhole,[icawholemarked_name '_IC' char(string(icacomp)) '.fig']));
    exportgraphics(gcf,fullfile(outpath.MarkedICAwhole,[icawholemarked_name '_IC' char(string(icacomp)) '.fig']));
    close all;
end

% plot EEG data before and after ICA component rejection
figure
plot(EEG.times./1000,EEG.data,'color','k')
hold on

% remove marked components
EEG = pop_subcomp(EEG, [], 0);

plot(EEG.times ./ 1000, EEG.data,'color','r')
xlabel('Time (s)'); ylabel("Voltage (uV)");
xlim([EEG.times(1) EEG.times(end)] ./ 1000);
title(sprintf('SubID: %s, Scan Date: %s\nVar before: %.1f, Var after: %.1f', subid,scandate, EEG.etc.varBeforeICArej,EEG.etc.varAfterICArej));
savefig(fullfile(outpath.MarkedICAwhole,[icawholemarked_name '_befaftICA.fig']));
exportgraphics(gcf,fullfile(outpath.MarkedICAwhole,[icawholemarked_name '_befaftICA.png']));
close all;

% save EEG with removed components
EEG = pop_saveset(EEG, 'filename', icawholeclean_name, 'filepath', outpath.ICAwholeclean);