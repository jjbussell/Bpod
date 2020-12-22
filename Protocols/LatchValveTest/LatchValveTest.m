%{
----------------------------------------------------------------------------

T

----------------------------------------------------------------------------
%}
function LatchValveTest

global BpodSystem

%% Define parameters

S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.SessionTrials = 1000;
    S.GUI.Odor = 2;
end

%% Initialize plots

BpodParameterGUI('init', S); % Initialize parameter GUI plugin

%% MAIN TRIAL LOOP

MaxTrials = S.GUI.SessionTrials;

%% SET ODOR SIDES (LATCH VALVES)

modules = BpodSystem.Modules.Name;
latchValves = [16 15 14 11 10 9 8 7]; % evens to left
% latchValves = [3 5 7 9 4 6 8 10]; % 1:4 go to left, 5:8 go to right!
latchModule = [modules(strncmp('DIO',modules,3))];
latchModule = latchModule{1};


%% Main loop (runs once per trial)
for currentTrial = 1:MaxTrials
   S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
   
   MaxTrials = S.GUI.SessionTrials;
    odor = S.GUI.Odor; % logic here to cycle odors
    latchPins = [latchValves(odor*2+1) latchValves(odor*2+2)];
   
   LoadSerialMessages(latchModule,{[latchPins(1) 1],[latchPins(1) 0],...
       [latchPins(2) 1],[latchPins(2) 0]});
   
    sma = NewStateMachine();
    sma = AddState(sma, 'Name', 'PowerOnLeft', ...
        'Timer', 0.020,...
        'StateChangeConditions', {'Tup', 'PowerOffLeft'},...
        'OutputActions', {latchModule,1});
    sma = AddState(sma, 'Name', 'PowerOffLeft', ...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'Wait1'},...
        'OutputActions', {latchModule,2});
    sma = AddState(sma, 'Name', 'Wait1',...
        'Timer', 0.200,...
        'StateChangeConditions', {'Tup', 'PowerOnRight'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'PowerOnRight', ...
        'Timer', 0.020,...
        'StateChangeConditions', {'Tup', 'PowerOffRight'},...
        'OutputActions', {latchModule,3});
    sma = AddState(sma, 'Name', 'PowerOffRight', ...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'Wait2'},...
        'OutputActions', {latchModule,4});
    sma = AddState(sma, 'Name', 'Wait2',...
        'Timer', 0.200,...
        'StateChangeConditions', {'Tup', '>exit'},...
        'OutputActions', {});    
    
    SendStateMatrix(sma); % Send state machine to the Bpod state machine device
    RawEvents = RunStateMatrix; % Run the trial and return events
    
    %--- Package and save the trial's data, update plots
    if ~isempty(fieldnames(RawEvents)) % If you didn't stop the session manually mid-trial
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Adds raw events to a human-readable data struct
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
        
        %--- Typically a block of code here will update online plots using the newly updated BpodSystem.Data
        
    end
    
    %--- This final block of code is necessary for the Bpod console's pause and stop buttons to work
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0
        return
    end
end
end

