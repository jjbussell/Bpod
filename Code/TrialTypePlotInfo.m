%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2017 Sanworks LLC, Stony Brook, New York, USA

----------------------------------------------------------------------------

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed  WITHOUT ANY WARRANTY and without even the
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
%}
% function OutcomePlot(AxesHandle,TrialTypeSides, OutcomeRecord, CurrentTrial)
function TrialTypePlot(AxesHandle, Action, varargin)
%% 
% Plug in to Plot trial type and trial outcome.
% AxesHandle = handle of axes to plot on
% Action = specific action for plot, "init" - initialize OR "update" -  update plot

%Example usage:
% TrialTypePlot(AxesHandle,'init',TrialTypes)
% TrialTypePlot(AxesHandle,'init',TrialTypes,'ntrials',90)
% TrialTypePlot(AxesHandle,'update',CurrentTrial,TrialTypes,OutcomeRecord)

% varargins:
% TrialTypes: Vector of trial types (integers)
% OutcomeRecord:  Vector of trial outcomes
%                 Simplest case: 
%                               1: correct trial (green)
%                               0: incorrect trial (red)
%                 Advanced case: 
%                               NaN: future trial (blue)
%                                -1: withdrawal (red circle)
%                                 0: incorrect choice (red dot)
%                                 1: correct choice (green dot)
%                                 2: did not choose (green circle)

%                 Info: 
%                               NaN: future trial (blue)
%                                -1: Not Present (black circle)
%                                 0: correct choice rand (orange dot)
%                                 1: correct choice info (purple dot)
%                                 2: did not choose (blue X)
%                                 3: incorrect choice (red X)
% OutcomeRecord can also be empty
% Current trial: the current trial number

% Adapted from BControl (SidesPlotSection.m) 
% Kachi O. 2014.Mar.17
% J. Sanders. 2015.Jun.6 - adapted to display trial types instead of sides

%% Code Starts Here
global nTrialsToShow %this is for convenience
global BpodSystem

switch Action
    case 'init'
        %initialize pokes plot
        TrialTypeList = varargin{1};
        nTrialsToShow = 40; %default number of trials to display
        if nargin > 3 %custom number of trials
            nTrialsToShow = varargin{2};
        end
        yticklabelsinfo = {'RandForced','InfoForced','Choice'};
        labelFontSize = 16;
        axes(AxesHandle);
        MaxTrialType = numel(yticklabelsinfo);
        %plot in specified axes
        Xdata = 1:nTrialsToShow;
        if ~isrow(TrialTypeList)
            Ydata = -TrialTypeList(Xdata)';
        else
            Ydata = -TrialTypeList(Xdata);
        end
        BpodSystem.GUIHandles.FutureTrialLine = line([Xdata,Xdata],[Ydata,Ydata],'LineStyle','none','Marker','o','MarkerEdge','b','MarkerFace','b', 'MarkerSize',6);
        BpodSystem.GUIHandles.CurrentTrialCircle = line([0,0],[0,0], 'LineStyle','none','Marker','o','MarkerEdge','k','MarkerFace',[1 1 1], 'MarkerSize',6);
        BpodSystem.GUIHandles.CurrentTrialCross = line([0,0],[0,0], 'LineStyle','none','Marker','+','MarkerEdge','k','MarkerFace',[1 1 1], 'MarkerSize',6);
        BpodSystem.GUIHandles.IncorrectLine = line([0,0],[0,0], 'LineStyle','none','Marker','x','MarkerEdge','r','MarkerFace','r', 'MarkerSize',6);
        BpodSystem.GUIHandles.InfoCorrectLine = line([0,0],[0,0], 'LineStyle','none','Marker','o','MarkerEdge',[128	0 128]./255,'MarkerFace',[128	0 128]./255, 'MarkerSize',6);
        BpodSystem.GUIHandles.RandCorrectLine = line([0,0],[0,0], 'LineStyle','none','Marker','o','MarkerEdge',[255 140 0]./255,'MarkerFace',[255 140 0]./255, 'MarkerSize',6);
        BpodSystem.GUIHandles.NotPresentLine = line([0,0],[0,0], 'LineStyle','none','Marker','o','MarkerEdge','k','MarkerFace',[1 1 1], 'MarkerSize',6);
        BpodSystem.GUIHandles.NoChoiceLine = line([0,0],[0,0], 'LineStyle','none','Marker','x','MarkerEdge','b','MarkerFace','b', 'MarkerSize',6);
        BpodSystem.GUIHandles.TTOP_Ylabel = strsplit(num2str(MaxTrialType:-1:-1));        
        if numel(unique(TrialTypeList)) == 3
            set(AxesHandle,'TickDir', 'out','YLim', [-MaxTrialType-.5, -.5], 'YTick', -MaxTrialType:1:-1, 'YTickLabel', yticklabelsinfo, 'FontSize', 16);
        else
            set(AxesHandle,'TickDir', 'out','YLim', [-MaxTrialType-.5, -.5], 'YTick', -MaxTrialType:1:-1,'YTickLabel', BpodSystem.GUIHandles.TTOP_Ylabel, 'FontSize', 16);
        end
        set(AxesHandle,'TickDir', 'out','YLim', [-MaxTrialType-.5, -.5], 'YTick', -MaxTrialType:1:-1,'FontSize', 16);
        xlabel(AxesHandle, 'Trial#', 'FontSize', labelFontSize);
        ylabel(AxesHandle, 'Trial Type', 'FontSize', 16);

        hold(AxesHandle, 'on');
        
    case 'update'
        CurrentTrial = varargin{1};
        TrialTypeList = varargin{2};
        if ~isrow(TrialTypeList)
            TrialTypeList = TrialTypeList';
        end
        if nargin>4
            OutcomeRecord = varargin{3};
        else
            OutcomeRecord = BpodSystem.Data.PlotOutcomes;
        end
        MaxTrialType = 3;
        yticklabelsinfo = {'RandForced','InfoForced','Choice'};
        if numel(unique(TrialTypeList)) == 3
            set(AxesHandle,'YLim',[-MaxTrialType-.5, -.5], 'YTick', -MaxTrialType:1:-1,'YTickLabel', yticklabelsinfo);
        else
            set(AxesHandle,'YLim',[-MaxTrialType-.5, -.5], 'YTick', -MaxTrialType:1:-1,'YTickLabel', BpodSystem.GUIHandles.TTOP_Ylabel);
        end
        if CurrentTrial<1
            CurrentTrial = 1;
        end
        TrialTypeList  = -TrialTypeList;
        
        % recompute xlim
        [mn, mx] = rescaleX(AxesHandle,CurrentTrial,nTrialsToShow);
        
        %plot future trials
        offset = mn-1;
        FutureTrialsIndx = CurrentTrial+1:mx;
        Xdata = FutureTrialsIndx; Ydata = TrialTypeList(Xdata);
        DisplayXdata = Xdata-offset;
        set(BpodSystem.GUIHandles.FutureTrialLine, 'xdata', [DisplayXdata,DisplayXdata], 'ydata', [Ydata,Ydata]);
        %Plot current trial
        displayCurrentTrial = CurrentTrial-offset+1;
        set(BpodSystem.GUIHandles.CurrentTrialCircle, 'xdata', [displayCurrentTrial,displayCurrentTrial], 'ydata', [TrialTypeList(CurrentTrial+1),TrialTypeList(CurrentTrial+1)]);
        set(BpodSystem.GUIHandles.CurrentTrialCross, 'xdata', [displayCurrentTrial,displayCurrentTrial], 'ydata', [TrialTypeList(CurrentTrial+1),TrialTypeList(CurrentTrial+1)]);
        
        %Plot past trials
        if ~isempty(OutcomeRecord)
            indxToPlot = mn:CurrentTrial;
            %Plot Error, unpunished NOT PRESENT
            EarlyWithdrawalTrialsIndx =(OutcomeRecord(indxToPlot) == -1);
            Xdata = indxToPlot(EarlyWithdrawalTrialsIndx); Ydata = TrialTypeList(Xdata);
            DispData = Xdata-offset;
            set(BpodSystem.GUIHandles.NotPresentLine, 'xdata', [DispData,DispData], 'ydata', [Ydata,Ydata]);
            %Plot Error, punished INCORRECT
            InCorrectTrialsIndx = (OutcomeRecord(indxToPlot) == 3);
            Xdata = indxToPlot(InCorrectTrialsIndx); Ydata = TrialTypeList(Xdata);
            DispData = Xdata-offset;
            set(BpodSystem.GUIHandles.IncorrectLine, 'xdata', [DispData,DispData], 'ydata', [Ydata,Ydata]);
            %Plot Correct, INFO
            CorrectTrialsIndx = (OutcomeRecord(indxToPlot) == 1);
            Xdata = indxToPlot(CorrectTrialsIndx); Ydata = TrialTypeList(Xdata);
            DispData = Xdata-offset;
            set(BpodSystem.GUIHandles.InfoCorrectLine, 'xdata', [DispData,DispData], 'ydata', [Ydata,Ydata]);
            %Plot Correct, NO INFO
            UnrewardedTrialsIndx = (OutcomeRecord(indxToPlot) == 0);
            Xdata = indxToPlot(UnrewardedTrialsIndx); Ydata = TrialTypeList(Xdata);
            DispData = Xdata-offset;
            set(BpodSystem.GUIHandles.RandCorrectLine, 'xdata', [DispData,DispData], 'ydata', [Ydata,Ydata]);
            %Plot DidNotChoose
            DidNotChooseTrialsIndx = (OutcomeRecord(indxToPlot) == 2);
            Xdata = indxToPlot(DidNotChooseTrialsIndx); Ydata = TrialTypeList(Xdata);
            DispData = Xdata-offset;
            set(BpodSystem.GUIHandles.NoChoiceLine, 'xdata', [DispData,DispData], 'ydata', [Ydata,Ydata]);
        end
end

end

function [mn,mx] = rescaleX(AxesHandle,CurrentTrial,nTrialsToShow)
FractionWindowStickpoint = .5; % After this fraction of visible trials, the trial position in the window "sticks" and the window begins to slide through trials.
mn = max(round(CurrentTrial - FractionWindowStickpoint*nTrialsToShow),1);
mx = mn + nTrialsToShow - 1;
tickLabels = sprintfc('%d',(mn-1:10:mx));
set(AxesHandle, 'Xtick', 0:10:nTrialsToShow, 'XtickLabel', tickLabels);
%set(AxesHandle,'XLim',[mn-1 mx+1]); Replaced this with a trimmed "display" copy of the data 
                                    % and an xticklabel update for speed - JS 2018
end
