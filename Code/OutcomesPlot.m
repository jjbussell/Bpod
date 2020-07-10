a.finalOutcomeLabels = {'ChoiceNoChoice','ChoiceInfoBig','ChoiceInfoBigNP',...
'ChoiceInfoSmall','ChoiceInfoSmallNP','ChoiceRandBig','ChoiceRandBigNP',...
'ChoiceRandSmall','ChoiceRandSmallNP','InfoNoChoice','InfoBig',...
'InfoBigNP','InfoSmall','InfoSmallNP','InfoIncorrect','RandNoChoice',...
'RandBig','RandBigNP','RandSmall','RandSmallNP',...
'RandIncorrect'};

CCfinal = [0.2,0.2,0.2; %choice no choice
0.474509803921569,0.125490196078431,0.768627450980392; %choice info big
171/255,130/255,1; % choice info big NP
0.9490, 0.8, 1.0; %choiceinfosmall
238/255,224/255,229/255; %choiceinfoNPsmall
0.984313725490196,0.545098039215686,0.0235294117647059; %choice rand big
245/255,222/255,179/255; % choice rand big NP
1, 0.8, 0.0; %choice rand small
244/255, 164/255, 96/255; %choice rand small NP
0.6,0.6,0.6; %info no choice
0,1,0; %info big
152/255,251/255,152/255;% info big NP
1,0,1; %infosmall
1,192/255,203/255; %info small not present
0.0,0.0,0.0; %infoincorrect
0.2,0.2,0.2;% rand no choice
0,0,1; %rand big
135/255,206/255,1; % rand big NP
0,1,1; %rand small
187/255,1,1; %rand small NP
0.0,0.0,0.0]; %rand incorrect

outcomes = SessionData.Outcomes;
[outcomeCountsNorm,outcomeBins] = histcounts(outcomes,[0.5:1:21.5],'Normalization','probability');
[outcomeCounts,outcomeBins] = histcounts(outcomes,[0.5:1:21.5]);
outcomesToPlot = [outcomeCountsNorm; outcomeCountsNorm];

%%
figure();
fig = gcf;
fig.PaperUnits = 'inches';
fig.PaperPosition = [1 1 10 8];
set(fig,'renderer','painters')
set(fig,'PaperOrientation','landscape');

ax = nsubplot(1,1,1,1);
ax.FontSize = 10;
ylabel('Trial Outcomes (% of trials)');
ax.YLim = [0 1];
ax.YTick = [0:0.25:1];
ax.XLim = [0 1.5];
colormap(fig,CCfinal);
bar(outcomesToPlot,'stacked');
set(gca, 'ydir', 'reverse');
lgd = legend(ax,a.finalOutcomeLabels,'Location','eastoutside');
lgd.Box = 'off';
lgd.FontWeight = 'bold';

%%
figure();
fig = gcf;
fig.PaperUnits = 'inches';
fig.PaperPosition = [1 1 10 8];
set(fig,'renderer','painters')
set(fig,'PaperOrientation','landscape');

ax = nsubplot(1,1,1,1);
ax.FontSize = 10;
title('Trial Outcomes');
ylabel('# of trials');
% ax.YLim = [0 1];
% ax.YTick = [0:0.25:1];
% ax.XLim = [0 1.5];
colormap(fig,CCfinal);
for i = 1:numel(outcomeCounts)
    bar(i,outcomeCounts(i),'FaceColor',CCfinal(i,:));
end
lgd = legend(ax,a.finalOutcomeLabels,'Location','eastoutside');
lgd.Box = 'off';
lgd.FontWeight = 'bold';

