%{
----------------------------------------------------------------------------

T

----------------------------------------------------------------------------
%}
function FinalValveTest

global BpodSystem

%% Define parameters

S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.SessionTrials = 1000;
    S.GUI.OdorTime = 4;
    S.GUI.OdorInterval = 10;
    S.GUI.OdorHeadstart = 4;
    S.GUI.Port = 1; %0 = center, 1 = left, 2 = right
    S.GUI.OdorID = 1; % 0 = odor 1
end


%% LOAD SERIAL MESSAGES

% LoadSerialMessages('ValveModule1',{[1,2],[1,3],[1,4],[1,5],[1,6],[1,7],[1,8]});
% LoadSerialMessages('ValveModule2',{[1,2],[1,3],[1,4],[1,5],[1,6],[1,7],[1,8]});
LoadSerialMessages('ValveModule3',{[1,2],[3,4],[5,6]});

ModuleWrite('ValveModule1',[1 2]);
ModuleWrite('ValveModule2',[1 2]);

%% Initialize plots

BpodParameterGUI('init', S); % Initialize parameter GUI plugin

%% MAIN TRIAL LOOP

MaxTrials = S.GUI.SessionTrials;

%% Main loop (runs once per trial)
for currentTrial = 1:MaxTrials
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin

    MaxTrials = S.GUI.SessionTrials;
    odor = S.GUI.OdorID; % logic here to cycle odors
    port = S.GUI.Port;

    %--- Assemble state machine
    sma = NewStateMachine();    
    sma = AddState(sma, 'Name', 'OdorOn', ...
        'Timer', S.GUI.OdorTime,...
        'StateChangeConditions', {'Tup', 'OdorOff'},...
        'OutputActions', PresentOdor(port));
    sma = AddState(sma, 'Name', 'OdorOff', ...
        'Timer', S.GUI.OdorInterval,...
        'StateChangeConditions', {'Tup', '>exit'},...
        'OutputActions', PresentOdor(port));

%     sma = AddState(sma, 'Name', 'OdorOn', ...
%         'Timer', S.GUI.OdorTime,...
%         'StateChangeConditions', {'Tup', 'OdorOff'},...
%         'OutputActions', OdorTest(1));%{'ValveModule2',1,'ValveModule1',1,'ValveModule1',2,'ValveModule2',2}
%     sma = AddState(sma, 'Name', 'OdorOff', ...
%         'Timer', S.GUI.OdorInterval,...
%         'StateChangeConditions', {'Tup', '>exit'},...
%         'OutputActions', OdorTest(1));     

    SendStateMatrix(sma); % Send state machine to the Bpod state machine device
    RawEvents = RunStateMatrix; % Run the trial and return events

    %--- Package and save the trial's data, update plots
    if ~isempty(fieldnames(RawEvents)) % If you didn't stop the session manually mid-trial
        TurnOffAllOdors();
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Adds raw events to a human-readable data struct
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file

        %--- Typically a block of code here will update online plots using the newly updated BpodSystem.Data

    end

    %--- This final block of code is necessary for the Bpod console's pause and stop buttons to work
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0
        TurnOffAllOdors();
        return
    end
end
end


%% ODOR CONTROL

% to preload, turn off control and turn on other odor (still going to
% exhaust)
% function actions = OdorTest(odor)
%     actions = {'ValveModule1',odor};
% end

% function actions = OdorTest(odor)
%     cmd1 = {'ValveModule1',odor};
%     cmd2 = {'ValveModule2',odor};
%     actions = [cmd1,cmd2];
% end

function Actions = PreloadOdor(odorID)
    cmd1 = {'ValveModule1',odorID};
    cmd2 = {'ValveModule2',odorID}; 
    Actions = [cmd1,cmd2];
end

function Actions = PresentOdor(port)
    switch port
        case 0 % center
            Actions = {'ValveModule3',2};
        case 1 % left
            Actions = {'ValveModule3',1};
        case 2 % right
            Actions = {'ValveModule3',3};
    end
end

function TurnOffAllOdors()
    for v = 1:8
        ModuleWrite('ValveModule1',['C' v]);
        ModuleWrite('ValveModule2',['C' v]);
        ModuleWrite('ValveModule3',['C' v]);
    end 
end
