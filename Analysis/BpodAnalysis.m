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

%% INFOSIDE

a.infoSide = [a.trialSettings.InfoSide]';

%% DAY AND MOUSE
a.day2 = reshape([a.day{:}],[8],[])';
datevec=[a.files(:).date];
a.fileDay=cellstr(reshape(datevec,[8],[23])');
% days=unique(a.filedays);
mousevec=[a.files(:).mouse];
a.fileMouse=cellstr(reshape(mousevec,[],[23])');

% find(ismember(days,a.filedays))

a.mouseList = unique(a.mouse);
a.mouseCt = numel(a.mouseList);

for m = 1:a.mouseCt
   mouseFileIdx = strcmp(a.fileMouse,a.mouseList{m});
   a.mouseDays{m} = unique(a.fileDay(mouseFileIdx)); % sorts
   a.mouseDayCt(m) = size(a.mouseDays{m},1);
   mouseFirstDay = find(strcmp(a.mouse,a.mouseList{m})& strcmp(a.day,a.mouseDays{m}(1)),1);
   a.initInfoSide(m) = a.infoSide(mouseFirstDay);
end

%% CORRECT, CHOICE, TRIAL TYPE, WATER

% infoSide = 0, info left

% choice is waitforodorleft,waitforodorright,incorrect,nochoice

a.trialCt = numel(a.trialType);

a.choice = NaN(a.trialCt,1);

a.leftChoice = a.statesExpanded.WaitForOdorLeft(:,1);
a.rightChoice = a.statesExpanded.WaitForOdorRight(:,1);
a.incorrectChoice = a.statesExpanded.Incorrect(:,1);
a.noChoice = a.statesExpanded.NoChoice(:,1);

a.choice(~isnan(a.leftChoice)) = a.leftChoice(~isnan(a.leftChoice));
a.choice(~isnan(a.rightChoice)) = a.rightChoice(~isnan(a.rightChoice));
a.choice(~isnan(a.incorrectChoice)) = a.incorrectChoice(~isnan(a.incorrectChoice));
a.choice(~isnan(a.noChoice)) = a.noChoice(~isnan(a.noChoice));

a.rxn = a.choice-a.statesExpanded.GoCue(:,1);

a.trialLength = a.endTime - a.startTime;
a.trialLengthGoCue = a.endTime - a.statesExpanded.GoCue(:,1);

%% REWARD

dropSize = 4; % microliters per drop

infoBigReward = [a.trialSettings.InfoBigDrops]' * 4;
infoSmallReward = [a.trialSettings.InfoSmallDrops]' * 4;
randBigReward = [a.trialSettings.RandBigDrops]' * 4;
randSmallReward = [a.trialSettings.RandSmallDrops]' * 4;

%% MOUSE DAY SUMMARIES

a.outcomeLabels = {'ChoiceNoChoice','ChoiceInfoBig','ChoiceInfoBigNP',...
    'ChoiceInfoSmall','ChoiceInfoSmallNP','ChoiceRandBig','ChoiceRandBigNP',...
    'ChoiceRandSmall','ChoiceRandSmallNP','InfoNoChoice','InfoBig',...
    'InfoBigNP','InfoSmall','InfoSmallNP','InfoIncorrect','RandNoChoice',...
    'RandBig','RandBigNP','RandSmall','RandSmallNP',...
    'RandIncorrect'};

for m = 1:a.mouseCt
    ok = strcmp(a.mouse,a.mouseList{m});
   outcomes(m,:) = histcounts(a.outcome(ok),(0.5:1:21.5)); 
end