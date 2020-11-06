%{
----------------------------------------------------------------------------

This code runs a 2AFC Information Seeking assay. The mouuse initiatess a
trial by poking the center port to receive an odor directing to right or
left port or free choice between the two. The mouse chooses side port by
poking there and there receives either informative or un-
informative odor, then after a delay, reward outcome at the same side port.

The mouse only receives water if he is present in the corret chosen port
at the outcome tiime.
----------------------------------------------------------------------------

Three valve control modules control airflow in the custom dilution
olfactometer.

One Teensy 3.2 connected as a module with the Bpod Teensy Shield controls
a buzzer and lick sensor.

%}
function Association

global BpodSystem

%% Create trial manager object
TrialManager = TrialManagerObject;

%% Define parameters

S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.RewardProb = 1;
    S.GUI.PreOdorDelay = 0.2;
    S.GUI.CSPlusOdor = 2;
    S.GUI.CSMinusOdor = 1;
    S.GUI.CenterDelay = 1;
    S.GUI.OdorTime = 0.25;
    S.GUI.RewardDelay = 1;
    S.GUI.RewardDrops = 1;
    S.GUI.Timeout = 0;
    S.GUI.Interval = 1; 
    
    BpodSystem.ProtocolSettings = S;
    SaveProtocolSettings(BpodSystem.ProtocolSettings); % if no loaded settings, save defaults as a settings file   
end

%% Define trial types
MaxTrials = 1000;
% TrialTypes = ceil(rand(1,MaxTrials)*2);
TrialTypes = SetTrialTypes(S);
BpodSystem.Data.TrialTypes = [];

%% Initialize plots

EventsPlot('init', getStateColors); % events within trial
BpodNotebook('init');
InfoParameterGUI('init', S); % Initialize parameter GUI plugin
TotalRewardDisplay('init');

%% INITIALIZE SERIAL MESSAGES

buzzer1 = [254 1];
buzzer2 = [253 1];
doorOpen = [251 10];
doorClose = [252 100];

LoadSerialMessages('Infoseek1', {buzzer1, buzzer2, doorOpen, doorClose, ...
    [7 1],[7,0],[8 1],[8 0],[9 1],[9 0],[10 1],[10 0],[11 1],[11 0],[12 1],[12 0],...
    [13 1], [13 0]});

%%    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ODOR CONTROL SERIAL MESSAGES
LoadSerialMessages('ValveModule1',{[1,2],[1,3],[1,4],[1,5],[1,6],[1,7],[1,8]}); % switch control and odor 1-7, valves before
LoadSerialMessages('ValveModule2',{[1,2],[1,3],[1,4],[1,5],[1,6],[1,7],[1,8]}); % switch control and odor 1-7, valves after
LoadSerialMessages('ValveModule3',{[1,2],[3,4],[5,6]}); % final valves switch control and odor, left, center, right
LoadSerialMessages('ValveModule4',{[1,2],[3,2]}); % turn on right, turn on left


%% INITIALIZE STATE MACHINE

sma = PrepareStateMachine(S, TrialTypes, 1, []); % Prepare state machine for trial 1 with empty "current events" variable

TrialManager.startTrial(sma); % Sends & starts running first trial's state machine. A MATLAB timer object updates the 
                              % console UI, while code below proceeds in parallel.

%% MAIN TRIAL LOOP

for currentTrial = 1:MaxTrials
    currentTrialEvents = TrialManager.getCurrentEvents({'PortCheck'}); % Hangs here until Bpod enters one of the listed trigger states, then returns current trial's states visited + events captured to this point                       
    if BpodSystem.Status.BeingUsed == 0;        
        TurnOffAllOdors();      
        return; end % If user hit console "stop" button, end session
    sma = PrepareStateMachine(S, TrialTypes, currentTrial+1, currentTrialEvents); % Prepare next state machine.
    SendStateMachine(sma, 'RunASAP'); % send the next trial's state machine while the current trial is ongoing
    RawEvents = TrialManager.getTrialData; % Hangs here until trial is over, then retrieves full trial's raw data
    if BpodSystem.Status.BeingUsed == 0;        
        TurnOffAllOdors();
        return; end % If user hit console "stop" button, end session 
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    TrialManager.startTrial(); % Start processing the next trial's events
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned from last trial, update plots and save data
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial);
        BpodSystem.Data = BpodNotebook('sync', BpodSystem.Data); % Sync with Bpod notebook plugin
%         BpodSystem.Data.raw = RawEvents;
        if sum(RawEvents.States==11)>0
            rewardAmount = S.GUI.RewardDrops*4;
        else
            rewardAmount = 0;
        end
        TotalRewardDisplay('add',rewardAmount);
        EventsPlot('update');
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file --> POSSIBLY MOVE THIS TO SAVE TIME??
    end
end

end % end of protocol main function


%% PREPARE STATE MACHINE

function sma = PrepareStateMachine(S, TrialTypes, nextTrial, currentTrialEvents)

global BpodSystem;

nextTrialType = TrialTypes(nextTrial);

% Determine trial-specific state matrix fields
% Set trialParams (reward and odor)
switch nextTrialType
    case 1 % WATER
        Odor = S.GUI.CSPlusOdor;
        OdorState = 'OdorCSPlus';
        DIOmsg1 = 5; DIOmsg2 = 6;
        RewardDrops = S.GUI.RewardDrops;
        NotPresentState = 'NotPresentReward';
        OutcomeState = 'OutcomeReward';
    case 0 % NO WATER
        Odor = S.GUI.CSMinusOdor;
        OdorState = 'OdorCSMinus';
        DIOmsg1 = 7; DIOmsg2 = 8;
        RewardDrops = 0;
        NotPresentState = 'NotPresentNoReward';
        OutcomeState = 'OutcomeNoReward';
end

% Water parameters
R = GetValveTimes(4, 2);
ValveTime = R(1);
RewardPauseTime = 0.05;

sma = NewStateMatrix(); % Assemble state matrix

sma = SetCondition(sma, 1, 'Port2', 1); % Condition 1: Port 1 high (is in) (left)
sma = SetCondition(sma, 2, 'Port2', 0); % Condition 2: Port 2 high (is in) (center)

% TIMERS

% TIMER TO PRELOAD ODOR
OdorHeadstart = 0.500;

sma = SetGlobalTimer(sma,'TimerID',1,'Duration',S.GUI.Interval-OdorHeadstart,'OnsetDelay',0,...
   'Channel','PWM2','OnMessage', 0, 'OffMessage', 0);
sma = SetCondition(sma, 9, 'GlobalTimer1', 0);


% Timers for delivering reward drops
maxDrops = S.GUI.RewardDrops;
if maxDrops > 1
    sma = SetGlobalTimer(sma, 'TimerID', 2, 'Duration', ValveTime,...
        'OnsetDelay', 0, 'Channel', 'SoftCode', 'OnMessage',0, 'OffMessage', 0,...
        'Loop', maxDrops, 'SendEvents', 1, 'LoopInterval', RewardPauseTime); % timer to stay in reward state
else
    sma = SetGlobalTimer(sma, 'TimerID', 2, 'Duration', ValveTime,...
        'OnsetDelay', 0, 'Channel', 'SoftCode', 'OnMessage', 0, 'OffMessage', 0,...
        'Loop', 0, 'SendEvents', 1, 'LoopInterval', 0); % timer to stay in reward state    
end
sma = SetGlobalCounter(sma, 2, 'GlobalTimer2_End', maxDrops);

if RewardDrops > 1
   sma = SetGlobalTimer(sma,'TimerID',3,'Duration',ValveTime,'OnsetDelay',0,...
       'Channel', 'Valve2', 'OnMessage', 1, 'OffMessage', 0, 'Loop',...
       RewardDrops, 'SendEvents', 1, 'LoopInterval', RewardPauseTime,'OnsetTrigger', '10');
   sma = SetGlobalCounter(sma, 3, 'GlobalTimer3_End', RewardDrops);
elseif RewardDrops == 1
   sma = SetGlobalTimer(sma,'TimerID',3,'Duration',ValveTime,'OnsetDelay',0,...
       'Channel','Valve2','OnMessage', 1, 'OffMessage', 0, 'Loop', 0, 'SendEvents', 1,'LoopInterval',0,'OnsetTrigger', '10');
   sma = SetGlobalCounter(sma, 3, 'GlobalTimer3_End', 1);
else
   sma = SetGlobalTimer(sma,'TimerID',3,'Duration',0,'OnsetDelay',0,...
       'Channel','Valve2','OnMessage', 0, 'OffMessage', 0, 'Loop', 0, 'SendEvents', 1,'LoopInterval',0,'OnsetTrigger', '10');
   sma = SetGlobalCounter(sma, 3, 'GlobalTimer3_End', 1);
end


% STATES
%{
ITI
OdorPreload
StartTrial
WaitForCenter
CenterDelay
OdorCS+
OdorCS-
CenterOdorOff--if leave early
Delay--close door!
PortCheck
OutcomeReward--open door
OutcomeNoReward--odor door
NotPresentReward
Timeout
NotPresentNoReward
OutcomeDelivery
EndTrial
%}


sma = AddState(sma, 'Name', 'InterTrialInterval', ...
    'Timer', S.GUI.Interval,...
    'StateChangeConditions', {'Tup', 'StartTrial','Condition9', 'OdorPreload'},...
    'OutputActions', {'GlobalTimerTrig', 1});
sma = AddState(sma, 'Name', 'OdorPreload',...
    'Timer', OdorHeadstart,...
    'StateChangeConditions', {'Tup', 'StartTrial'},...
    'OutputActions',PreloadOdor(Odor,0)); %Preload odor
sma = AddState(sma, 'Name', 'StartTrial', ...
    'Timer', 0.2,...
    'StateChangeConditions', {'Tup', 'WaitForCenter'},...
    'OutputActions', {'Infoseek1',1});
sma = AddState(sma, 'Name', 'WaitForCenter', ...
    'Timer', 0,...
    'StateChangeConditions', {'Port2In', 'CenterDelay','Condition1','CenterDelay'},... % test how these are different!
    'OutputActions', {});
sma = AddState(sma, 'Name', 'CenterDelay', ...
    'Timer', S.GUI.CenterDelay,...
    'StateChangeConditions', {'Tup', OdorState,'Port2Out','WaitForCenter'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'OdorCSPlus', ...
    'Timer', S.GUI.OdorTime,...
    'StateChangeConditions', {'Port2Out', 'OdorOff', 'Tup', 'CloseDoor'},...
    'OutputActions',[{'BNC2',1,'Infoseek1',DIOmsg1},PresentOdor(0)]);
sma = AddState(sma, 'Name', 'OdorCSMinus', ...
    'Timer', S.GUI.OdorTime,...
    'StateChangeConditions', {'Port2Out', 'OdorOff', 'Tup', 'CloseDoor'},...
    'OutputActions',[{'BNC2',1,'Infoseek1',DIOmsg1},PresentOdor(0)]);
sma = AddState(sma, 'Name', 'OdorOff',...
    'Timer', 0,...
    'StateChangeConditions', {'Tup','WaitForCenter'},...
    'OutputActions', [{'Infoseek1',DIOmsg2},PresentOdor(0),...
    PreloadOdor(Odor,0)]);
sma = AddState(sma, 'Name', 'CloseDoor', ...
    'Timer', 1,...
    'StateChangeConditions', {'Tup', 'Delay'},...
    'OutputActions', {'Infoseek1',4});
sma = AddState(sma, 'Name', 'Delay', ...
    'Timer', S.GUI.RewardDelay,...
    'StateChangeConditions', {'Tup','PortCheck'},...
    'OutputActions', [{'Infoseek1',DIOmsg2},PresentOdor(0),...
    PreloadOdor(Odor,0)]);
sma = AddState(sma, 'Name', 'PortCheck',...
    'Timer',0,...
    'StateChangeConditions',{'Condition2',NotPresentState,'Condition1',OutcomeState},...
    'OutputActions',{'Infoseek1',3});
sma = AddState(sma, 'Name', 'OutcomeReward', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup','OutcomeDelivery'},...
    'OutputActions', {'GlobalTimerTrig', 3});
sma = AddState(sma, 'Name', 'OutcomeNoReward', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup','OutcomeDelivery'},...
    'OutputActions', {'GlobalTimerTrig', 3});
sma = AddState(sma, 'Name', 'NotPresentReward', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup','Timeout'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'Timeout', ...
    'Timer', S.GUI.Timeout,...
    'StateChangeConditions', {'Tup','OutcomeDelivery'},...
    'OutputActions', {'GlobalTimerTrig', 2});
sma = AddState(sma, 'Name', 'NotPresentNoReward', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup','OutcomeDelivery'},...
    'OutputActions', {'GlobalTimerTrig', 2});
sma = AddState(sma, 'Name','OutcomeDelivery','Timer',0,...
    'StateChangeConditions',{'GlobalCounter2_End','EndTrial'},...
    'OutputActions',{});
sma = AddState(sma, 'Name', 'EndTrial', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup', '>exit'},...
    'OutputActions', {'GlobalTimerCancel', 2});

end

%% ODOR CONTROL

% to preload, turn off control and turn on other odor (still going to
% exhaust)

function Actions = PreloadOdor(odorID,port)
    switch port
        case 0            
            cmd1 = {'ValveModule1',odorID};
            cmd2 = {'ValveModule2',odorID}; 
            Actions = [cmd1,cmd2];
        case 1
            cmd1 = {'ValveModule1',odorID};
            cmd2 = {'ValveModule2',odorID};
            cmd3 = {'ValveModule4',1};
            Actions = [cmd1,cmd2,cmd3];
        case 2
            cmd1 = {'ValveModule1',odorID};
            cmd2 = {'ValveModule2',odorID};
            cmd3 = {'ValveModule4',2};
            Actions = [cmd1,cmd2,cmd3];            
    end
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





        
%% TRIAL EVENT PLOTTING COLORS

function state_colors = getStateColors()
    state_colors = struct( ...
        'InterTrialInterval',[0.8 0.8 0.8],...
        'OdorPreload',[0.8 0.8 0.8],...
        'StartTrial', [0 0 0],...
        'WaitForCenter',[255 240 245]./255,...
        'CenterDelay', [255	255 102]./255,...
        'OdorCSPlus',[255 255 102]./255,...
        'OdorCSMinus',[255 255 102]./255,...
        'OdorOff',[255 255 102]./255,...
        'CloseDoor',[255 255 102]./255,...
        'Delay',[255 255 102]./255,...
        'PortCheck',[216 191 216]./255,...
        'OutcomeReward',[0 1 0],...
        'OutcomeNoReward',[1 0 1],...
        'NotPresentReward',[0 0 0],...
        'Timeout',[1 1 1],...
        'NotPresentNoReward',[1 1 1],...
        'OutcomeDelivery',[0 0 1],...
        'EndTrial',[0 0 0]);
end

function TrialTypes = SetTrialTypes(S)

    global BpodSystem;

    %% Define trial choice types

    maxTrials = 1000;

    blockSize = 12;
	rewardPercent = S.GUI.RewardProb;

    % set trial type arrays based on TrialTypes
    bigBlockSize = round(rewardPercent * blockSize);

    blockToShuffle = zeros(blockSize,1);

    if bigBlockSize > 0
        blockToShuffle(1:bigBlockSize) = 1;
    end

    blocks = ceil(maxTrials/blockSize);
    TrialTypes = zeros(blocks*blockSize,1);

    block=blockToShuffle;

    for n = 1:blocks
        for m = 1:blockSize
            i = randi(blockSize);
            temp = block(m);
            block(m) = block(i);
            block(i) = temp;
        end
        if n == 1
           TrialTypes(1:blockSize) = block; 
        else
            TrialTypes((n-1)*blockSize+1:n*blockSize) = block;
        end
    end

    TrialTypes=TrialTypes(1:maxTrials);
   
end
