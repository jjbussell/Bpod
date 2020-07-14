%%
%{
with laptop and triggered, no more big gaps but still a few hundred extra
inscopix frames--from last trial?!?

scope23--multiple vids, maybe large trial gap? also 12 s in last trial that
wasn't completed and maybe didn't save!!

%}

%%
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
missingFrames = inscopixFrames-bpodFrames

%% TROUBLESHOOTING

Bpodframestarts = a.frameStarts(:,1);

%{
both had 2 large gaps when 150 and 300 ms between trials. However, Bpod
missed a frame b/c it had 350 ms between trials

if trial gaps truly 200us, inscopix won't see them and turn off at 1000Hz.
1000Hz also enough to see 50ms incoming pulses

large gaps between trials account for like ~20 missing frames, but more
than 400! a whole extra video in session?!?

no, not extra pre-existing video. number of extra inscopix frames ~= the
pre-recording time? each trial has ~expected number of frames. slight diff
in b/t trial gaps can't explain 11s of missing frames.
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

%% TRIAL TIMES
endTimes=a.TrialEndTimestamp(1:end-1);
startTimes=a.TrialStartTimestamp(2:end);
timeBetween=startTimes-endTimes;
trialLengths = a.TrialEndTimestamp-a.TrialStartTimestamp;

%%

bigGaps = gaps(gaps>0.052);
bigScopeGaps = inscopixGaps(inscopixGaps>0.052);

%%
for t=1:a.trialCt
   framesInTrial(t,1)=a.trialFrames(t);
   framesInTrial2(t,1)=a.trialFrameStarts(t);
end