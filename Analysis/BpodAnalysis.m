% check control sums, reward rates
% be sure counting incorrect, nochoice, NP trials correctly! are they
% "correct"? are they included in info, info big, etc??


% assign day and mouse and infoside and correct and choice and trial type to each trial
% calc reaction time
% calc trial length
% calc water
% day summary: outcomes, (rewards, reward rt, rxn, error) by type, num
% trials by type, % correct, % correct initiation, % choice

% LATER
% reversals
% stats
% leaving/entries/dwell time
% prob of in port
% LICKS!!!!

% day summary/errors by outcome/reward rate
% add errors to day summary!

%% EXPAND MULTIPLE STATE OCCURRANCES

% state = a.WaitForCenter;
% state = a.WaitForOdorLeft;

for s = 1:numel(a.stateList)

    statename = a.stateList{s};
    state = a.(stateList{s});
% multicheck = cell2mat(cellfun(@(x) size(x,1),state,'UniformOutput',false));
% if(sum(multicheck>1)>0)
%     multistates = 1
% end

    maxLength = max(cellfun(@numel,state));

    result=cellfun(@(x) [reshape(x,1,[]),NaN(1,maxLength-numel(x))],state,'UniformOutput',false);
    result2=vertcat(result{:});

%     statename='WaitForOdorLeft';
    a.statesExpanded.(statename) = result2;
    result = [];
    result2 = [];
end


%% EXPAND EVENTS

eventsToExpand = {'GlobalTimer3_Start','GlobalTimer4_Start','GlobalTimer3_End','GlobalTimer4_End'};
% eventList = a.eventList;
eventList = eventsToExpand;

for e = 1:numel(eventList)

    eventname = eventList{e};
    event = a.(eventList{e});

    maxLength = max(cellfun(@numel,event));

    result=cellfun(@(x) [reshape(x,1,[]),NaN(1,maxLength-numel(x))],event,'UniformOutput',false);
    result2=vertcat(result{:});

%     statename='WaitForOdorLeft';
    a.eventsExpanded.(eventname) = result2;
    result = [];
    result2 = [];
end


%% INFOSIDE

a.infoSide = [a.trialSettings.InfoSide]';

%% TRIAL COUNT
a.trialCt = numel(a.trialType);

%% DAY AND MOUSE
a.day2 = reshape([a.day{:}],[8],[])';
datevec=[a.files(:).date];
a.fileDayCell=cellstr(reshape(datevec,[8],[])');
days=unique(a.fileDayCell);
mousevec=[a.files(:).mouse];
a.fileMouseCell=cellstr(reshape(mousevec,[],[numel(a.files)])');

% find(ismember(days,a.filedays))

a.mouseList = unique(a.mouse);
a.mouseCt = numel(a.mouseList);

for m = 1:a.mouseCt
   a.mice(:,m) = strcmp(a.mouse,a.mouseList(m)) == 1;
   mouseFileIdx = strcmp(a.fileMouseCell,a.mouseList{m});
   a.mouseDays{m} = unique(a.fileDayCell(mouseFileIdx)); % sorts
   a.mouseDayCt(m) = size(a.mouseDays{m},1);
   mouseFirstDay = find(strcmp(a.mouse,a.mouseList{m})& strcmp(a.day,a.mouseDays{m}(1)),1);
   a.initinfoside(m) = a.infoSide(mouseFirstDay);
end

for f = 1:numel(a.files)
   a.fileMouse(f,1) = find(strcmp(cellstr(a.files(f).mouse),a.mouseList));
   a.fileDay(f,1) = find(strcmp(cellstr(a.files(f).date),a.mouseDays{a.fileMouse(f)}));
end

for t = 1:a.trialCt
   a.mouseDay(t,1) = a.fileDay(a.file(t)); 
end

%% INITIAL INFO SIDE

% infoSide = 0, info left

a.initinfoside_info = -ones(a.trialCt,1); % initinfoside_info all trials by info-ness. 1 if initinfoside, -1 if reversed
a.initinfoside_side = ones(a.trialCt,1); % initinfoside_side all trials

for m = 1:a.mouseCt
    ok = a.mice(:,m) == 1;
    a.initinfoside_info(a.infoSide == a.initinfoside(m) & ok == 1) = 1;
end

%%
% choice is waitforodorleft,waitforodorright,incorrect,nochoice

a.choice = NaN(a.trialCt,1);

a.leftChoice = a.statesExpanded.WaitForOdorLeft(:,1);
a.rightChoice = a.statesExpanded.WaitForOdorRight(:,1);
a.incorrectChoice = a.statesExpanded.Incorrect(:,1);
a.noChoice = a.statesExpanded.NoChoice(:,1);
a.incorrect = ~isnan(a.incorrectChoice);

% CORRECT = CHOSE CORRECTLY (includes NP but not no choice or incorrect)
a.correct = ~isnan(a.leftChoice)|~isnan(a.rightChoice); % doesn't include no choice or incorrect

% time of choice
a.choice(~isnan(a.leftChoice)) = a.leftChoice(~isnan(a.leftChoice));
a.choice(~isnan(a.rightChoice)) = a.rightChoice(~isnan(a.rightChoice));
a.choice(~isnan(a.incorrectChoice)) = a.incorrectChoice(~isnan(a.incorrectChoice));
a.choice(~isnan(a.noChoice)) = a.noChoice(~isnan(a.noChoice));

%% INFO includes incorrect but not nochoice

a.info = NaN(a.trialCt,1);
a.info((a.infoSide == 0) & ~isnan(a.leftChoice)) = 1;
a.info((a.infoSide == 0) & ~isnan(a.rightChoice)) = 0;
a.info((a.infoSide == 1) & ~isnan(a.rightChoice)) = 1;
a.info((a.infoSide == 1) & ~isnan(a.leftChoice)) = 0;
a.info((a.trialType == 2) & ~isnan(a.incorrectChoice)) = 0;
a.info((a.trialType == 3) & ~isnan(a.incorrectChoice)) = 1;

a.choice_all = a.info; % choice relative to initial info side, all trials
reverseFlag = a.initinfoside_info == -1;
a.choice_all(reverseFlag) = ~a.choice_all(reverseFlag);

%% REACTION TIME AND TRIAL LENGTH

a.rxn = a.choice-a.statesExpanded.GoCue(:,1);

a.trialLengthTotal = a.endTime - a.startTime;
a.trialLength = a.endTime - a.statesExpanded.GoCue(:,1) + a.startTime;
a.trialLengthCenterEntry = a.endTime - a.statesExpanded.CenterDelay(:,1) + a.startTime;

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% TRIAL CHOICE TYPES (includes NP but not no choice or incorrect)

a.choiceTypeNames = {'InfoForced','RandForced','Choice'};
a.choiceTypeCts = [sum(a.trialType == 2) sum(a.trialType == 3) sum(a.trialType == 1)];
a.infoForced = a.trialType == 2 & a.correct == 1;
a.randForced = a.trialType == 3 & a.correct == 1;
a.infoChoice = a.trialType == 1 & a.correct == 1 & a.info == 1;
a.randChoice = a.trialType == 1 & a.correct == 1 & a.info == 0;

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ALL CORRECT TRIALS (INCLUDES NOT PRESENT)

infoBig = [2,3,11,12];
infoSmall = [4,5,13,14];
randBig = [6,7,17,18];
randSmall = [8,9,19,20];

a.infoBig = ismember(a.outcome,infoBig);
a.infoSmall = ismember(a.outcome,infoSmall);
a.randBig = ismember(a.outcome,randBig);
a.randSmall = ismember(a.outcome,randSmall);;

a.typeNames = {'Info Water','Info None','Rand Water','Rand None'};
a.typeSizes = [sum(a.infoBig) sum(a.infoSmall) sum(a.randBig) sum(a.randSmall)];

a.choiceCorrTrials = a.trialType == 1 & a.correct == 1;
a.forcedCorrTrials = a.trialType ~= 1 & a.correct == 1;
a.infoCorrTrials = a.info == 1 & a.correct == 1;
a.randCorrTrials = a.info == 0 & a.correct == 1;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% ERRORS

a.centerEntryCount = sum(~isnan(a.statesExpanded.CenterOdor),2)/2;
a.completeInitiation = a.centerEntryCount == 1;

% doesn't include NP (NP info small is not an error)
a.infoCorrCodes = [11 13 14];
a.infoIncorrCodes = [10 12 15];
a.randCorrCodes = [17 19];
a.randIncorrCodes = [16 18 20 21];
a.choiceCorrCodes = [2 4 5 6 8];
a.choiceIncorrCodes = [1 3 7 9];    

a.infoForcedCorr = ismember(a.outcome,a.infoCorrCodes);
a.infoForcedIncorr = ismember(a.outcome,a.infoIncorrCodes);
a.randForcedCorr = ismember(a.outcome,a.randCorrCodes);
a.randForcedIncorr = ismember(a.outcome,a.randIncorrCodes);
a.choiceCorr = ismember(a.outcome,a.choiceCorrCodes);
a.choiceIncorr = ismember(a.outcome,a.choiceIncorrCodes);
a.infoChoiceCorr = ismember(a.outcome,[2 4 5]);
a.randChoiceCorr = ismember(a.outcome,[6 7]);

a.choiceCorrTypeNames = {'InfoForced','RandForced','InfoChoice',...
    'RandChoice'};
a.choiceTypeCtsCorr = [sum(a.infoForcedCorr) sum(a.randForcedCorr) sum(a.infoChoiceCorr) sum(a.randChoiceCorr)];

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% NOT PRESENT

a.infoForcedNP = ismember(a.outcome,[12 14]);
a.randForcedNP = ismember(a.outcome,[18 20]);
a.choiceInfoNP = ismember(a.outcome,[3 5]);
a.choiceRandNP = ismember(a.outcome,[7 9]);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% REWARD

dropSize = 4; % microliters per drop

a.infoBigReward = [a.trialSettings.InfoBigDrops]' * 4;
a.infoSmallReward = [a.trialSettings.InfoSmallDrops]' * 4;
a.randBigReward = [a.trialSettings.RandBigDrops]' * 4;
a.randSmallReward = [a.trialSettings.RandSmallDrops]' * 4;

a.leftDrops = a.eventsExpanded.GlobalTimer3_End - a.eventsExpanded.GlobalTimer3_Start;
a.leftRewardDrops = NaN(size(a.leftDrops));
a.leftRewardDrops(a.leftDrops>0.01) = 1;
a.leftReward = sum(a.leftRewardDrops,2)*dropSize;
a.rightDrops = a.eventsExpanded.GlobalTimer4_End - a.eventsExpanded.GlobalTimer4_Start;
a.rightRewardDrops = NaN(size(a.rightDrops));
a.rightRewardDrops(a.rightDrops>0.01) = 1;
a.rightReward = sum(a.rightRewardDrops,2)*dropSize;
a.reward = nansum([a.leftReward, a.rightReward],2);

%% OUTCOMES

a.outcomeLabels = {'ChoiceNoChoice','ChoiceInfoBig','ChoiceInfoBigNP',...
    'ChoiceInfoSmall','ChoiceInfoSmallNP','ChoiceRandBig','ChoiceRandBigNP',...
    'ChoiceRandSmall','ChoiceRandSmallNP','InfoNoChoice','InfoBig',...
    'InfoBigNP','InfoSmall','InfoSmallNP','InfoIncorrect','RandNoChoice',...
    'RandBig','RandBigNP','RandSmall','RandSmallNP',...
    'RandIncorrect'};

for m = 1:a.mouseCt
   ok = strcmp(a.mouse,a.mouseList{m});
   a.mouseOutcomes(m,:) = histcounts(a.outcome(ok),(0.5:1:21.5)); 
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% DAY SUMMARY
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


for m = 1:a.mouseCt
    for d = 1:a.mouseDayCt(m)
        ok = a.mouseDay == d & a.mice(:,m) == 1 & a.correct == 1;
        okAll = a.mouseDay == d & a.mice(:,m) == 1;        
        a.daySummary.outcome{m,d} = a.outcome(okAll ==1);    
        a.daySummary.infoForced{m,d} = sum(a.infoForcedCorr(ok));
        a.daySummary.infoChoice{m,d} = sum(a.infoChoiceCorr(ok));
        a.daySummary.randForced{m,d} = sum(a.randForcedCorr(ok));
        a.daySummary.randChoice{m,d} = sum(a.randChoiceCorr(ok));
        a.daySummary.infoBig{m,d} = sum(a.infoBig(ok));
        a.daySummary.infoSmall{m,d} = sum(a.infoSmall(ok));
        a.daySummary.randBig{m,d} = sum(a.randBig(ok));
        a.daySummary.randSmall{m,d} = sum(a.randSmall(ok));
        
        a.daySummary.trialCt{m,d} = sum(okAll);
        a.daySummary.totalCorrectTrials = sum(a.correct(okAll));
        a.daySummary.totalWater{m,d} = nansum(a.reward(okAll));
        
        a.daySummary.rxnInfoForced{m,d} = nanmean(a.rxn(a.infoForcedCorr & ok));
        a.daySummary.rxnInfoChoice{m,d} = nanmean(a.rxn(a.infoChoiceCorr & ok));
        a.daySummary.rxnRandForced{m,d} = nanmean(a.rxn(a.randForcedCorr & ok));
        a.daySummary.rxnRandChoice{m,d} = nanmean(a.rxn(a.randChoiceCorr & ok));
        
        a.daySummary.trialLengthInfoForced{m,d} = nansum(a.trialLength(a.infoForcedCorr == 1 & ok == 1))/sum(~isnan(a.trialLength(a.infoForcedCorr == 1 & ok == 1)));
        a.daySummary.trialLengthInfoChoice{m,d} = nansum(a.trialLength(a.infoChoiceCorr == 1 & ok == 1))/sum(~isnan(a.trialLength(a.infoChoiceCorr == 1 & ok == 1)));
        a.daySummary.trialLengthRandForced{m,d} = nansum(a.trialLength(a.randForcedCorr == 1 & ok == 1))/sum(~isnan(a.trialLength(a.randForcedCorr == 1 & ok == 1)));
        a.daySummary.trialLengthRandChoice{m,d} = nansum(a.trialLength(a.randChoiceCorr == 1 & ok == 1))/sum(~isnan(a.trialLength(a.randChoiceCorr == 1 & ok == 1)));        
        
        a.daySummary.rewardRateInfoForced{m,d} = sum(a.reward(a.infoForced == 1 & okAll == 1)) / (nansum(a.trialLengthCenterEntry(a.infoForced == 1 & okAll == 1))/60);
        a.daySummary.rewardRateRandForced{m,d} = sum(a.reward(a.randForced == 1 & okAll == 1)) / (nansum(a.trialLengthCenterEntry(a.randForced == 1 & okAll == 1))/60);
        a.daySummary.rewardRateChoice{m,d} = sum(a.reward(a.trialType == 1 & okAll == 1)) / (nansum(a.trialLengthCenterEntry(a.trialType == 1 & okAll == 1))/60);
        a.daySummary.rewardRateInfo{m,d} = sum(a.reward(a.info == 1 & okAll == 1)) / (nansum(a.trialLengthCenterEntry(a.info == 1 & okAll == 1))/60);
        a.daySummary.rewardRateRand{m,d} = sum(a.reward(a.info == 0 & okAll == 1)) / (nansum(a.trialLengthCenterEntry(a.info == 0 & okAll == 1))/60);        

        outcomes = a.outcome(okAll ==1);
        a.daySummary.infoCorr{m,d} = sum(ismember(outcomes,a.infoCorrCodes))/(sum(ismember(outcomes,a.infoCorrCodes))+sum(ismember(outcomes,a.infoIncorrCodes)));
        a.daySummary.infoIncorr{m,d} = sum(ismember(outcomes,a.infoIncorrCodes))/(sum(ismember(outcomes,a.infoCorrCodes))+sum(ismember(outcomes,a.infoIncorrCodes)));
        a.daySummary.randCorr{m,d} = sum(ismember(outcomes,a.randCorrCodes))/(sum(ismember(outcomes,a.randCorrCodes))+sum(ismember(outcomes,a.randIncorrCodes)));
        a.daySummary.randIncorr{m,d} = sum(ismember(outcomes,a.randIncorrCodes))/(sum(ismember(outcomes,a.randCorrCodes))+sum(ismember(outcomes,a.randIncorrCodes)));
        a.daySummary.choiceCorr{m,d} = sum(ismember(outcomes,a.choiceCorrCodes))/(sum(ismember(outcomes,a.choiceCorrCodes))+sum(ismember(outcomes,a.choiceIncorrCodes)));                
        a.daySummary.choiceIncorr{m,d} = sum(ismember(outcomes,a.choiceIncorrCodes))/(sum(ismember(outcomes,a.choiceCorrCodes))+sum(ismember(outcomes,a.choiceIncorrCodes)));        
    
    end
end

%%
save('infoSeekBpodDataAnalyzed.mat','a');
% uisave({'a'},'infoSeekFSMData.mat');

save(['infoSeekFSMBpodDataAnalyzed' datestr(now,'yyyymmdd')],'a');

