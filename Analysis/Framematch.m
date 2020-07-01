gaps=diff(a.frameStarts(:,1),1);
fig1 = figure();
title('Bpod Frame Gaps');
histogram(gaps);
sync = Value(strcmp(ChannelName,' BNC Sync Output'));
syncDiff = diff(sync,1,1);
syncIdx = find(syncDiff==1)+1;
syncTimes = Times(strcmp(ChannelName,' BNC Sync Output'));
frameTimes = syncTimes(syncIdx);
inscopixGaps=diff(frameTimes,1);
fig2 = figure();
title('Inscopix Frame Gaps');
histogram(inscopixGaps)
bpodFrames=size(a.frameStarts,1);
inscopixFrames = size(frameTimes,1);
inscopixFrames-bpodFrames

%% TROUBLESHOOTING

Bpodframestarts = a.frameStarts(:,1);

%{
both had 2 large gaps when 150 and 300 ms between trials. However, Bpod
missed a frame b/c it had 350 ms between trials

if trial gaps truly 200us, inscopix won't see them and turn off at 1000Hz.
1000Hz also enough to see 50ms incoming pulses

large gaps between trials account for like ~20 missing frames, but more
than 400! a whole extra video in session?!?
%}

%% sessions/videos

trig = Value(strcmp(ChannelName,' BNC Trigger Input'));
trigDiff = diff(trig);
trigTimes = Times(strcmp(ChannelName,' BNC Trigger Input'));
startIdx = find(trigDiff==1)+1;
stopIdx = find(trigDiff==-1)+1;
vidStarts = trigTimes(startIdx);
vidStops = trigTimes(stopIdx);
vidGaps = diff([vidStops(1:end-1) vidStarts(2:end)],1,2);

endTimes=a.TrialEndTimestamp(1:end-1);
startTimes=a.TrialStartTimestamp(2:end);
timeBetween=startTimes-endTimes;
trialLengths = a.TrialEndTimestamp-a.TrialStartTimestamp;

%%

bigGaps = gaps(gaps>0.052);
bigScopeGaps = inscopixGaps(inscopixGaps>0.052);