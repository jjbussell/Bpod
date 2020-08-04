%{
----------------------------------------------------------------------------

T

----------------------------------------------------------------------------
%}
function OdorTest

global BpodSystem

%% Define parameters

S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.SessionTrials = 1000;
    S.GUI.OdorTime = 3;
    S.GUI.OdorInterval = 4;
    S.GUI.Port = 0; %0 = center, 1 = left, 2 = right
    S.GUI.OdorID = 0;
end

%% Initialize plots

BpodParameterGUI('init', S); % Initialize parameter GUI plugin

%% MAIN TRIAL LOOP

MaxTrials = S.GUI.SessionTrials;

%% SET ODOR SIDES (LATCH VALVES)

port = S.GUI.Port;

modules = BpodSystem.Modules.Name;
latchValves = [3 5 7 9 4 6 8 10]; % 1:4 go to left, 5:8 go to right!
latchModule = [modules(strncmp('DIO',modules,3))];
latchModule = latchModule{1};

if port == 1 % SEND INFO ODORS TO LEFT (A,B)
    for i = 1:4
        ModuleWrite(latchModule,[latchValves(i) 1]);
        pause(100/1000);
        ModuleWrite(latchModule,[latchValves(i) 0]);
        pause(100/1000);
    end
else
    for i = 5:8
        ModuleWrite(latchModule,[latchValves(i) 1]);
        pause(100/1000);
        ModuleWrite(latchModule,[latchValves(i) 0]);
        pause(100/1000);
    end
end

%% Main loop (runs once per trial)
for currentTrial = 1:MaxTrials
   S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
   
   MaxTrials = S.GUI.SessionTrials;
   odor = S.GUI.OdorID; % logic here to cycle odors
   newPort = S.GUI.Port;
   port = newPort; % change here to switch sides
   
   % SETUP ODORS
   
    %--- Assemble state machine
    sma = NewStateMachine();
    sma = AddState(sma, 'Name', 'OdorOn', ...
        'Timer', S.GUI.OdorTime,...
        'StateChangeConditions', {'Tup', 'OdorOff'},...
        'OutputActions', [{'PWM2',255}, odorSwitch(port,odor)]);
    sma = AddState(sma, 'Name', 'OdorOff', ...
        'Timer', S.GUI.OdorInterval,...
        'StateChangeConditions', {'Tup', '>exit'},...
        'OutputActions', odorSwitch(port,odor));  
    
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

%% ODOR CONTROL

function OdorActions = odorSwitch(portID,odorID)
    switch portID
        case 0
            cmd1 = {'ValveModule3',1}; % before center control
            cmd2 = {'ValveModule3',2}; % after center control
            switch odorID
                case 0
                    cmd3 = {'ValveModule1',1}; % before center odor
                    cmd4 = {'ValveModule2',1}; % after center odor                    
                case 1
                    cmd3 = {'ValveModule1',1}; % before center odor
                    cmd4 = {'ValveModule2',1}; % after center odor                     
                case 2
                    cmd3 = {'ValveModule1',1}; % before center odor
                    cmd4 = {'ValveModule2',1}; % after center odor                     
                case 3
                    cmd3 = {'ValveModule1',1}; % before center odor
                    cmd4 = {'ValveModule2',1}; % after center odor                    
            end
        case 1
            cmd1 = {'ValveModule3',3}; % before left control
            cmd2 = {'ValveModule3',4}; % after left control            
        case 2
            cmd1 = {'ValveModule3',5}; % before right control
            cmd2 = {'ValveModule3',6}; % after right control              
    end
    
    OdorActions = [cmd1, cmd2, cmd3, cmd4];
end

%% CONTROLS

function OdorOutputActions = turnOnOdor(odorID)
    switch odorID
        case 0
            cmd1 = {'ValveModule3',1}; % before center control
            cmd2 = {'ValveModule3',2}; % after center control  
        case 1
            cmd1 = {'ValveModule3',3}; % before left control
            cmd2 = {'ValveModule3',4}; % after left control              
        case 2
            cmd1 = {'ValveModule3',5}; % before right control
            cmd2 = {'ValveModule3',6}; % after right control  
    end
    OdorOutputActions = [cmd1, cmd2];
end

%% CENTER ODOR

function CenterOdorOutputActions = turnOnCenterOdor(odorID)
    switch odorID
        case 0
            cmd1 = {'ValveModule1',1}; % before center odor
            cmd2 = {'ValveModule1',2}; % after center odor
            cmd3 = {'ValveModule3',3}; % before center control
            cmd4 = {'ValveModule1',4}; % after center control
        case 1
            cmd1 = {'ValveModule1',1}; % before center odor
            cmd2 = {'ValveModule1',2}; % after center odor
            cmd3 = {'ValveModule3',3}; % before center control
            cmd4 = {'ValveModule3',4}; % after center control
        case 2
            cmd1 = {'ValveModule1',1}; % before center odor
            cmd2 = {'ValveModule1',2}; % after center odor
            cmd3 = {'ValveModule3',3}; % before center control
            cmd4 = {'ValveModule3',4}; % after center control                        
        case 3
            cmd1 = {'ValveModule1',1}; % before center odor
            cmd2 = {'ValveModule1',2}; % after center odor
            cmd3 = {'ValveModule3',3}; % before center control
            cmd4 = {'ValveModule3',4}; % after center control            
    end
    CenterOdorOutputActions = [cmd1, cmd2, cmd3, cmd4];
    % string({'John ','Mary '});
end

%% SIDE ODOR

function SideOdorOutputActions = turnOnSideOdor(odorID, side)
    
    if strcmp('left',side)
        controlBefore = 1;
        controlAfter = 2;
    else
        controlBefore = 3;
        controlAfter = 4; 
    end

    switch odorID
        case 0
            cmd1 = {'ValveModule1',1}; % before odor
            cmd2 = {'ValveModule1',2}; % after odor
            cmd3 = {'ValveModule1',controlBefore}; % before control
            cmd4 = {'ValveModule1',controlAfter}; % after control
        case 1
            cmd1 = {'ValveModule1',1}; % before odor
            cmd2 = {'ValveModule1',2}; % after odor
            cmd3 = {'ValveModule1',controlBefore}; % before control
            cmd4 = {'ValveModule1',controlAfter}; % after control
        case 2
            cmd1 = {'ValveModule1',1}; % before odor
            cmd2 = {'ValveModule1',2}; % after odor
            cmd3 = {'ValveModule1',controlBefore}; % before control
            cmd4 = {'ValveModule1',controlAfter}; % after control                        
        case 3
            cmd1 = {'ValveModule1',1}; % before odor
            cmd2 = {'ValveModule1',2}; % after odor
            cmd3 = {'ValveModule1',controlBefore}; % before control
            cmd4 = {'ValveModule1',controlAfter}; % after control
        case 5
            cmd1 = [];
            cmd2 = [];
            cmd3 = [];
            cmd4 = [];
    end
    SideOdorOutputActions = [cmd1, cmd2, cmd3, cmd4];
end