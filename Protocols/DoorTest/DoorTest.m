%{
----------------------------------------------------------------------------

T

----------------------------------------------------------------------------
%}
function DoorTest

global BpodSystem

%% Define parameters

S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.SessionTrials = 1000;
    S.GUI.Delay1 = 2;
    S.GUI.Delay2 = 2;
end


%% LOAD SERIAL MESSAGES

LoadSerialMessages('ValveModule1',{[1,2],[1,3],[1,4],[1,5],[1,6],[1,7],[1,8]}); % switch control and odor 1-7, valves before
LoadSerialMessages('ValveModule2',{[1,2],[1,3],[1,4],[1,5],[1,6],[1,7],[1,8]}); % switch control and odor 1-7, valves after
LoadSerialMessages('ValveModule3',{[1,2],[3,4],[5,6]}); % final valves switch control and odor, left, center, right
LoadSerialMessages('ValveModule4',{[1,2],[3,2]}); % turn on right, turn on left

buzzer1 = [254 1];
buzzer2 = [253 1];
openDoor = [252 1];
closeDoor = [251 1];
LoadSerialMessages('Infoseek1', {buzzer1, buzzer2,...
    openDoor,closeDoor});
%% Initialize plots

BpodParameterGUI('init', S); % Initialize parameter GUI plugin

%% MAIN TRIAL LOOP

MaxTrials = S.GUI.SessionTrials;

%% Main loop (runs once per trial)
for currentTrial = 1:MaxTrials
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin

    MaxTrials = S.GUI.SessionTrials;

    %--- Assemble state machine
    sma = NewStateMachine();
    sma = AddState(sma, 'Name', 'HoldOpen', ...
        'Timer', S.GUI.Delay2,...
        'StateChangeConditions', {'Tup', 'CloseDoor'},...
        'OutputActions', {});     
    sma = AddState(sma, 'Name', 'CloseDoor', ...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'HoldClosed'},...
        'OutputActions', {'Infoseek1',4});    
    sma = AddState(sma, 'Name', 'HoldClosed', ...
        'Timer', S.GUI.Delay1,...
        'StateChangeConditions', {'Tup', 'OpenDoor'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'OpenDoor', ...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', '>exit'},...
        'OutputActions', {'Infoseek1',3});

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