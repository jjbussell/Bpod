gaps=diff(a.frameStarts(:,1),1);
histogram(gaps)
sync = Value(strcmp(ChannelName,' BNC Sync Output'));
syncDiff = diff(sync,1,1);
syncIdx = find(syncDiff==1)+1;
syncTimes = Times(strcmp(ChannelName,' BNC Sync Output'));
frameTimes = syncTimes(syncIdx);
inscopixGaps=diff(frameTimes,1);
histogram(inscopixGaps)
bpodFrames=size(a.frameStarts,1);
inscopixFrames = size(frameTimes,1);
inscopixFrames-bpodFrames

%% TROUBLESHOOTING
