% INFO SIDE 0 = info on LEFT

% TO TRACK: water, trials complete, % correct, % info
% MAKE OUTCOME BARS??

% NEED TO FIX REPEATING TRIAL TYPES IF NO CHOICE ETC!!git status
% is randomization of reward and trial correct??
% sending data vs making state machine vs current trial?!?

% trial event plots--Not present?? not showing reward?

% NOT ACTUALLY OPENING WATER VALVES?!?

% GRACE PERIOD: additional time after response period expires. mouse can
% still choose then goes immediately to odor-->messes up timing!

% OMG BEEPING TIMER!!!

% HOUSE LIGHTS

% ADDITIONAL COMPONENTS: OUTPUT PINS: 4 latch valves (8 pins), buzzer,
% house light LED, scope sync: center odor, side odor, water (3 pins)
% lick sensors (IRQ, SCL, SDA) 
% FOR SCOPE, BNCs: 1 IN = sync, 1 OUT = trig, 1 out for odor

% additional components handled by teensy shield module, DIOLicks
% send 2 bytes, pin + state, to turn output on and off
% send 2 bytes, 254 or 253 and 1 to turn on buzzer
% licks come as an event with number of sensor?

%{

how to read scope SYNC in signal?? (outside of trial structure)? no events
in trial
send it directly to computer??

The simplest way to add more digital I/O is via Teensy 3.2 + the Bpod Teensy Shield (both are shown in this pic). With the DIO sketch loaded, this makes a "DIO Module' which provides 6 digital input channels on Teensy pins 2-7 and 6 digital output channels on Teensy pins 19-23. You can add up to 5 DIO modules for a total of 30 additional inputs and outputs.
To build the DIO module, you'd have to solder two female headers to Teensy 3.2, and upload the DIO sketch. The state machine should power Teensy over the wire (if connected to module ports 1-3) and the DIO module will appear as DIO1 (additional modules detected are DIO2-5). Then, in the 'output actions' section of the state where you want to drive the pins, add {'DIO1', [N S]} where N is pin number (19-23) and S is the new logic state (0 or 1 for 0V or 3.3V).

------------------------------------------------------
5 modules: 3 valve modules, then need 15 TTL pins.

So teensy (one or two, if can't configure all pins as outputs) can run
latch valves (need 8 pins)

How to do buzzer, LED, lick sensors (TOUCH_IRQ + WIRE)

arduScope (to turn
on scope-->USE native BNC for this and sending and receiving SYNC)

-----------------

how to read in SYNC outside of trial structure / during downtimes? some
marker for missed frames? or only run scope outside of ITI? I don't care
what mouse is doing then??

see Josh's email re: ArCOM. Does it let me just use old protocol on regular
arduino/due/teensy without Bpod? IS all Bpod giving me the trial manager
object/holding saving data until ITI and preparing next state machine
outside of trial running loop? Couldn't I just do this with Python and a
DAQ?

if not, use arduino shield for the non-teensy pins (lick sensor and send
scope TTL). upload their sketch and use as normal?  
%}


%{
----------------------------------------------------------------------------

This code runs a 2AFC Information Seeking assay. After initiating trial
with a center-poke, animal receives odor directing to right or left port or
free choice. Animal chooses side port, receives either informative or un-
informative odor, then after a delay, reward outcome at the same side port.


----------------------------------------------------------------------------
%}
function InfoSeek


global BpodSystem

%% Create trial manager object
TrialManager = TrialManagerObject;

%% Define parameters

S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.SessionTrials = 1000;
    S.GUI.TrialTypes = 2;
    S.GUI.InfoSide = 0;
    S.GUI.InfoOdor = 2;
    S.GUI.RandOdor = 0;
    S.GUI.ChoiceOdor = 3;
    S.GUI.OdorA = 3;
    S.GUI.OdorB = 2;
    S.GUI.OdorC = 0;
    S.GUI.OdorD = 1;
    S.GUI.CenterDelay = 0;
    S.GUI.CenterOdorTime = 0.2;
    S.GUI.StartDelay = 0;
    S.GUI.OdorDelay = 0;
    S.GUI.OdorTime = 0;
    S.GUI.RewardDelay = 0.5;
    S.GUI.InfoBigDrops = 1;
    S.GUI.InfoSmallDrops = 1;
    S.GUI.RandBigDrops = 1;
    S.GUI.RandSmallDrops = 1;
    S.GUI.InfoRewardProb = 1;
    S.GUI.RandRewardProb = 1;
    S.GUI.GracePeriod = 100000000; 
    S.GUI.Interval = 1; 
    S.GUI.OptoFlag = 0;
    S.GUI.OptoType = 0;
    S.GUI.ImageFlag = 0;
    S.GUI.ImageType = 0;
end

BpodSystem.ProtocolSettings = S;

SaveProtocolSettings(BpodSystem.ProtocolSettings);

%% SET INFO SIDE

infoSide = S.GUI.InfoSide;

% 0 = info on left


%% Define trial choice types

MaxTrials = S.GUI.SessionTrials;

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

blocks = ceil(MaxTrials/blockSize);
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

% trial choiceTypes
% TrialTypes = [2; 2; 3; 3; 2; 2; 3; 3; TrialTypes];
TrialTypes=TrialTypes(1:MaxTrials);

PlotOutcomes = NaN(1,MaxTrials);
Outcomes = NaN(1,MaxTrials);

BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.
BpodSystem.Data.Outcomes = [];

%% SET REWARD BLOCKS

infoBigCount = round(S.GUI.InfoRewardProb*typeBlockSize);
randBigCount = round(S.GUI.RandRewardProb*typeBlockSize);

infoBlockShuffle = zeros(typeBlockSize,1);
randBlockShuffle = zeros(typeBlockSize,1);

infoBlockShuffle(1:infoBigCount) = 1;
randBlockShuffle(1:randBigCount) = 1;

typeBlockCount = ceil(MaxTrials/typeBlockSize);
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
RewardTypes = RewardTypes(1:MaxTrials,:);

% Rand Odors to pull from
% RandOdorTypes = repmat(RandOdorTypes,1,4);
RandOdorTypes = RandOdorTypes(1:MaxTrials);

BpodSystem.Data.OrigTrialTypes = TrialTypes;
BpodSystem.Data.RewardTypes = RewardTypes;

%% Initialize plots

% BpodSystem.ProtocolFigures.OutcomePlotFig = figure('Position', [50 540 1000 250],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none');
BpodSystem.ProtocolFigures.TrialTypePlotFig = figure('Position', [50 540 1000 250],'name','Trial Type','numbertitle','off', 'MenuBar', 'none');
% BpodSystem.GUIHandles.OutcomePlot = axes('Position', [.075 .35 .89 .6]);
BpodSystem.GUIHandles.TrialTypePlot = axes('OuterPosition', [0 0 1 1]);
TrialTypePlotInfo(BpodSystem.GUIHandles.TrialTypePlot,'init',TrialTypes,min([MaxTrials 40])); %trial choice types   
EventsPlot('init', getStateColors(infoSide));
BpodNotebook('init');
InfoParameterGUI('init', S); % Initialize parameter GUI plugin
TotalRewardDisplay('init');

%% SET INITIAL TYPE COUNTS

TrialCounts = [0,0,0,0];

%% INITIALIZE SERIAL MESSAGES

% % pins
% LEDPin = 11;
% buzzer1 = [254 1];
% buzzer2 = [253 1];
% 
% DIOmodule = [modules(strncmp('DIO',modules,3))];
% DIOmodule = DIOmodule{1};
% 
% % MINISCOPE
% % miniscope has 4 I/O BNC Pins, and scope sync and trig
% % scope sync connects to Bpod IN BNC
% % scope trig to Bpod OUT BNC 1
% % Bpod out BNC 2 at center odor start
% 
% % Set serial messages 1,2,3,4,5,6,7,8,9,10
% LoadSerialMessages('DIOLicks1', {buzzer1, buzzer2,...
%     [11 1], [11 0], [12 1], [12 0], [13 1], [13 0]});
% %{
%     1 buzzer 1
%     2 buzzer 2
%     3 LEDs on
%     4 LEDs off
%     5 scope signal 1 on side odor
%     6 scope signal 1 off side odor
%     7 scope signal 2 on reward
%     8 scope signal 2 off reward
%     %}
    
% controls for odor
LoadSerialMessages('ValveModule1',{[1 2],[3 4],[5 6]}); % control by port

%% START SCOPE RECORDING? HOW TO SET TIMER? MOVE THIS INTO TRIAL START??

% Turn on BNC1
% ManualOverride('OB',1);

% NEED TO CATCH AND TURN THIS OFF IF AN ERROR!!

%% SAVE EVENT NAMES AND NUMBER

BpodSystem.Data.nEvents = BpodSystem.StateMachineInfo.nEvents;
BpodSystem.Data.EventNames = BpodSystem.StateMachineInfo.EventNames;
SaveBpodSessionData;

%% INITIALIZE STATE MACHINE

[sma,~,nextTrialType,TrialTypes,nextRewardLeft,nextRewardRight] = PrepareStateMachine(S, TrialTypes, TrialCounts, infoSide,  RewardTypes, RandOdorTypes, 1, []); % Prepare state machine for trial 1 with empty "current events" variable

TrialManager.startTrial(sma); % Sends & starts running first trial's state machine. A MATLAB timer object updates the 
                              % console UI, while code below proceeds in parallel.
RewardLeft = nextRewardLeft; RewardRight = nextRewardRight;

%% MAIN TRIAL LOOP

for currentTrial = 1:MaxTrials
    currentTrialEvents = TrialManager.getCurrentEvents({'InterTrialInterval'}); 
                                       % Hangs here until Bpod enters one of the listed trigger states, 
                                       % then returns current trial's states visited + events captured to this point                       
    if BpodSystem.Status.BeingUsed == 0;        
        for v = 1:8
            ModuleWrite('ValveModule1',['C' v]);
            ModuleWrite('ValveModule2',['C' v]);
            ModuleWrite('ValveModule3',['C' v]);
        end                
        return; end % If user hit console "stop" button, end session 
    [sma, S, nextTrialType, TrialTypes,nextRewardLeft,nextRewardRight] = PrepareStateMachine(S, TrialTypes, TrialCounts, infoSide, RewardTypes, RandOdorTypes, currentTrial+1, currentTrialEvents); % Prepare next state machine.
    % Since PrepareStateMachine is a function with a separate workspace, pass any local variables needed to make 
    % the state machine as fields of settings struct S e.g. S.learningRate = 0.2.
    SendStateMachine(sma, 'RunASAP'); % With TrialManager, you can send the next trial's state machine while the current trial is ongoing
    RawEvents = TrialManager.getTrialData; % Hangs here until trial is over, then retrieves full trial's raw data
    if BpodSystem.Status.BeingUsed == 0;        
        for v = 1:8
            ModuleWrite('ValveModule1',['C' v]);
            ModuleWrite('ValveModule2',['C' v]);
            ModuleWrite('ValveModule3',['C' v]);
        end        
        return; end % If user hit console "stop" button, end session 
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    TrialManager.startTrial(); % Start processing the next trial's events (call with no argument since SM was already sent)
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned from last trial, update plots and save data
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data = BpodNotebook('sync', BpodSystem.Data); % Sync with Bpod notebook plugin
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial); % Adds the trial type of the current trial to data
        BpodSystem.Data.AllTrialTypes{currentTrial} = TrialTypes;
        [outcome, rewardAmount] = UpdateOutcome(TrialTypes(currentTrial),RewardLeft,RewardRight,BpodSystem.Data,infoSide,S);
        TotalRewardDisplay('add',rewardAmount);
        BpodSystem.Data.Outcomes(currentTrial) = outcome;
        RewardLeft = nextRewardLeft; RewardRight = nextRewardRight;
        [TrialCounts,PlotOutcomes] = UpdateCounts(TrialTypes(currentTrial), BpodSystem.Data, TrialCounts, PlotOutcomes, infoSide);
        EventsPlot('update');
        TrialTypePlotInfo(BpodSystem.GUIHandles.TrialTypePlot,'update',BpodSystem.Data.nTrials+1,TrialTypes,PlotOutcomes);
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file --> POSSIBLY MOVE THIS TO SAVE TIME??
    end
end

%% SHUT DOWN
% NEED CODE FOR TURNING OFF SCOPE AND SHUTTING DOWN HERE!
% ManualOverride('OB',1);

end % end of protocol main function

%% PREPARE STATE MACHINE

function [sma, S, nextTrialType, TrialTypes, RewardLeft, RewardRight] = PrepareStateMachine(S, TrialTypes, TrialCounts, infoSide, RewardTypes, RandOdorTypes, nextTrial, currentTrialEvents)

global BpodSystem;

S = InfoParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin

% Water parameters
R = GetValveTimes(4, [1 3]);
% R = [0.100 0.100];
LeftValveTime = R(1); RightValveTime = R(2); % Update reward amounts
MaxValveTime = max(R);
maxDrops = max([S.GUI.InfoBigDrops,S.GUI.InfoSmallDrops,S.GUI.RandBigDrops,S.GUI.RandSmallDrops]);
RewardPauseTime = 0.05;

% % pins
% LEDPin = 11;
% % for sending side odor on and reward on to scope
% syncPins = [12, 13];
% buzzer1 = [254 1];
% buzzer2 = [253 1];
% 
% modules = BpodSystem.Modules.Name;
% DIOmodule = [modules(strncmp('DIO',modules,3))];
% DIOmodule = DIOmodule{1};

% MINISCOPE
% miniscope has 4 I/O BNC Pins, and scope sync and trig
% scope sync connects to Bpod IN BNC
% scope trig to Bpod OUT BNC
% other Bpod out BNC at center odor start

% Set serial messages 1,2,3,4
% LoadSerialMessages('DIOLicks1', {[254 1],[253 1],[5 1], [5 0]});
% LoadSerialMessages('DIOLicks1', {[5 1]});
% LoadSerialMessages(1, {[5 8], [2 3 4]});


% DETERMINE TRIAL TYPE
if nextTrial>1
    previousStates = currentTrialEvents.StatesVisited;
    % if ~isnan(find(contains(previousStates,'NoChoice'))) | ~isnan(find(contains(previousStates,'Incorrect')))
    if sum(contains(previousStates,'NoChoice') | contains(previousStates,'Incorrect'))>0
        nextTrialType = TrialTypes(nextTrial-1);
        TrialTypes = UpdateTrialTypes(nextTrial,nextTrialType,TrialTypes);
    else
        nextTrialType = TrialTypes(nextTrial);
    end
else
   nextTrialType = TrialTypes(nextTrial);
end

% Set trialParams (reward and odor)
switch nextTrialType % Determine trial-specific state matrix fields
    % Stimulus output will change to CENTER ODOR
    case 1 % CHOICE
%         OutcomeStateLeft = 'LeftReward'; OutcomeStateRight = 'RightReward';
        ChooseLeft = 'WaitForOdorLeft'; ChooseRight = 'WaitForOdorRight'; StimulusOutput = {'PWM1', 255,'PWM3', 255};
        ThisCenterOdor = S.GUI.ChoiceOdor;
        if infoSide == 0 % INFO LEFT            
            RewardLeft = RewardTypes(TrialCounts(1)+1,1); RewardRight = RewardTypes(TrialCounts(2)+1,2);
            RightSideOdorFlag = RandOdorTypes(TrialCounts(2)+1,1);
            if RightSideOdorFlag == 0
                RightSideOdor = S.GUI.OdorC;
            else
                RightSideOdor = S.GUI.OdorD;
            end
            if RewardLeft == 1
                OutcomeStateLeft = 'LeftBigReward';
                LeftRewardDrops = S.GUI.InfoBigDrops;
                LeftSideOdor = S.GUI.OdorA;
            else
                OutcomeStateLeft = 'LeftSmallReward';
                LeftRewardDrops = S.GUI.InfoSmallDrops;
                LeftSideOdor = S.GUI.OdorB;
            end
            if RewardRight == 1
                OutcomeStateRight = 'RightBigReward';
                RightRewardDrops = S.GUI.RandBigDrops;
            else
                OutcomeStateRight = 'RightSmallReward';
                RightRewardDrops = S.GUI.RandSmallDrops;
            end
        else
            RewardLeft = RewardTypes(TrialCounts(2)+1,2); RewardRight = RewardTypes(TrialCounts(1)+1,1);
            LeftSideOdorFlag = RandOdorTypes(TrialCounts(2)+1,1);
            if LeftSideOdorFlag == 0
                LeftSideOdor = S.GUI.OdorC;
            else
                LeftSideOdor = S.GUI.OdorD;
            end            
            if RewardLeft == 1
                OutcomeStateLeft = 'LeftBigReward';
                LeftRewardDrops = S.GUI.RandBigDrops;
            else
                OutcomeStateLeft = 'LeftSmallReward';
                LeftRewardDrops = S.GUI.RandSmallDrops;
            end
            if RewardRight == 1
                OutcomeStateRight = 'RightBigReward';
                RightRewardDrops = S.GUI.InfoBigDrops;
                RightSideOdor = S.GUI.OdorA;
            else
                OutcomeStateRight = 'RightSmallReward';
                RightRewardDrops = S.GUI.InfoSmallDrops;
                RightSideOdor = S.GUI.OdorB;
            end            
        end
             
    case 2 % INFO FORCED
%         ChooseLeft = 'WaitForOdorLeft'; ChooseRight = 'Punish'; StimulusOutput = {'PWM1', 255}; OutcomeStateLeft = 'LeftReward'; OutcomeStateRight = 'RightReward';
        ThisCenterOdor = S.GUI.InfoOdor;
        if infoSide == 0
            % info on left
            RewardLeft = RewardTypes(TrialCounts(3)+1,3); RewardRight = 0;
            ChooseLeft = 'WaitForOdorLeft'; ChooseRight = 'Incorrect'; StimulusOutput = {'PWM1', 255};
            RightSideOdor = 0;
%             OutcomeStateLeft = 'LeftCorrectChoice'; OutcomeStateRight = 'RightIncorrectChoice';
            if RewardLeft == 1
                OutcomeStateLeft = 'LeftBigReward';
                LeftRewardDrops = S.GUI.InfoBigDrops;
                LeftSideOdor = S.GUI.OdorA;
            else
                OutcomeStateLeft = 'LeftSmallReward';
                LeftRewardDrops = S.GUI.InfoSmallDrops;
                LeftSideOdor = S.GUI.OdorB;
            end
            OutcomeStateRight = 'IncorrectRight';
            RightRewardDrops = 0;
        else
            RewardLeft = 0; RewardRight = RewardTypes(TrialCounts(3)+1,3);
            ChooseLeft = 'Incorrect'; ChooseRight = 'WaitForOdorRight'; StimulusOutput = {'PWM3', 255};
            LeftSideOdor = 0;
%             OutcomeStateLeft = 'LeftInCorrectChoice'; OutcomeStateRight = 'RightCorrectChoice';
            if RewardRight == 1
                OutcomeStateRight = 'RightBigReward';
                RightRewardDrops = S.GUI.InfoBigDrops;
                RightSideOdor = S.GUI.OdorA;
            else
                OutcomeStateRight = 'RightSmallReward';
                RightRewardDrops = S.GUI.InfoSmallDrops;
                RightSideOdor = S.GUI.OdorB;
            end
            OutcomeStateLeft = 'IncorrectLeft';
            LeftRewardDrops = 0;
        end
    case 3 % RAND FORCED
%         ChooseLeft = 'Incorrect'; ChooseRight = 'WaitForOdorRight'; StimulusOutput = {'PWM3', 255}; OutcomeStateLeft = 'LeftReward'; OutcomeStateRight = 'RightReward';
        ThisCenterOdor = S.GUI.RandOdor;
        if infoSide == 0 % INFO ON LEFT
            RewardLeft = 0; RewardRight = RewardTypes(TrialCounts(4)+1,4);
            ChooseLeft = 'Incorrect'; ChooseRight = 'WaitForOdorRight'; StimulusOutput = {'PWM3', 255};
%             OutcomeStateLeft = 'LeftInCorrectChoice'; OutcomeStateRight = 'RightCorrectChoice';
            RightSideOdorFlag = RandOdorTypes(TrialCounts(4)+1,1);
            if RightSideOdorFlag == 0
                RightSideOdor = S.GUI.OdorC;
            else
                RightSideOdor = S.GUI.OdorD;
            end            
            LeftSideOdor = 0;
            if RewardRight == 1
                OutcomeStateRight = 'RightBigReward';
                RightRewardDrops = S.GUI.RandBigDrops;
            else
                OutcomeStateRight = 'RightSmallReward';
                RightRewardDrops = S.GUI.RandSmallDrops;
            end
            OutcomeStateLeft = 'IncorrectLeft';
            LeftRewardDrops = 0;
        else
            RewardLeft = RewardTypes(TrialCounts(4)+1); RewardRight = 0;
            ChooseLeft = 'WaitForOdorLeft'; ChooseRight = 'Incorrect'; StimulusOutput = {'PWM1', 255};
            LeftSideOdorFlag = RandOdorTypes(TrialCounts(1)+1,1);
            if LeftSideOdorFlag == 0
                LeftSideOdor = S.GUI.OdorC;
            else
                LeftSideOdor = S.GUI.OdorD;
            end             
            RightSideOdor = 0;
%             OutcomeStateLeft = 'LeftCorrectChoice'; OutcomeStateRight = 'RightIncorrectChoice';
            if RewardLeft == 1
                OutcomeStateLeft = 'LeftBigReward';
                LeftRewardDrops = S.GUI.RandBigDrops;
            else
                OutcomeStateLeft = 'LeftSmallReward';
                LeftRewardDrops = S.GUI.RandSmallDrops;
            end
            OutcomeStateRight = 'IncorrectRight';
            RightRewardDrops = 0;
        end
end


sma = NewStateMatrix(); % Assemble state matrix
sma = SetCondition(sma, 1, 'Port1', 1); % Condition 1: Port 1 high (is in) (left)
sma = SetCondition(sma, 2, 'Port2', 1); % Condition 2: Port 2 high (is in) (center)
sma = SetCondition(sma, 3, 'Port3', 1); % Condition 3: Port 3 high (is in) (right)
sma = SetCondition(sma, 4, 'Port1', 0); % Condition 4: Port 1 low (is out) (left)
sma = SetCondition(sma, 5, 'Port2', 0); % Condition 5: Port 2 low (is out) (center)
sma = SetCondition(sma, 6, 'Port3', 0); % Condition 6: Port 3 low (is out) (right)

% TIMERS
sma = SetCondition(sma, 7, 'GlobalTimer1', 0);

sma = SetGlobalTimer(sma, 'TimerID', 1, 'Duration', S.GUI.OdorDelay+0.05); % ODOR DELAY

% TIMER 2 FOR MAX REWARD
if maxDrops > 1
    sma = SetGlobalTimer(sma, 'TimerID', 2, 'Duration', MaxValveTime,...
        'OnsetDelay', 0, 'Channel', 'Serial5', 'OnMessage',0, 'OffMessage', 0,...
        'Loop', maxDrops, 'SendEvents', 1, 'LoopInterval', RewardPauseTime); % timer to stay in reward state
else
    sma = SetGlobalTimer(sma, 'TimerID', 2, 'Duration', MaxValveTime,...
        'OnsetDelay', 0, 'Channel', 'Serial5', 'OnMessage', 0, 'OffMessage', 0,...
        'Loop', 0, 'SendEvents', 1, 'LoopInterval', 0); % timer to stay in reward state    
end
sma = SetGlobalCounter(sma, 2, 'GlobalTimer2_End', maxDrops);

% reward states all wait for timers to end
% set multiple timers for each outcome--one for drops, one for blanks
% get rid of reward states

% Timers for delivering reward drops
if LeftRewardDrops > 1
   sma = SetGlobalTimer(sma,'TimerID',3,'Duration',LeftValveTime,'OnsetDelay',0,...
       'Channel', 'Valve1', 'OnMessage', 1, 'OffMessage', 0, 'Loop',...
       LeftRewardDrops, 'SendEvents', 1, 'LoopInterval', RewardPauseTime,'OnsetTrigger', '10');
   sma = SetGlobalCounter(sma, 3, 'GlobalTimer3_End', LeftRewardDrops);
elseif LeftRewardDrops == 1
   sma = SetGlobalTimer(sma,'TimerID',3,'Duration',LeftValveTime,'OnsetDelay',0,...
       'Channel','Valve1','OnMessage', 1, 'OffMessage', 0, 'Loop', 0, 'SendEvents', 1,'LoopInterval',0,'OnsetTrigger', '10');
   sma = SetGlobalCounter(sma, 3, 'GlobalTimer3_End', 1);
else
   sma = SetGlobalTimer(sma,'TimerID',3,'Duration',0,'OnsetDelay',0,...
       'Channel','Valve1','OnMessage', 0, 'OffMessage', 0, 'Loop', 0, 'SendEvents', 1,'LoopInterval',0,'OnsetTrigger', '10');
   sma = SetGlobalCounter(sma, 3, 'GlobalTimer3_End', 1);
end


% sma = SetGlobalTimer(sma,'TimerID',3,'Duration',1,'OnsetDelay',0,...
%    'Channel', 'PWM1', 'OnsetValue', 255, 'OffsetValue', 0);
% sma = SetGlobalCounter(sma, 3, 'GlobalTimer3_End', 1);


if RightRewardDrops > 1
    sma = SetGlobalTimer(sma,'TimerID',4,'Duration', RightValveTime,'OnsetDelay',0,...
        'Channel', 'Valve3', 'OnMessage', 1, 'OffMessage', 0, 'Loop',...
        RightRewardDrops, 'SendEvents', 1, 'LoopInterval', RewardPauseTime,'OnsetTrigger', '10');
    sma = SetGlobalCounter(sma, 4, 'GlobalTimer4_End', RightRewardDrops);
elseif RightRewardDrops == 1
    sma = SetGlobalTimer(sma,'TimerID',4,'Duration',RightValveTime,'OnsetDelay',0,...
        'Channel', 'Valve3', 'OnMessage', 1, 'OffMessage', 0, 'Loop', 0, 'SendEvents', 1,'LoopInterval',0,'OnsetTrigger', '10');
    sma = SetGlobalCounter(sma, 4, 'GlobalTimer4_End', 1);
else
    sma = SetGlobalTimer(sma,'TimerID',4,'Duration',0,'OnsetDelay',0,...
        'Channel', 'Valve3', 'OnMessage', 0, 'OffMessage', 0, 'Loop', 0, 'SendEvents', 1,'LoopInterval',0,'OnsetTrigger', '10');
    sma = SetGlobalCounter(sma, 4, 'GlobalTimer4_End', 1);
end


% STATES
sma = AddState(sma, 'Name', 'StartTrial', ...
    'Timer', 0.2,...
    'StateChangeConditions', {'Tup', 'WaitForCenter'},...
    'OutputActions', {});
%     'OutputActions', {'DIOLicks1',1});
sma = AddState(sma, 'Name', 'WaitForCenter', ...
    'Timer', 0,...
    'StateChangeConditions', {'Port2In', 'CenterDelay','Condition2','CenterDelay'},... % test how these are different!
    'OutputActions', {'PWM2',50}); % port light on
sma = AddState(sma, 'Name', 'CenterDelay', ...
    'Timer', S.GUI.CenterDelay,...
    'StateChangeConditions', {'Tup', 'CenterOdor','Port2Out','WaitForCenter'},...
    'OutputActions', {'PWM2',50});
sma = AddState(sma, 'Name', 'CenterOdor', ...
    'Timer', S.GUI.CenterOdorTime,...
    'StateChangeConditions', {'Port2Out', 'CenterOdorOff', 'Tup', 'CenterPostOdorDelay'},...
    'OutputActions',[{'BNC2',1,'PWM2',50},RunOdor(ThisCenterOdor,0)]);
%     'OutputActions',[{'BNC2',1,'DIOLicks1',3,'PWM2',50},RunOdor(ThisCenterOdor,0)]);
sma = AddState(sma, 'Name', 'CenterOdorOff',...
    'Timer', 0,...
    'StateChangeConditions', {'Tup','WaitForCenter'},...
    'OutputActions', [{'PWM2',50},RunOdor(ThisCenterOdor,0)]);
%     'OutputActions', [{'DIOLicks1',4,'PWM2',50},RunOdor(ThisCenterOdor,0)]);
sma = AddState(sma, 'Name', 'CenterPostOdorDelay', ...
    'Timer', S.GUI.StartDelay,...
    'StateChangeConditions', {'Port2Out','WaitForCenter','Tup','GoCue'},... % is that right?
    'OutputActions', [{'PWM2',50},RunOdor(ThisCenterOdor,0)]);
% 'OutputActions', [{'DIOLicks1',4,'PWM2',50},RunOdor(ThisCenterOdor,0)]);
sma = AddState(sma, 'Name', 'GoCue', ...
    'Timer', 0.05,...
    'StateChangeConditions', {'Tup','Response'},...
    'OutputActions', {'GlobalTimerTrig', 1});
% 'OutputActions', {'GlobalTimerTrig', 1,'DIOLicks1',2});
% DOES TIMER START AT BEGINNING OR END? TIMER STARTS AT BEGINNING

% RESPONSE (CHOICE) --> MAKE SURE STAY IN SIDE FOR AT LEAST A SMALL TIME TO INDICATE CHOICE?
sma = AddState(sma, 'Name', 'Response', ...
    'Timer', S.GUI.OdorDelay,...
    'StateChangeConditions', {'Tup','GracePeriod','Port1In',ChooseLeft,'Port3In',ChooseRight},...
    'OutputActions', {}); % buzz? light?

sma = AddState(sma, 'Name', 'GracePeriod',...
    'Timer', S.GUI.GracePeriod,...
    'StateChangeConditions', {'Tup','NoChoice','Port1In',ChooseLeft,'Port3In',ChooseRight},...
    'OutputActions', {});    

% AFTER CHOICE

% LEFT
sma = AddState(sma, 'Name', 'WaitForOdorLeft', ...
    'Timer', 0,...
    'StateChangeConditions', {'GlobalTimer1_End','OdorLeft','Condition7','OdorLeft'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'OdorLeft', ...
    'Timer', S.GUI.OdorTime,...
    'StateChangeConditions', {'Tup','RewardDelayLeft'},...
    'OutputActions', [{RunOdor(LeftSideOdor,1)]);
% 'OutputActions', [{'DIOLicks1',5}, RunOdor(LeftSideOdor,1)]);
sma = AddState(sma, 'Name', 'RewardDelayLeft', ...
    'Timer', S.GUI.RewardDelay,...
    'StateChangeConditions', {'Tup','LeftPortCheck'},...
    'OutputActions', [RunOdor(LeftSideOdor,1)]);
% 'OutputActions', [{'DIOLicks1',6},RunOdor(LeftSideOdor,1)]);

% LEFT REWARD
sma = AddState(sma, 'Name', 'LeftPortCheck',...
    'Timer',0,...
    'StateChangeConditions',{'Condition4','LeftNotPresent','Condition1',OutcomeStateLeft},...
    'OutputActions',{});
sma = AddState(sma, 'Name', 'LeftBigReward', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup','OutcomeDelivery','Condition4','LeftNotPresent'},...
    'OutputActions', {'GlobalTimerTrig', 3}); %, 'GlobalTimerTrig', 3
sma = AddState(sma, 'Name', 'LeftSmallReward', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup','OutcomeDelivery','Condition4','LeftNotPresent'},...
    'OutputActions', {'GlobalTimerTrig', 3}); %, 'GlobalTimerTrig', 3
sma = AddState(sma, 'Name', 'IncorrectLeft', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup','OutcomeDelivery'},...
    'OutputActions', {'GlobalTimerTrig', 2});
sma = AddState(sma, 'Name', 'LeftNotPresent', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup','OutcomeDelivery'},...
    'OutputActions', {'GlobalTimerTrig', 2});


% CHOOSE RIGHT
sma = AddState(sma, 'Name', 'WaitForOdorRight', ...
    'Timer', 0,...
    'StateChangeConditions', {'GlobalTimer1_End','OdorRight','Condition7','OdorRight'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'OdorRight', ...
    'Timer', S.GUI.OdorTime,...
    'StateChangeConditions', {'Tup','RewardDelayRight'},...
    'OutputActions', [RunOdor(RightSideOdor,2)]);
% 'OutputActions', [{'DIOLicks1',7}, RunOdor(RightSideOdor,2)]);
sma = AddState(sma, 'Name', 'RewardDelayRight', ...
    'Timer', S.GUI.RewardDelay,...
    'StateChangeConditions', {'Tup','RightPortCheck'},...
    'OutputActions', [RunOdor(RightSideOdor,2)]);
% 'OutputActions', [{'DIOLicks1',8},RunOdor(RightSideOdor,2)]);

% RIGHT REWARD
sma = AddState(sma, 'Name', 'RightPortCheck',...
    'Timer',0,...
    'StateChangeConditions',{'Condition6','RightNotPresent','Condition3',OutcomeStateRight},...
    'OutputActions',{});
sma = AddState(sma, 'Name', 'RightBigReward', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup','OutcomeDelivery','Condition6','RightNotPresent'},...
    'OutputActions', {'GlobalTimerTrig', 4}); %, 'GlobalTimerTrig', 4
sma = AddState(sma, 'Name', 'RightSmallReward', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup','OutcomeDelivery','Condition6','RightNotPresent'},...
    'OutputActions', {'GlobalTimerTrig', 4}); %, 'GlobalTimerTrig', 4
sma = AddState(sma, 'Name', 'IncorrectRight', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup','OutcomeDelivery'},...
    'OutputActions', {'GlobalTimerTrig', 2});
sma = AddState(sma, 'Name', 'RightNotPresent', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup','OutcomeDelivery'},...
    'OutputActions', {'GlobalTimerTrig', 2});

% Waits for max drops time
sma = AddState(sma, 'Name','OutcomeDelivery','Timer',0,...
    'StateChangeConditions',{'GlobalCounter2_End','InterTrialInterval'},...
    'OutputActions',{});

% if no choice during response
sma = AddState(sma, 'Name', 'NoChoice', ...
    'Timer', 0,...
    'StateChangeConditions', {'GlobalTimer1_End', 'TimeoutOdor', 'Condition7', 'TimeoutOdor'},...
    'OutputActions', {});

% For incorrect choices (left/right on forced trials)
sma = AddState(sma, 'Name', 'Incorrect', ...
    'Timer', 0,...
    'StateChangeConditions', {'GlobalTimer1_End','TimeoutOdor','Condition7', 'TimeoutOdor'},...
    'OutputActions', {});

sma = AddState(sma, 'Name', 'TimeoutOdor', ...
    'Timer', S.GUI.OdorTime,...
    'StateChangeConditions', {'Tup','TimeoutRewardDelay'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'TimeoutRewardDelay', ...
    'Timer', S.GUI.RewardDelay,...
    'StateChangeConditions', {'Tup','TimeoutOutcome'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'TimeoutOutcome', ...
    'Timer', 0,...
    'StateChangeConditions', {'GlobalCounter2_End','InterTrialInterval'},...
    'OutputActions', {'GlobalTimerTrig', 2});

sma = AddState(sma, 'Name', 'InterTrialInterval', ...
    'Timer', S.GUI.Interval,...
    'StateChangeConditions', {'Tup', '>exit'},...
    'OutputActions', {'GlobalTimerCancel', 2});

end

%% TRIAL TYPES

function updatedtypes = UpdateTrialTypes(i,trialType,TrialTypes)
    updatedtypes = [TrialTypes(1:i); TrialTypes(i); TrialTypes(i+1:end-1)];
end

%% ODOR CONTROL

%% ODOR WITH SERIAL MESSAGES

% LoadSerialMessages('ValveModule1',{['O' 1],['C' 1],['O' 2],['C' 2],['O' 3],...
%     ['C' 3],['O' 4],['C' 4],['O' 5],['C' 5],['O' 6],['C' 6],['O' 7],['C' 7],...
%     ['O' 8],['C' 8]});
% LoadSerialMessages('ValveModule2',{['O' 1],['C' 1],['O' 2],['C' 2],['O' 3],...
%     ['C' 3],['O' 4],['C' 4],['O' 5],['C' 5],['O' 6],['C' 6],['O' 7],['C' 7],...
%     ['O' 8],['C' 8]});
% LoadSerialMessages('ValveModule3',{['O' 1],['C' 1],['O' 2],['C' 2],['O' 3],...
%     ['C' 3],['O' 4],['C' 4],['O' 5],['C' 5],['O' 6],['C' 6],['O' 7],['C' 7],...
%     ['O' 8],['C' 8]});
% 
% function OdorOutputActions = OdorOn(odorID,port)
%     switch port
%         case 0
%             cmd1 = {'ValveModule1',1}; % center control  
%             cmd2 = {'ValveModule1',3};
%             switch odorID
%                 case 0
%                     cmd3 = {'ValveModule2',1};
%                     cmd4 = {'ValveModule3',1};
%                 case 1
%                     cmd3 = {'ValveModule2',3};
%                     cmd4 = {'ValveModule3',3};
%                 case 2
%                     cmd3 = {'ValveModule2',5};
%                     cmd4 = {'ValveModule3',5};                    
%                 case 3
%                     cmd3 = {'ValveModule2',7};
%                     cmd4 = {'ValveModule3',7};                    
%             end
%         case 1 % LEFT
%             cmd1 = {'ValveModule1',5}; % left control
%             cmd2 = {'ValveModule1',7}; % left control
%             switch odorID
%                 case 0
%                     cmd3 = {'ValveModule2',9};
%                     cmd4 = {'ValveModule3',9};
%                 case 1
%                     cmd3 = {'ValveModule2',11};
%                     cmd4 = {'ValveModule3',11};
%                 case 2
%                     cmd3 = {'ValveModule2',13};
%                     cmd4 = {'ValveModule3',13};                    
%                 case 3
%                     cmd3 = {'ValveModule2',15};
%                     cmd4 = {'ValveModule3',15};                    
%             end            
%         case 2 % RIGHT
%             cmd1 = {'ValveModule1',9}; % right control
%             cmd2 = {'ValveModule1',11}; % right control
%             switch odorID
%                 case 0
%                     cmd3 = {'ValveModule2',9};
%                     cmd4 = {'ValveModule3',9};
%                 case 1
%                     cmd3 = {'ValveModule2',11};
%                     cmd4 = {'ValveModule3',11};
%                 case 2
%                     cmd3 = {'ValveModule2',13};
%                     cmd4 = {'ValveModule3',13};                    
%                 case 3
%                     cmd3 = {'ValveModule2',15};
%                     cmd4 = {'ValveModule3',15};                    
%             end   
%     end
%     OdorOutputActions = [cmd1,cmd2,cmd3,cmd4];    
% end
% 
% function OdorOutputActions = OdorOn(odorID,port)
%     switch port
%         case 0
%             cmd1 = {'ValveModule1',2}; % center control  
%             cmd2 = {'ValveModule1',4};
%             switch odorID
%                 case 0
%                     cmd3 = {'ValveModule2',2};
%                     cmd4 = {'ValveModule3',2};
%                 case 1
%                     cmd3 = {'ValveModule2',4};
%                     cmd4 = {'ValveModule3',4};
%                 case 2
%                     cmd3 = {'ValveModule2',6};
%                     cmd4 = {'ValveModule3',6};                    
%                 case 3
%                     cmd3 = {'ValveModule2',8};
%                     cmd4 = {'ValveModule3',8};                    
%             end
%         case 1 % LEFT
%             cmd1 = {'ValveModule1',6}; % left control
%             cmd2 = {'ValveModule1',8}; % left control
%             switch odorID
%                 case 0
%                     cmd3 = {'ValveModule2',10};
%                     cmd4 = {'ValveModule3',10};
%                 case 1
%                     cmd3 = {'ValveModule2',12};
%                     cmd4 = {'ValveModule3',12};
%                 case 2
%                     cmd3 = {'ValveModule2',14};
%                     cmd4 = {'ValveModule3',14};                    
%                 case 3
%                     cmd3 = {'ValveModule2',16};
%                     cmd4 = {'ValveModule3',16};                    
%             end            
%         case 2 % RIGHT
%             cmd1 = {'ValveModule1',10}; % right control
%             cmd2 = {'ValveModule1',12}; % right control
%             switch odorID
%                 case 0
%                     cmd3 = {'ValveModule2',10};
%                     cmd4 = {'ValveModule3',10};
%                 case 1
%                     cmd3 = {'ValveModule2',12};
%                     cmd4 = {'ValveModule3',12};
%                 case 2
%                     cmd3 = {'ValveModule2',14};
%                     cmd4 = {'ValveModule3',14};                    
%                 case 3
%                     cmd3 = {'ValveModule2',16};
%                     cmd4 = {'ValveModule3',16};                    
%             end   
%     end
%     OdorOutputActions = [cmd1,cmd2,cmd3,cmd4];    
% end

%% GENERAL ODOR

function OdorOutputActions = RunOdor(odorID,port)
    switch port
        case 0
            cmd1 = {'ValveModule1',1}; % center control  
            switch odorID
                case 0
                    cmd2 = {'ValveModule2',1};
                    cmd3 = {'ValveModule3',1};
                case 1
                    cmd2 = {'ValveModule2',2};
                    cmd3 = {'ValveModule3',2};
                case 2
                    cmd2 = {'ValveModule2',3};
                    cmd3 = {'ValveModule3',3};                    
                case 3
                    cmd2 = {'ValveModule2',4};
                    cmd3 = {'ValveModule3',4};                    
            end
        case 1 % LEFT
            cmd1 = {'ValveModule1',2}; % left control
            switch odorID
                case 0
                    cmd2 = {'ValveModule2',5};
                    cmd3 = {'ValveModule3',5};
                case 1
                    cmd2 = {'ValveModule2',6};
                    cmd3 = {'ValveModule3',6};
                case 2
                    cmd2 = {'ValveModule2',7};
                    cmd3 = {'ValveModule3',7};                    
                case 3
                    cmd2 = {'ValveModule2',8};
                    cmd3 = {'ValveModule3',8};                    
            end            
        case 2 % RIGHT
            cmd1 = {'ValveModule1',3}; % right control
            switch odorID
                case 0
                    cmd2 = {'ValveModule2',5};
                    cmd3 = {'ValveModule3',5};
                case 1
                    cmd2 = {'ValveModule2',6};
                    cmd3 = {'ValveModule3',6};
                case 2
                    cmd2 = {'ValveModule2',7};
                    cmd3 = {'ValveModule3',7};                    
                case 3
                    cmd2 = {'ValveModule2',8};
                    cmd3 = {'ValveModule3',8};
            end
    end
    OdorOutputActions = [cmd1,cmd2,cmd3];
end


%% OUTCOMES

function [Outcome, rewardAmount] = UpdateOutcome(trialType,RewardLeft,RewardRight,Data,infoSide,S)
    global BpodSystem;    
    x = Data.nTrials;
    infoBigReward = S.GUI.InfoBigDrops*4;
    infoSmallReward = S.GUI.InfoSmallDrops*4;
    randBigReward = S.GUI.RandBigDrops*4;
    randSmallReward = S.GUI.RandSmallDrops*4;
    rewardAmount = 0;
    
    if infoSide == 0
        switch trialType
            case 1
                if ~isnan(Data.RawEvents.Trial{x}.States.NoChoice(1))
                    Outcome = 1; % choice no choice
                elseif ~isnan(Data.RawEvents.Trial{x}.States.WaitForOdorLeft(1))
                    if RewardLeft == 1
                        if ~isnan(Data.RawEvents.Trial{x}.States.LeftBigReward(1))
                            Outcome = 2; % choice info big
                            rewardAmount = infoBigReward;
                        else
                            Outcome = 3; % choice info big NP
                        end
                    else
                        if ~isnan(Data.RawEvents.Trial{x}.States.LeftSmallReward(1))
                            Outcome = 4; % choice info small
                            rewardAmount = infoSmallReward;
                        else
                            Outcome = 5; % choice info small NP
                        end
                    end
                else
                   if RewardRight == 1
                        if ~isnan(Data.RawEvents.Trial{x}.States.RightBigReward(1))
                            Outcome = 6; % choice rand big
                            rewardAmount = randBigReward;
                        else
                            Outcome = 7; % choice rand big NP
                        end                       
                   else
                        if ~isnan(Data.RawEvents.Trial{x}.States.RightSmallReward(1))
                            Outcome = 8; % choice rand small
                            rewardAmount = randSmallReward;
                        else
                            Outcome = 9; % choice rand small NP
                        end                       
                   end
                end
                
            case 2
                if ~isnan(Data.RawEvents.Trial{x}.States.NoChoice(1))
                    Outcome = 10; % info no choice
                elseif ~isnan(Data.RawEvents.Trial{x}.States.WaitForOdorLeft(1))
                    if RewardLeft == 1
                        if ~isnan(Data.RawEvents.Trial{x}.States.LeftBigReward(1))
                            Outcome = 11; % info big
                            rewardAmount = infoBigReward;
                        else
                            Outcome = 12; % info big NP
                        end
                    else
                        if ~isnan(Data.RawEvents.Trial{x}.States.LeftSmallReward(1))
                            Outcome = 13; % info small
                            rewardAmount = infoSmallReward;
                        else
                            Outcome = 14; % info small NP
                        end
                    end
                else
                    Outcome = 15; % info incorrect
                end
                
            case 3
                if ~isnan(Data.RawEvents.Trial{x}.States.NoChoice(1))
                    Outcome = 16; % rand no choice
                elseif ~isnan(Data.RawEvents.Trial{x}.States.WaitForOdorRight(1))
                    if RewardRight == 1
                        if ~isnan(Data.RawEvents.Trial{x}.States.RightBigReward(1))
                            Outcome = 17; % rand big
                            rewardAmount = randBigReward;
                        else
                            Outcome = 18; % rand big NP
                        end
                    else
                        if ~isnan(Data.RawEvents.Trial{x}.States.RightSmallReward(1))
                            Outcome = 19; % rand small
                            rewardAmount = randSmallReward;
                        else
                            Outcome = 20; % rand small NP
                        end
                    end
                else
                    Outcome = 21; % rand incorrect
                end
        end
        
    else
        switch trialType
            case 1
                if ~isnan(Data.RawEvents.Trial{x}.States.NoChoice(1))
                    Outcome = 1; % choice no choice
                elseif ~isnan(Data.RawEvents.Trial{x}.States.WaitForOdorRight(1))
                    if RewardRight == 1
                        if ~isnan(Data.RawEvents.Trial{x}.States.RightBigReward(1))
                            Outcome = 2; % choice info big
                            rewardAmount = infoBigReward;
                        else
                            Outcome = 3; % choice info big NP
                        end
                    else
                        if ~isnan(Data.RawEvents.Trial{x}.States.RightSmallReward(1))
                            Outcome = 4; % choice info small
                            rewardAmount = infoSmallReward;
                        else
                            Outcome = 5; % choice info small NP
                        end
                    end
                else
                   if RewardLeft == 1
                        if ~isnan(Data.RawEvents.Trial{x}.States.LeftBigReward(1))
                            Outcome = 6; % choice rand big
                            rewardAmount = randBigReward;
                        else
                            Outcome = 7; % choice rand big NP
                        end                       
                   else
                        if ~isnan(Data.RawEvents.Trial{x}.States.LeftSmallReward(1))
                            Outcome = 8; % choice rand small
                            rewardAmount = randSmallReward;
                        else
                            Outcome = 9; % choice rand small NP
                        end                       
                   end
                end
                
            case 2
                if ~isnan(Data.RawEvents.Trial{x}.States.NoChoice(1))
                    Outcome = 10; % info no choice
                elseif ~isnan(Data.RawEvents.Trial{x}.States.WaitForOdorRight(1))
                    if RewardRight == 1
                        if ~isnan(Data.RawEvents.Trial{x}.States.RightBigReward(1))
                            Outcome = 11; % info big
                            rewardAmount = infoBigReward;
                        else
                            Outcome = 12; % info big NP
                        end
                    else
                        if ~isnan(Data.RawEvents.Trial{x}.States.RightSmallReward(1))
                            Outcome = 13; % info small
                            rewardAmount = infoSmallReward;
                        else
                            Outcome = 14; % info small NP
                        end
                    end
                else
                    Outcome = 15; % info incorrect
                end
                
            case 3
                if ~isnan(Data.RawEvents.Trial{x}.States.NoChoice(1))
                    Outcome = 16; % rand no choice
                elseif ~isnan(Data.RawEvents.Trial{x}.States.WaitForOdorLeft(1))
                    if RewardLeft == 1
                        if ~isnan(Data.RawEvents.Trial{x}.States.LeftBigReward(1))
                            Outcome = 17; % rand big
                            rewardAmount = randBigReward;
                        else
                            Outcome = 18; % rand big NP
                        end
                    else
                        if ~isnan(Data.RawEvents.Trial{x}.States.LeftSmallReward(1))
                            Outcome = 19; % rand small
                            rewardAmount = randSmallReward;
                        else
                            Outcome = 20; % rand small NP
                        end
                    end
                else
                    Outcome = 21; % rand incorrect
                end
        end            
    end
end


%% COUNTS

% PlotOutcomes = type: choice, info, rand. outcome: NaN, nochoice(2) incorrect (3), not present(-1), correctinfo(1), correct rand(0)

function [newTrialCounts,newPlotOutcomes] = UpdateCounts(trialType, Data, TrialCounts, PlotOutcomes, infoSide)
    global BpodSystem;
    x = Data.nTrials;
    newTrialCounts = TrialCounts;
    newPlotOutcomes = PlotOutcomes;
    if infoSide == 0
        switch trialType
            case 1
                if ~isnan(Data.RawEvents.Trial{x}.States.WaitForOdorLeft(1))
                    newTrialCounts(1) = TrialCounts(1) + 1; % infochoice
                    newPlotOutcomes(x) = 1;
                elseif ~isnan(Data.RawEvents.Trial{x}.States.WaitForOdorRight(1))
                    newTrialCounts(2) = TrialCounts(2) + 1; % randChoice
                    newPlotOutcomes(x) = 0;
                end
            case 2
                if sum(~isnan([Data.RawEvents.Trial{x}.States.WaitForOdorLeft(1) Data.RawEvents.Trial{x}.States.Incorrect(1)]))
                    newTrialCounts(3) = TrialCounts(3) + 1; % infoforced
                    newPlotOutcomes(x) = 1;
                end
            case 3
                if sum(~isnan([Data.RawEvents.Trial{x}.States.WaitForOdorRight(1) Data.RawEvents.Trial{x}.States.Incorrect(1)]))
                    newTrialCounts(4) = TrialCounts(4) + 1; % randforced
                    newPlotOutcomes(x) = 0;
                end
        end
    else
        switch trialType
            case 1
                if ~isnan(Data.RawEvents.Trial{x}.States.WaitForOdorLeft(1))
                    newTrialCounts(2) = TrialCounts(2) + 1; % randChoice
                    newPlotOutcomes(x) = 0;
                elseif ~isnan(Data.RawEvents.Trial{x}.States.WaitForOdorRight(1))
                    newTrialCounts(1) = TrialCounts(1) + 1; % infochoice
                    newPlotOutcomes(x) = 1;
                end
            case 2
                if sum(~isnan([Data.RawEvents.Trial{x}.States.WaitForOdorRight(1) Data.RawEvents.Trial{x}.States.Incorrect(1)]))
                    newTrialCounts(3) = TrialCounts(3) + 1; % infoforced
                    newPlotOutcomes(x) = 1;
                end
            case 3
                if sum(~isnan([Data.RawEvents.Trial{x}.States.WaitForOdorLeft(1) Data.RawEvents.Trial{x}.States.Incorrect(1)]))
                    newTrialCounts(4) = TrialCounts(4) + 1; % randforced
                    newPlotOutcomes(x) = 0;
                end          
        end            
    end
    if sum(~isnan([Data.RawEvents.Trial{x}.States.LeftNotPresent(1) Data.RawEvents.Trial{x}.States.RightNotPresent(1)]))
        newPlotOutcomes(x) = -1;
    elseif ~isnan(Data.RawEvents.Trial{x}.States.Incorrect(1))
        newPlotOutcomes(x) = 3;
    elseif ~isnan(Data.RawEvents.Trial{x}.States.NoChoice(1))
        newPlotOutcomes(x) = 2;
    end
end
        
%% TRIAL EVENT PLOTTING

function state_colors = getStateColors(thisInfoSide)
    if thisInfoSide == 0
        state_colors = struct( ...
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
            'OdorLeft',[128	0 128]./255,...
            'RewardDelayLeft',[216 191 216]./255,...
            'LeftPortCheck',[216 191 216]./255,...
            'LeftBigReward',[0 1 0],...
            'LeftSmallReward',[1 0 1],...
            'IncorrectLeft',[0 0 0],...
            'LeftNotPresent',[1 1 1],...
            'WaitForOdorRight',[1 0.8 0],... % 1 0.8 0 [255 228 189]./255
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
            'InterTrialInterval',[0.8 0.8 0.8]);
    else
        state_colors = struct( ...
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
            'OdorLeft',[255 140 0]./255,...
            'RewardDelayLeft',[1 0.8 0],...
            'LeftPortCheck',[1 0.8 0],...
            'LeftBigReward',[0 1 0],...
            'LeftSmallReward',[1 0 1],...
            'IncorrectLeft',[0 0 0],...
            'LeftNotPresent',[1 1 1],...
            'WaitForOdorRight',[216 191 216]./255,...
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
            'InterTrialInterval',[0.8 0.8 0.8]);        
    end
end


