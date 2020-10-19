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

%% INFOSIDE

a.infoSide = [a.trialSettings.InfoSide]';

%% DAY AND MOUSE
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

a.left 

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