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
    S.GUI.PreOdorDelay = 0.2;
    S.GUI.CS+Odor = 2;
    S.GUI.CS-Odor = 1;
    S.GUI.CenterDelay = 0;
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
TrialTypes = ceil(rand(1,MaxTrials)*2);
BpodSystem.Data.TrialTypes = [];

%% Initialize plots

EventsPlot('init', getStateColors); % events within trial
BpodNotebook('init');
InfoParameterGUI('init', S); % Initialize parameter GUI plugin
TotalRewardDisplay('init');

%% INITIALIZE SERIAL MESSAGES

buzzer1 = [254 1];
buzzer2 = [253 1];
doorOpen = [252 1];
doorClose = [251 1];

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
    currentTrialEvents = TrialManager.getCurrentEvents({'WaitForOdorLeft','WaitForOdorRight','NoChoice','Incorrect'}); % Hangs here until Bpod enters one of the listed trigger states, then returns current trial's states visited + events captured to this point                       
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
        Odor = S.GUI.CS+Odor;
        OdorState = 'OdorCS+'
        DIOmsg1 = 5; DIOmsg2 = 6;
        RewardDrops = S.GUI.RewardDrops;
        NotPresentState = 'NotPresentReward';
        OutcomeState = 'OutcomeReward';
    case 2 % NO WATER
        Odor = S.GUI.CS-Odor;
        OdorState = 'OdorCS-'
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

sma = SetGlobalTimer(sma,'TimerID',6,'Duration',S.GUI.Interval-OdorHeadstart,'OnsetDelay',0,...
   'Channel','none','OnMessage', 0, 'OffMessage', 0);
sma = SetCondition(sma, 9, 'GlobalTimer6', 0);


% Timers for delivering reward drops
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
OutcomeReward--open door
OutcomeNoReward--odor door
%}


sma = AddState(sma, 'Name', 'InterTrialInterval', ...
    'Timer', S.GUI.Interval,...
    'StateChangeConditions', {'Tup', 'StartTrial','Condition9', 'CenterOdorPreload'},...
    'OutputActions', {'GlobalTimerTrig', 6});
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
    'StateChangeConditions', {'Port2In', 'CenterDelay','Condition2','CenterDelay'},... % test how these are different!
    'OutputActions', {});
sma = AddState(sma, 'Name', 'CenterDelay', ...
    'Timer', S.GUI.CenterDelay,...
    'StateChangeConditions', {'Tup', OdorState,'Port2Out','WaitForCenter'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'OdorCS+', ...
    'Timer', S.GUI.CenterOdorTime,...
    'StateChangeConditions', {'Port2Out', 'CenterOdorOff', 'Tup', 'Delay'},...
    'OutputActions',[{'BNC2',1,'Infoseek1',DIOmsg1},PresentOdor(0)]);
sma = AddState(sma, 'Name', 'OdorCS-', ...
    'Timer', S.GUI.CenterOdorTime,...
    'StateChangeConditions', {'Port2Out', 'CenterOdorOff', 'Tup', 'Delay'},...
    'OutputActions',[{'BNC2',1,'Infoseek1',DIOmsg1},PresentOdor(0)]);
sma = AddState(sma, 'Name', 'CenterOdorOff',...
    'Timer', 0,...
    'StateChangeConditions', {'Tup','WaitForCenter'},...
    'OutputActions', [{'Infoseek1',DIOmsg2},PresentOdor(0),...
    PreloadOdor(Odor,0)]);
sma = AddState(sma, 'Name', 'Delay', ...
    'Timer', S.GUI.RewardDelay,...
    'StateChangeConditions', {'Tup','PortCheck'},...
    'OutputActions', [{'Infoseek1',DIOmsg2,'Infoseek1',4},PresentOdor(0),...
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

%% TRIAL TYPES

function S = UpdateTrialTypes(i,S)
    TrialTypes = S.TrialTypes;
    S.TrialTypes = [TrialTypes(1:i-1); TrialTypes(i-1); TrialTypes(i:end-1)];
    S.RewardTypes = [S.RewardTypes(1:i-1,:); S.RewardTypes(i-1,:); S.RewardTypes(i:end-1,:)];
    S.RandOdorTypes = [S.RandOdorTypes(1:i-1); S.RandOdorTypes(i-1); S.RandOdorTypes(i:end-1)];
end

function S = SetTrialTypes(S,currentTrial)

    global BpodSystem;

    %% Define trial choice types

    maxTrials = S.GUI.SessionTrials;

    typesAvailable = S.GUI.TrialTypes;

    blockSize = 12;
    typeBlockSize = 8;
    choicePercent = 0; infoPercent = 0; randPercent = 0;

    switch typesAvailable 
        case 1
            choicePercent = 1; infoPercent = 0; randPercent = 0;
        case 2
            choicePercent = 0; infoPercent = 1; randPercent = 0;
        case 3
            choicePercent = 0; infoPercent = 0; randPercent = 1;
        case 4
            choicePercent = 0; infoPercent = 0.5; randPercent = 0.5;
        case 5
            choicePercent = 0.334; infoPercent = 0.334; randPercent = 0.334;        
        case 6
            choicePercent = 0; infoPercent = 0.85; randPercent = 0.15;
        case 7
            choicePercent = 0.5; infoPercent = 0.5; randPercent = 0;
        case 8
            choicePercent = 0.5; infoPercent = 0; randPercent = 0.5;        
    end

    % set trial type arrays based on TrialTypes
    choiceBlockSize = round(choicePercent * blockSize);
    infoBlockSize = round(infoPercent * blockSize);
    randBlockSize = round(randPercent * blockSize);

    blockToShuffle = zeros(blockSize,1);

    if choiceBlockSize > 0
        blockToShuffle(1:choiceBlockSize) = 1;
    end

    if infoBlockSize > 0
        if choiceBlockSize > 0
            blockToShuffle(choiceBlockSize+1:choiceBlockSize + infoBlockSize) = 2;
        else
            blockToShuffle(1:infoBlockSize) = 2;
        end
    end
    if randBlockSize > 0
        blockToShuffle(choiceBlockSize + infoBlockSize + 1:end) = 3;
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

%     TrialTypes = [2; 2; 3; 3; 2; 2; 3; 3; TrialTypes];
    TrialTypes=TrialTypes(1:maxTrials);
    if currentTrial==1
        S.TrialTypes = TrialTypes;
    else
        S.TrialTypes = [S.TrialTypes(1:currentTrial-1); TrialTypes(1:end-currentTrial+1)];
        TrialTypePlotInfo(BpodSystem.GUIHandles.TrialTypePlot,'update',currentTrial,S.TrialTypes);
    end
    

end

function S = SetRewardTypes(S,currentTrial)

    maxTrials = S.GUI.SessionTrials;
    typeBlockSize = 8;    
    
    %% SET REWARD BLOCKS

    infoBigCount = round(S.GUI.InfoRewardProb*typeBlockSize);
    randBigCount = round(S.GUI.RandRewardProb*typeBlockSize);

    infoBlockShuffle = zeros(typeBlockSize,1);
    randBlockShuffle = zeros(typeBlockSize,1);

    infoBlockShuffle(1:infoBigCount) = 1;
    randBlockShuffle(1:randBigCount) = 1;

    typeBlockCount = ceil(maxTrials/typeBlockSize);
    RewardTypes = zeros(typeBlockCount*typeBlockSize,4);
    RandOdorTypes = zeros(typeBlockCount*typeBlockSize,1);

    infoBlock = infoBlockShuffle;
    randBlock = randBlockShuffle;
    randOdorBlock = randBlockShuffle;

    % info choice
    for n = 1:typeBlockCount
        for m = 1:typeBlockSize
            i = randi(typeBlockSize);
            temp = infoBlock(m);
            infoBlock(m) = infoBlock(i);
            infoBlock(i) = temp;
        end
        if n == 1
           RewardTypes(1:typeBlockSize,1) = infoBlock'; 
        else
            RewardTypes((n-1)*typeBlockSize+1:n*typeBlockSize,1) = infoBlock';
        end
    end

    % rand choice
    for n = 1:typeBlockCount
        for m = 1:typeBlockSize
            i = randi(typeBlockSize);
            temp = randBlock(m);
            randBlock(m) = randBlock(i);
            randBlock(i) = temp;
        end
        if n == 1
           RewardTypes(1:typeBlockSize,2) = randBlock'; 
        else
            RewardTypes((n-1)*typeBlockSize+1:n*typeBlockSize,2) = randBlock';
        end
    end

    % info forced
    for n = 1:typeBlockCount
        for m = 1:typeBlockSize
            i = randi(typeBlockSize);
            temp = infoBlock(m);
            infoBlock(m) = infoBlock(i);
            infoBlock(i) = temp;
        end
        if n == 1
           RewardTypes(1:typeBlockSize,3) = infoBlock'; 
        else
            RewardTypes((n-1)*typeBlockSize+1:n*typeBlockSize,3) = infoBlock';
        end
    end

    % rand forced
    for n = 1:typeBlockCount
        for m = 1:typeBlockSize
            i = randi(typeBlockSize);
            temp = randBlock(m);
            randBlock(m) = randBlock(i);
            randBlock(i) = temp;
        end
        if n == 1
           RewardTypes(1:typeBlockSize,4) = randBlock'; 
        else
            RewardTypes((n-1)*typeBlockSize+1:n*typeBlockSize,4) = randBlock';
        end
    end

    % rand odors
    for n = 1:typeBlockCount
        for m = 1:typeBlockSize
            i = randi(typeBlockSize);
            temp = randOdorBlock(m);
            randOdorBlock(m) = randOdorBlock(i);
            randOdorBlock(i) = temp;
        end
        if n == 1
           RandOdorTypes(1:typeBlockSize) = randOdorBlock'; 
        else
            RandOdorTypes((n-1)*typeBlockSize+1:n*typeBlockSize) = randOdorBlock';
        end
    end

    % Trial types (rewards) to pull from
    RewardTypes = RewardTypes(1:maxTrials,:);


    % Rand Odors to pull from
    % RandOdorTypes = repmat(RandOdorTypes,1,4);
    RandOdorTypes = RandOdorTypes(1:maxTrials);

    if currentTrial == 1
        S.RandOdorTypes = RandOdorTypes;
        S.RewardTypes = RewardTypes;
    else
        S.RandOdorTypes = [S.RandOdorTypes(1:currentTrial); RandOdorTypes(1:end-currentTrial)];
        S.RewardTypes = [S.RewardTypes(1:currentTrial,:); RewardTypes(1:end-currentTrial,:)];
    end
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


%% OUTCOME

function [rewardAmount, Outcome] = UpdateOutcome(currentTrial,S,RewardLeft,RewardRight)

    global BpodSystem
    % BpodSystem.Data.RawEvents(currentTrial)
    TrialData = BpodSystem.Data.RawEvents.Trial{currentTrial};
    TrialCounts = BpodSystem.Data.TrialCounts;
    PlotOutcomes = BpodSystem.Data.PlotOutcomes;
    
    trialType = S.TrialTypes(currentTrial);
    infoSide = S.GUI.InfoSide;
    infoBigReward = S.GUI.InfoBigDrops*4;
    infoSmallReward = S.GUI.InfoSmallDrops*4;
    randBigReward = S.GUI.RandBigDrops*4;
    randSmallReward = S.GUI.RandSmallDrops*4;
    rewardAmount = 0;
    x = currentTrial;
    newTrialCounts = TrialCounts;
    newPlotOutcomes = PlotOutcomes;
    
    if infoSide == 0
        switch trialType
            case 1
                if ~isnan(TrialData.NoChoice(1))
                    newPlotOutcomes(x) = 2;
                    Outcome = 1; % choice no choice
                elseif ~isnan(TrialData.States.WaitForOdorLeft(1))
                    newTrialCounts(1) = TrialCounts(1) + 1; % infochoice
                    newPlotOutcomes(x) = 1;
                    if RewardLeft == 1
                        if ~isnan(TrialData.States.LeftBigReward(1))
                            Outcome = 2; % choice info big
                            rewardAmount = infoBigReward;
                        else
                            newPlotOutcomes(x) = -1;
                            Outcome = 3; % choice info big NP
                        end
                    else
                        if ~isnan(TrialData.States.LeftSmallReward(1))
                            Outcome = 4; % choice info small
                            rewardAmount = infoSmallReward;
                        else
                            newPlotOutcomes(x) = -1;
                            Outcome = 5; % choice info small NP
                        end
                    end
                else
                   newTrialCounts(2) = TrialCounts(2) + 1; % randChoice
                   newPlotOutcomes(x) = 0;
                   if RewardRight == 1
                        if ~isnan(TrialData.States.RightBigReward(1))
                            Outcome = 6; % choice rand big
                            rewardAmount = randBigReward;
                        else
                            newPlotOutcomes(x) = -1;
                            Outcome = 7; % choice rand big NP
                        end                       
                   else
                        if ~isnan(TrialData.States.RightSmallReward(1))
                            Outcome = 8; % choice rand small
                            rewardAmount = randSmallReward;
                        else
                            newPlotOutcomes(x) = -1;
                            Outcome = 9; % choice rand small NP
                        end                       
                   end
                end
                
            case 2
                if ~isnan(TrialData.States.NoChoice(1))
                    newPlotOutcomes(x) = 2;
                    Outcome = 10; % info no choice
                elseif ~isnan(TrialData.States.WaitForOdorLeft(1))
                    newTrialCounts(3) = TrialCounts(3) + 1; % infoforced
                    newPlotOutcomes(x) = 1;
                    if RewardLeft == 1
                        if ~isnan(TrialData.States.LeftBigReward(1))
                            Outcome = 11; % info big
                            rewardAmount = infoBigReward;
                        else
                            newPlotOutcomes(x) = -1;
                            Outcome = 12; % info big NP
                        end
                    else
                        if ~isnan(TrialData.States.LeftSmallReward(1))
                            Outcome = 13; % info small
                            rewardAmount = infoSmallReward;
                        else
                            newPlotOutcomes(x) = -1;
                            Outcome = 14; % info small NP
                        end
                    end
                else
                    newTrialCounts(3) = TrialCounts(3) + 1; % infoforced
                    newPlotOutcomes(x) = 3;
                    Outcome = 15; % info incorrect
                end
                
            case 3
                if ~isnan(TrialData.States.NoChoice(1))
                    newPlotOutcomes(x) = 2;
                    Outcome = 16; % rand no choice
                elseif ~isnan(TrialData.States.WaitForOdorRight(1))
                    newTrialCounts(4) = TrialCounts(4) + 1; % randforced
                    newPlotOutcomes(x) = 0;
                    if RewardRight == 1
                        if ~isnan(TrialData.States.RightBigReward(1))
                            Outcome = 17; % rand big
                            rewardAmount = randBigReward;
                        else
                            newPlotOutcomes(x) = -1;
                            Outcome = 18; % rand big NP
                        end
                    else
                        if ~isnan(TrialData.States.RightSmallReward(1))
                            Outcome = 19; % rand small
                            rewardAmount = randSmallReward;
                        else
                            newPlotOutcomes(x) = -1;
                            Outcome = 20; % rand small NP
                        end
                    end
                else
                    newPlotOutcomes(x) = 3;
                    newTrialCounts(4) = TrialCounts(4) + 1; % randforced
                    Outcome = 21; % rand incorrect
                end
        end
        
    else
        switch trialType
            case 1
                if ~isnan(TrialData.States.NoChoice(1))
                    newPlotOutcomes(x) = 2;
                    Outcome = 1; % choice no choice
                elseif ~isnan(TrialData.States.WaitForOdorRight(1))
                    newTrialCounts(1) = TrialCounts(1) + 1; % infochoice
                    newPlotOutcomes(x) = 1;
                    if RewardRight == 1
                        if ~isnan(TrialData.States.RightBigReward(1))
                            Outcome = 2; % choice info big
                            rewardAmount = infoBigReward;
                        else
                            newPlotOutcomes(x) = -1;
                            Outcome = 3; % choice info big NP
                        end
                    else
                        if ~isnan(TrialData.States.RightSmallReward(1))
                            Outcome = 4; % choice info small
                            rewardAmount = infoSmallReward;
                        else
                            newPlotOutcomes(x) = -1;
                            Outcome = 5; % choice info small NP
                        end
                    end
                else
                    newTrialCounts(2) = TrialCounts(2) + 1; % randChoice
                    newPlotOutcomes(x) = 0;
                   if RewardLeft == 1
                        if ~isnan(TrialData.States.LeftBigReward(1))
                            Outcome = 6; % choice rand big
                            rewardAmount = randBigReward;
                        else
                            newPlotOutcomes(x) = -1;
                            Outcome = 7; % choice rand big NP
                        end                       
                   else
                        if ~isnan(TrialData.States.LeftSmallReward(1))
                            Outcome = 8; % choice rand small
                            rewardAmount = randSmallReward;
                        else
                            newPlotOutcomes(x) = -1;
                            Outcome = 9; % choice rand small NP
                        end                       
                   end
                end
                
            case 2
                if ~isnan(TrialData.States.NoChoice(1))
                    newPlotOutcomes(x) = 2;
                    Outcome = 10; % info no choice
                elseif ~isnan(TrialData.States.WaitForOdorRight(1))
                    newTrialCounts(3) = TrialCounts(3) + 1; % infoforced
                    newPlotOutcomes(x) = 1;
                    if RewardRight == 1
                        if ~isnan(TrialData.States.RightBigReward(1))
                            Outcome = 11; % info big
                            rewardAmount = infoBigReward;
                        else
                            newPlotOutcomes(x) = -1;
                            Outcome = 12; % info big NP
                        end
                    else
                        if ~isnan(TrialData.States.RightSmallReward(1))
                            Outcome = 13; % info small
                            rewardAmount = infoSmallReward;
                        else
                            newPlotOutcomes(x) = -1;
                            Outcome = 14; % info small NP
                        end
                    end
                else
                    newTrialCounts(3) = TrialCounts(3) + 1; % infoforced
                    newPlotOutcomes(x) = 3;
                    Outcome = 15; % info incorrect
                end
                
            case 3
                if ~isnan(TrialData.States.NoChoice(1))
                    newPlotOutcomes(x) = 2;
                    Outcome = 16; % rand no choice
                elseif ~isnan(TrialData.States.WaitForOdorLeft(1))
                    newTrialCounts(4) = TrialCounts(4) + 1; % randforced
                    newPlotOutcomes(x) = 0;
                    if RewardLeft == 1
                        if ~isnan(TrialData.States.LeftBigReward(1))
                            Outcome = 17; % rand big
                            rewardAmount = randBigReward;
                        else
                            newPlotOutcomes(x) = -1;
                            Outcome = 18; % rand big NP
                        end
                    else
                        if ~isnan(TrialData.States.LeftSmallReward(1))
                            Outcome = 19; % rand small
                            rewardAmount = randSmallReward;
                        else
                            newPlotOutcomes(x) = -1;
                            Outcome = 20; % rand small NP
                        end
                    end
                else
                    newTrialCounts(4) = TrialCounts(4) + 1; % randforced
                    newPlotOutcomes(x) = 3;
                    Outcome = 21; % rand incorrect
                end
        end            
    end    
    BpodSystem.Data.TrialCounts = newTrialCounts;
    BpodSystem.Data.PlotOutcomes = newPlotOutcomes;
end



        
%% TRIAL EVENT PLOTTING COLORS

function state_colors = getStateColors(thisInfoSide)
    if thisInfoSide == 0
        state_colors = struct( ...
            'InterTrialInterval',[0.8 0.8 0.8],...
            'CenterOdorPreload',[0.8 0.8 0.8],...
            'StartTrial', [0 0 0],...
            'WaitForCenter',[255 240 245]./255,...
            'CenterDelay', [255	255 102]./255,...
            'CenterOdor',[255 255 102]./255,...
            'CenterOdorOff',[255 255 102]./255,...
            'CenterPostOdorDelay',[255 255 102]./255,...
            'GoCue',[0 1 0],...
            'Response',[1 1 0.8],...
            'GracePeriod',[1 1 0.8],...
            'WaitForOdorLeft',[216 191 216]./255,...
            'PreloadOdorLeft',[216 191 216]./255,...            
            'OdorLeft',[128	0 128]./255,...
            'RewardDelayLeft',[216 191 216]./255,...
            'LeftPortCheck',[216 191 216]./255,...
            'LeftBigReward',[0 1 0],...
            'LeftSmallReward',[1 0 1],...
            'IncorrectLeft',[0 0 0],...
            'LeftNotPresent',[1 1 1],...
            'WaitForOdorRight',[1 0.8 0],... % 1 0.8 0 [255 228 189]./255
            'PreloadOdorRight',[1 0.8 0],...
            'OdorRight',[255 140 0]./255,...
            'RewardDelayRight',[1 0.8 0],...
            'RightPortCheck',[1 0.8 0],...
            'RightBigReward',[0 1 0],...
            'RightSmallReward',[1 0 1],...
            'IncorrectRight',[0 0 0],...    
            'RightNotPresent',[1 1 1],...
            'OutcomeDelivery',[0 0 1],...
            'NoChoice',[0 1 1],...
            'Incorrect',[1 0 0],...
            'TimeoutOdor',[0.4 0.4 0.4],...
            'TimeoutRewardDelay',[0.2 0.2 0.2],...
            'TimeoutOutcome',[0.4 0.4 0.4],...
            'EndTrial',[0 0 0]);
    else
        state_colors = struct( ...
            'InterTrialInterval',[0.8 0.8 0.8],...
            'CenterOdorPreload',[0.8 0.8 0.8],...            
            'StartTrial', [0 0 0],...
            'WaitForCenter',[255 240 245]./255,...
            'CenterDelay', [255	255 102]./255,...
            'CenterOdor',[255 255 102]./255,...
            'CenterOdorOff',[255 255 102]./255,...
            'CenterPostOdorDelay',[255 255 102]./255,...
            'GoCue',[0 1 0],...
            'Response',[1 1 0.8],...
            'GracePeriod',[1 1 0.8],...
            'WaitForOdorLeft',[1 0.8 0],...
            'PreloadOdorLeft',[1 0.8 0],...
            'OdorLeft',[255 140 0]./255,...
            'RewardDelayLeft',[1 0.8 0],...
            'LeftPortCheck',[1 0.8 0],...
            'LeftBigReward',[0 1 0],...
            'LeftSmallReward',[1 0 1],...
            'IncorrectLeft',[0 0 0],...
            'LeftNotPresent',[1 1 1],...
            'WaitForOdorRight',[216 191 216]./255,...
            'PreloadOdorRight',[216 191 216]./255,...            
            'OdorRight',[128	0 128]./255,...
            'RewardDelayRight',[216 191 216]./255,...
            'RightPortCheck',[216 191 216]./255,...
            'RightBigReward',[0 1 0],...
            'RightSmallReward',[1 0 1],...
            'IncorrectRight',[0 0 0],...    
            'RightNotPresent',[1 1 1],...
            'OutcomeDelivery',[0 0 1],...
            'NoChoice',[0 1 1],...
            'Incorrect',[1 0 0],...
            'TimeoutOdor',[0.4 0.4 0.4],...
            'TimeoutRewardDelay',[0.2 0.2 0.2],...
            'TimeoutOutcome',[0.4 0.4 0.4],...
            'EndTrial',[0 0 0]);        
    end
end


