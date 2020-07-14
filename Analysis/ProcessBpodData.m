%% LOAD FILE

clear all;
close all;

fname = 'infoSeekBpodData.mat';
load(fname); % opens structure "a" with previous data, if available

numFiles = numel(a.filename);

%% TRIAL STATE DATA

a.file = [];
a.trialType = [a.data(:).TrialTypes]';

a.TrialEvents = [a.RawEvents(:).Trial];
a.TrialEvents = [a.TrialEvents{:}]';
a.States = [a.TrialEvents(:).States]';
% a.Events = [a.TrialEvents(:).Events];


for f = 1:numFiles
    nTrials = a.trialCt(f);
    for t=1:nTrials
        trialFile(t,1) = f;   
    end
    a.file = [a.file; trialFile];
    trialFile = [];
end

%% EVENTS

for e = 1:a.nEvents
   eventName = a.EventNames{e};
   a.Events.eventName=[];
   for t = 1:a.trialCt
       if isfield(a.TrialEvents(t).Events,eventName)
            a.Events.(eventName){t} = a.TrialEvents(t).Events.(eventName);
       else
           a.Events.(eventName){t} = [];
       end
   end
end



%% CALC TRIAL START LAG

%% VIDEO FRAMES
if ~isempty(a.Events.BNC1High{1})
    % BNC1High, BNC1Low
    a.frameStarts = [];
    a.frameStops = [];
    for f = 1:numFiles
        for t = 1:a.trialCt
           frameStarts = [];
           frameStops = [];
           trialFramesStarts = [];
           trialFramesStop = [];
           if ~isempty(a.Events.BNC1High{t})
               trialFramesStart = a.Events.BNC1High{t}+a.TrialStartTimestamp(t);
               trialFramesStop = a.Events.BNC1Low{t}+a.TrialStartTimestamp(t);       
               frameStarts(:,1) = trialFramesStart';
               frameStarts(:,2) = t;
               frameStarts(:,3) = f;
               a.frameStarts = [a.frameStarts; frameStarts];
               frameStops(:,1) = trialFramesStop';
               frameStops(:,2) = t;
               frameStops(:,3) = f;
               a.frameStops = [a.frameStops; frameStops];
               a.trialFrameStarts(t) = numel(trialFramesStart);
               a.trialFrameStops(t) = numel(trialFramesStop);
           end
        end
    end

    a.trialFrames = cumsum(a.trialFrameStarts);
end



%% TIMES AND COUNTS FOR EACH STATE

fields = fieldnames(a.States);
a.stateNames = fields;
for i = 1:length(fields)
    for t = 1:sum(a.trialCt)
        a.(fields{i}){t,1}= {a.States(t).(fields{i})};
        state = {a.States(t).(fields{i})};
        statetimes = state{1};
        if isnan(a.States(t).(fields{i}))
            a.stateCount(t,i) = 0;
            a.([(fields{i}) 'Final'])(t,[1 2]) = 0;
            a.([(fields{i}) 'First'])(t,[1 2]) = 0;
        else
            a.stateCount(t,i) = size(a.States(t).(fields{i}),1);
            a.([(fields{i}) 'Final'])(t,[1 2]) = statetimes(end,:);
            a.([(fields{i}) 'First'])(t,[1 2]) = statetimes(1,:);
        end
    end
    a.(fields{i}) = [a.(fields{i}){:}]';   
end

%% TRIAL SETTINGS

a.settings = [a.TrialSettings(:).GUI];

fields = fieldnames(a.settings);

for i = 1:length(fields)
   a.(fields{i}) = [a.settings(:).(fields{i})]';
end


%% NEED ENTRIES AND EXITS -- calc time on side/leaving



%% INITIATION

a.correctInitiation = a.stateCount(:,find(strcmp(a.stateNames,'WaitForCenter'))) == 1;


%% CHOICE

chooseLeftState = find(strcmp(a.stateNames,'WaitForOdorLeft'));
chooseRightState = find(strcmp(a.stateNames,'WaitForOdorRight'));
noChoiceState = find(strcmp(a.stateNames,'NoChoice'));
incorrectLeftState = find(strcmp(a.stateNames,'IncorrectLeft'));
incorrectRightState = find(strcmp(a.stateNames,'IncorrectRight'));
incorrectState = find(strcmp(a.stateNames,'Incorrect'));
rightNPState = find(strcmp(a.stateNames,'RightNotPresent'));
leftNPState = find(strcmp(a.stateNames,'LeftNotPresent'));

choiceMat = a.stateCount(:,[chooseLeftState chooseRightState noChoiceState...
    incorrectLeftState incorrectRightState incorrectState]);
a.choiceNames = {'ChooseLeft';'ChooseRight';'NoChoice';'IncorrectLeft';'IncorrectRight';'Incorrect'};
a.choice = zeros(sum(a.trialCt),1);
a.choiceInfo = zeros(sum(a.trialCt),1);
a.notPresent = zeros(sum(a.trialCt),1);
a.reward = zeros(sum(a.trialCt),1);
for t = 1:sum(a.trialCt)
   a.choice(t,1) = find(choiceMat(t,:)); 
   a.notPresent(t,1) = sum(a.stateCount(t,[rightNPState leftNPState]));
   if ~isnan(a.LeftBigReward{t}) | ~isnan(a.RightBigReward{t})
       a.reward(t,1) = 1;
   end    
end

for t = 1:sum(a.trialCt)
   switch a.choice(t)
       case 1
           if a.InfoSide(t) == 0
               a.choiceInfo(t) = 1;
           else
               a.choiceInfo(t) = 0;
           end
       case 2
           if a.InfoSide(t) == 0
              a.choiceInfo(t) = 0;
           else
               a.choiceInfo(t) = 1;
           end
       case 3
           a.choiceInfo(t) = 2;
       case 4
           a.choiceInfo(t) = 3;
       case 5
           a.choiceInfo(t) = 3;
       case 6
           a.choiceInfo(t) = 3;
   end
end


a.correct = zeros(sum(a.trialCt),1);
a.correct(a.choice<3)=1;

%% OUTCOME

%{
a.outcome = zeros(sum(a.trialCt),1);
for t = 1:sum(a.trialCt)
   % CHOICE TRIALS
   if a.trialType(t) == 1
       % NO CHOICE
       if a.choiceInfo(t) == 2
            a.outcome(t,1) = 1; % choice no choice
       % INFO
       elseif a.choiceInfo(t) == 1
           if a.reward(t) == 1
               a.outcome = 2; % choice info big
   
end
%}


% a.infoSide --
% rewardsizes--
% a.choice --
% a.outcome
% a.rxn
% a.reward--
% a.correct-
% a.error
% a.water

% odors
% trial length
% reward rate
% entrances/exits


% mouse, file, day, mouse day -> based on file




%% DAY AND SESSION SUMMARY

% a.percentCorrectCenterEntries;

