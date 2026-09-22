epochfilename = [epoch_files(currentepochEEG).name];
newepochfilename = [regexprep(epochfilename,'\.set$',''), '_scored.set'];
id_date = regexp(epochfilename,'\d{5}_\d{8}','match','once');
match_idx = ~cellfun(@isempty, regexp({renamed_files.name}, id_date,'match'));
renamedfilename = [renamed_files(match_idx).name];
% load epoch and renamed EEGs
renamedEEG = pop_loadset(fullfile(paths.renamedtrials,renamedfilename));
epochEEG = pop_loadset(fullfile(paths.kept_epoch,epochfilename));
% get original event number from renamedEEG
% correct trials
cor_orig = strcmp({renamedEEG.event(:).type},'2_cor');
cor_orig_urevent = [renamedEEG.event(cor_orig).urevent];
urevent_match_idx = ismember([epochEEG.event.urevent], cor_orig_urevent);
[epochEEG.event(urevent_match_idx).type] = deal(21);
% incorrect trials
incor_orig = strcmp({renamedEEG.event(:).type},'2_incor');
incor_orig_urevent = [renamedEEG.event(incor_orig).urevent];
urevent_match_idx = ismember([epochEEG.event.urevent], incor_orig_urevent);
[epochEEG.event(urevent_match_idx).type] = deal(20);
% error correct trials
errcor_orig = strcmp({renamedEEG.event(:).type},'2_errcor');
errcor_orig_urevent = [renamedEEG.event(errcor_orig).urevent];
urevent_match_idx = ismember([epochEEG.event.urevent], errcor_orig_urevent);
[epochEEG.event(urevent_match_idx).type] = deal(22);
% dropped trials
drop_orig = strcmp({renamedEEG.event(:).type},'2_drop');
drop_orig_urevent = [renamedEEG.event(drop_orig).urevent];
urevent_match_idx = ismember([epochEEG.event.urevent], drop_orig_urevent);
[epochEEG.event(urevent_match_idx).type] = deal(19);

% save scored epoch
epochEEG = eeg_checkset(epochEEG, 'eventconsistency');
EEG = pop_saveset(epochEEG, 'filename', newepochfilename, 'filepath', paths.kept_epoch);