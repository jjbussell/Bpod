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