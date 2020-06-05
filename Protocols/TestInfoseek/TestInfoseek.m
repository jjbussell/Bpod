% GRACE PERIOD: additional time after response period expires. mouse can
% still choose then goes immediately to odor-->messes up timing!

% OMG BEEPING TIMER!!!

% HOUSE LIGHTS

% ERROR TRIALS / NOT PRESENT

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
function TestInfoSeek


global BpodSystem

%% Create trial manager object
TrialManager = TrialManagerObject;

%% Define parameters

S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.SessionTrials = 1000;
    S.GUI.TrialTypes = 5;
    S.GUI.InfoSide = 0;
    S.GUI.InfoOdor = 3;
    S.GUI.RandOdor = 2;
    S.GUI.ChoiceOdor = 1;
    S.GUI.OdorA = 3;
    S.GUI.OdorB = 2;
    S.GUI.OdorC = 1;
    S.GUI.OdorD = 0;
    S.GUI.CenterDelay = 0;
    S.GUI.CenterOdorTime = 0.5;
    S.GUI.StartDelay = 0;
    S.GUI.OdorDelay = 2;
    S.GUI.OdorTime = 0.2;
    S.GUI.RewardDelay = 1;
    S.GUI.InfoBigDrops = 4;
    S.GUI.InfoSmallDrops = 1;
    S.GUI.RandBigDrops = 4;
    S.GUI.RandSmallDrops = 1;
    S.GUI.InfoRewardProb = 0.5;
    S.GUI.RandRewardProb = 0.5;
    S.GUI.GracePeriod = 0; 
    S.GUI.Interval = 1; 
    S.GUI.OptoFlag = 0;
    S.GUI.OptoType = 0;
    S.GUI.ImageFlag = 0;
    S.GUI.ImageType = 0;
end


% Put code here to set session params interactively?? i.e. via GUI

%% HOW TO CHECK WHAT MODULES ARE THERE? (i.e. right teensys?)

%% VALVE AND OTHER PINS / NON-BPOD HARDWARD

% {'DIOLicks', [N S]} where N is pin number (19-23) and S is the new logic state (0 or 1 for 0V or 3.3V)

latchValves = [3 4 5 6 7 8 9 10]; % 1:4 go to left, 5:8 go to right!
latchModule = 'DIOLicks1';
teensyModule = 'DIOLicks1';
LEDPin = 11;

% MINISCOPE
% miniscope has 4 I/O BNC Pins, and scope sync and trig
% scope sync connects to Bpod IN BNC
% scope trig to Bpod OUT BNC
% other Bpod out BNC at center odor start

% for side odor on and reward on
syncPins = [12, 13];

% 'DIOLicks1',[254 1]
% 'DIOLicks1',[253 1],


%% Define trial types

% trial types depend on trial types available!!

MaxTrials = S.GUI.SessionTrials;

typesAvailable = S.GUI.TrialTypes;

blockSize = 12;
typeBlockSize = 8;
choicePercent = 0; infoPercent = 0; randPercent = 0;

switch typesAvailable % set trial type arrays based on TrialTypes
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

choiceBlockSize = round(choicePercent * blockSize);
infoBlockSize = round(infoPercent * blockSize);
randBlockSize = round(randPercent * blockSize);

blockToShuffle = zeros(12,1);

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
TrialTypes=TrialTypes(1:MaxTrials);

BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.

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
       RandOdorTypes(1:typeBlockSize,4) = randOdorBlock'; 
    else
        RandOdorTypes((n-1)*typeBlockSize+1:n*typeBlockSize,4) = randOdorBlock';
    end
end

% Trial types (rewards) to pull from
RewardTypes = RewardTypes(1:MaxTrials,:);

% Rand Odors to pull from
RandOdorTypes = RandOdorTypes(1:MaxTrials,1);

%% Initialize plots

% BpodSystem.ProtocolFigures.OutcomePlotFig = figure('Position', [50 540 1000 250],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
% BpodSystem.GUIHandles.OutcomePlot = axes('Position', [.075 .35 .89 .6]);
% TrialTypeOutcomePlot(BpodSystem.GUIHandles.OutcomePlot,'init',TrialTypes); %trial choice types
BpodNotebook('init');
BpodParameterGUI('init', S); % Initialize parameter GUI plugin   
PokesPlotInfo('init', getStateColors, getPokeColors);


%% SET INFO SIDE

infoSide = S.GUI.InfoSide;

%% SET ODOR SIDES (LATCH VALVES) AND ODOR IDS
% 
% if infoSide == 0
%     for i = 1:4
%         ModuleWrite(latchModule,[latchValves(i) 1]);
%         pause(100/1000);
%         ModuleWrite(latchModule,[latchValves(i) 0]);
%         pause(100/1000);
%     end
% else
%     for i = 5:8
%         ModuleWrite(latchModule,[latchValves(i) 1]);
%         pause(100/1000);
%         ModuleWrite(latchModule,[latchValves(i) 0]);
%         pause(100/1000);
%     end
% end

%% SET INITIAL TYPE COUNTS

TrialCounts = [0,0,0,0];

%% INITIALIZE STATE MACHINE

sma = PrepareStateMachine(S, TrialTypes, TrialCounts, infoSide, RewardTypes, RandOdorTypes, 1, []); % Prepare state machine for trial 1 with empty "current events" variable
TrialManager.startTrial(sma); % Sends & starts running first trial's state machine. A MATLAB timer object updates the 
                              % console UI, while code below proceeds in parallel.
                              
%% START SCOPE RECORDING? HOW TO SET TIMER? MOVE THIS INTO TRIAL START??
                              
%% MAIN TRIAL LOOP

for currentTrial = 1:MaxTrials
    currentTrialEvents = TrialManager.getCurrentEvents({'InterTrialInterval'}); 
                                       % Hangs here until Bpod enters one of the listed trigger states, 
                                       % then returns current trial's states visited + events captured to this point
                                       
    % CODE FOR PULLING IN SCOPE SYNC SIGNAL GOES HERE??
    
    if BpodSystem.Status.BeingUsed == 0; return; end % If user hit console "stop" button, end session 
    [sma, S] = PrepareStateMachine(S, TrialTypes, TrialCounts, infoSide, RewardTypes, RandOdorTypes, currentTrial+1, currentTrialEvents); % Prepare next state machine.
    % Since PrepareStateMachine is a function with a separate workspace, pass any local variables needed to make 
    % the state machine as fields of settings struct S e.g. S.learningRate = 0.2.
    SendStateMachine(sma, 'RunASAP'); % With TrialManager, you can send the next trial's state machine while the current trial is ongoing
    RawEvents = TrialManager.getTrialData; % Hangs here until trial is over, then retrieves full trial's raw data
    if BpodSystem.Status.BeingUsed == 0; return; end % If user hit console "stop" button, end session 
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    TrialManager.startTrial(); % Start processing the next trial's events (call with no argument since SM was already sent)
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned from last trial, update plots and save data
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data = BpodNotebook('sync', BpodSystem.Data); % Sync with Bpod notebook plugin
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial); % Adds the trial type of the current trial to data
        PokesPlotInfo('update');
%         UpdateOutcomePlot(TrialTypes, BpodSystem.Data);
        TrialCounts = UpdateTypeOutcomes(TrialTypes, BpodSystem.Data, TrialCounts, infoSide);
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end
end

%% SHUT DOWN
% NEED CODE FOR TURNING OFF SCOPE AND SHUTTING DOWN HERE!

end % end of protocol main function

%% PREPARE STATE MACHINE

function [sma, S] = PrepareStateMachine(S, TrialTypes, TrialCounts, infoSide, RewardTypes, RandOdorTypes, currentTrial, currentTrialEvents)

S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin

% Water parameters
R = GetValveTimes(4, [1 3]); LeftValveTime = R(1); RightValveTime = R(2); % Update reward amounts
MaxValveTime = max(R);
maxDrops = max([S.GUI.InfoBigDrops,S.GUI.InfoSmallDrops,S.GUI.RandBigDrops,S.GUI.RandSmallDrops]);
RewardPauseTime = 0.05;

% LeftValveTime = 2; RightValveTime = 2;

% Set trialParams (reward and odor)
switch TrialTypes(currentTrial) % Determine trial-specific state matrix fields
    % Stimulus output will change to CENTER ODOR
    case 1 % CHOICE
%         OutcomeStateLeft = 'LeftReward'; OutcomeStateRight = 'RightReward';
        ChooseLeft = 'WaitForOdorLeft'; ChooseRight = 'WaitForOdorRight'; StimulusOutput = {'PWM1', 255,'PWM3', 255};
        CenterOdor = S.GUI.ChoiceOdor;
        if infoSide == 0            
            RewardLeft = RewardTypes(TrialCounts(1)+1,1); RewardRight = RewardTypes(TrialCounts(2)+1,2);
            RightSideOdor = RandOdorTypes(TrialCounts(1)+1,1);
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
            LeftSideOdor = RandOdorTypes(TrialCounts(1)+1,1);
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
        if infoSide == 0
            RewardLeft = RewardTypes(TrialCounts(3)+1,3); RewardRight = 0;
            ChooseLeft = 'WaitForOdorLeft'; ChooseRight = 'Incorrect'; StimulusOutput = {'PWM1', 255};
            RightSideOdor = 5;
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
            LeftSideOdor = 5;
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
    case 3 % RAND LEFT
%         ChooseLeft = 'Incorrect'; ChooseRight = 'WaitForOdorRight'; StimulusOutput = {'PWM3', 255}; OutcomeStateLeft = 'LeftReward'; OutcomeStateRight = 'RightReward';
        if infoSide == 0
            RewardLeft = 0; RewardRight = RewardTypes(TrialCounts(4)+1,4);
            ChooseLeft = 'Incorrect'; ChooseRight = 'WaitForOdorRight'; StimulusOutput = {'PWM3', 255};
%             OutcomeStateLeft = 'LeftInCorrectChoice'; OutcomeStateRight = 'RightCorrectChoice';
            RightSideOdor = RandOdorTypes(TrialCounts(1)+1,1);
            LeftSideOdor = 5;
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
            LeftSideOdor = RandOdorTypes(TrialCounts(1)+1,1);
            RightSideOdor = 5;
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
if maxDrops > 1
    sma = SetGlobalTimer(sma, 'TimerID', 2, 'Duration', MaxValveTime,...
        'OnsetDelay', 0, 'Channel', 'PWM4', 'OnMessage', 0, 'OffMessage', 0,...
        'Loop', maxDrops, 'SendEvents', 1, 'LoopInterval', RewardPauseTime); % timer to stay in reward state
else
    sma = SetGlobalTimer(sma, 'TimerID', 2, 'Duration', MaxValveTime,...
        'OnsetDelay', 0, 'Channel', 'PWM4', 'OnMessage', 0, 'OffMessage', 0,...
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
    'OutputActions', {}); % {'Buzzer',1,'LED',1}buzzer on, light on (configure teensy, consider lighting center port)
sma = AddState(sma, 'Name', 'WaitForCenter', ...
    'Timer', 0,...
    'StateChangeConditions', {'Port2In', 'CenterDelay','Condition2','CenterDelay'},... % test how these are different!
    'OutputActions', {'PWM2',255}); % port light on
sma = AddState(sma, 'Name', 'CenterDelay', ...
    'Timer', S.GUI.CenterDelay,...
    'StateChangeConditions', {'Tup', 'CenterOdor','Port2Out','WaitForCenter'},...
    'OutputActions', {}); 
sma = AddState(sma, 'Name', 'CenterOdor', ...
    'Timer', S.GUI.CenterOdorTime,...
    'StateChangeConditions', {'Port2Out', 'WaitForCenter', 'Tup', 'CenterPostOdorDelay'},...
    'OutputActions', [{'SoftCode', 1,'PWM2',100}, turnOnCenterOdor(0)]); % center odor on NOTE VALVE FOR WATER
sma = AddState(sma, 'Name', 'CenterPostOdorDelay', ...
    'Timer', S.GUI.StartDelay,...
    'StateChangeConditions', {'Port2Out','WaitForCenter','Tup','GoCue'},... % is that right?
    'OutputActions', {});
sma = AddState(sma, 'Name', 'GoCue', ...
    'Timer', 0.05,...
    'StateChangeConditions', {'Tup','Response','Port2Out','WaitForCenter'},...
    'OutputActions', {'GlobalTimerTrig', 1}); % DOES TIMER START AT BEGINNING OR END? TIMER STARTS AT BEGINNING

% RESPONSE (CHOICE) --> MAKE SURE STAY IN SIDE FOR AT LEAST A SMALL TIME TO INDICATE CHOICE?
sma = AddState(sma, 'Name', 'Response', ...
    'Timer', S.GUI.OdorDelay,...
    'StateChangeConditions', {'Tup','NoChoice','Port1In',ChooseLeft,'Port3In',ChooseRight},...
    'OutputActions', StimulusOutput); % buzz? light?

% AFTER CHOICE

% LEFT
sma = AddState(sma, 'Name', 'WaitForOdorLeft', ...
    'Timer', 0,...
    'StateChangeConditions', {'GlobalTimer1_End','OdorLeft'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'OdorLeft', ...
    'Timer', S.GUI.OdorTime,...
    'StateChangeConditions', {'Tup','RewardDelayLeft'},...
    'OutputActions', [{'SoftCode', 2, 'PWM1',255}, turnOnSideOdor(LeftSideOdor,'left')]);
sma = AddState(sma, 'Name', 'RewardDelayLeft', ...
    'Timer', S.GUI.RewardDelay,...
    'StateChangeConditions', {'Tup',OutcomeStateLeft},...
    'OutputActions', {});

% LEFT REWARD
sma = AddState(sma, 'Name', 'LeftBigReward', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup','OutcomeDelivery'},...
    'OutputActions', {'GlobalTimerTrig', 3}); %, 'GlobalTimerTrig', 3
sma = AddState(sma, 'Name', 'LeftSmallReward', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup','OutcomeDelivery'},...
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
    'StateChangeConditions', {'GlobalTimer1_End','OdorRight'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'OdorRight', ...
    'Timer', S.GUI.OdorTime,...
    'StateChangeConditions', {'Tup','RewardDelayRight'},...
    'OutputActions', [{'SoftCode', 2, 'PWM3',255}, turnOnSideOdor(RightSideOdor,'right')]);
sma = AddState(sma, 'Name', 'RewardDelayRight', ...
    'Timer', S.GUI.RewardDelay,...
    'StateChangeConditions', {'Tup',OutcomeStateRight},...
    'OutputActions', {});

% RIGHT REWARD
sma = AddState(sma, 'Name', 'RightBigReward', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup','OutcomeDelivery'},...
    'OutputActions', {'GlobalTimerTrig', 4}); %, 'GlobalTimerTrig', 4
sma = AddState(sma, 'Name', 'RightSmallReward', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup','OutcomeDelivery'},...
    'OutputActions', {'GlobalTimerTrig', 4}); %, 'GlobalTimerTrig', 4
sma = AddState(sma, 'Name', 'IncorrectRight', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup','OutcomeDelivery'},...
    'OutputActions', {'GlobalTimerTrig', 2});
sma = AddState(sma, 'Name', 'RightNotPresent', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup','OutcomeDelivery'},...
    'OutputActions', {'GlobalTimerTrig', 2});


% sma = AddState(sma, 'Name','OutcomeDelivery','Timer',0,...
%     'StateChangeConditions',{'GlobalTimer3_End', 'OutcomeTimeout', 'GlobalTimer4_End','OutcomeTimeout'},...
%     'OutputActions',{});
% sma = AddState(sma, 'Name','OutcomeTimeout','Timer',0,...
%     'StateChangeConditions',{'GlobalCounter2_End','InterTrialInterval'},...
%     'OutputActions',{});

sma = AddState(sma, 'Name','OutcomeDelivery','Timer',0,...
    'StateChangeConditions',{'GlobalCounter2_End','InterTrialInterval'},...
    'OutputActions',{});

% add in max drops? no, put this until time for reward and then send to
% dummy reward states (timeout) OR add in time to cycle states?
sma = AddState(sma, 'Name', 'NoChoice', ...
    'Timer', 0,...
    'StateChangeConditions', {'GlobalTimer1_End', 'TimeoutOdor', 'Condition7', 'TimeoutOdor'},...
    'OutputActions', {});

% For incorrect choices (left/right on forced trials)
sma = AddState(sma, 'Name', 'Incorrect', ...
    'Timer', 0,...
    'StateChangeConditions', {'GlobalTimer1_End','TimeoutOdor'},...
    'OutputActions', {});
% add in state transition time or send to dummy reward states
sma = AddState(sma, 'Name', 'TimeoutOdor', ...
    'Timer', S.GUI.OdorTime,...
    'StateChangeConditions', {'Tup','TimeoutRewardDelay'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'TimeoutRewardDelay', ...
    'Timer', S.GUI.RewardDelay,...
    'StateChangeConditions', {'Tup','TimeoutReward'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'TimeoutReward', ...
    'Timer', 0,...
    'StateChangeConditions', {'GlobalCounter2_End','InterTrialInterval'},...
    'OutputActions', {'GlobalTimerTrig', 2});

sma = AddState(sma, 'Name', 'InterTrialInterval', ...
    'Timer', S.GUI.Interval,...
    'StateChangeConditions', {'Tup', '>exit'},...
    'OutputActions', {'GlobalTimerCancel', 2});

end

%% ODOR CONTROL

%% CENTER ODOR

function CenterOdorOutputActions = turnOnCenterOdor(odorID)
    switch odorID
        case 0
            cmd1 = {'ValveModule1',1}; % before center odor
            cmd2 = {'ValveModule1',2}; % after center odor
            cmd3 = {'ValveModule1',3}; % before center control
            cmd4 = {'ValveModule1',4}; % after center control
        case 1
            cmd1 = {'ValveModule1',1}; % before center odor
            cmd2 = {'ValveModule1',2}; % after center odor
            cmd3 = {'ValveModule1',3}; % before center control
            cmd4 = {'ValveModule1',4}; % after center control
        case 2
            cmd1 = {'ValveModule1',1}; % before center odor
            cmd2 = {'ValveModule1',2}; % after center odor
            cmd3 = {'ValveModule1',3}; % before center control
            cmd4 = {'ValveModule1',4}; % after center control                        
        case 3
            cmd1 = {'ValveModule1',1}; % before center odor
            cmd2 = {'ValveModule1',2}; % after center odor
            cmd3 = {'ValveModule1',3}; % before center control
            cmd4 = {'ValveModule1',4}; % after center control            
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

%% OUTCOME PLOT

function UpdateOutcomePlot(TrialTypes, Data)
global BpodSystem
Outcomes = zeros(1,Data.nTrials);
for x = 1:Data.nTrials
    if ~isnan(Data.RawEvents.Trial{x}.States.LeftBigReward(1))
        Outcomes(x) = 1;
    elseif ~isnan(Data.RawEvents.Trial{x}.States.LeftSmallReward(1))
        Outcomes(x) = 2;
    elseif ~isnan(Data.RawEvents.Trial{x}.States.RightBigReward(1))
        Outcomes(x) = 1;
    elseif ~isnan(Data.RawEvents.Trial{x}.States.RightSmallReward(1))
        Outcomes(x) = 2;        
    else
        Outcomes(x) = 0;
    end
end
TrialTypeOutcomePlot(BpodSystem.GUIHandles.OutcomePlot,'update',Data.nTrials+1,TrialTypes,Outcomes);
end


%% KEEP TRACK OF CHOICES FOR REWARD BLOCKS

function newTrialCounts = UpdateTypeOutcomes(TrialTypes, Data, TrialCounts, infoSide)
    global BpodSystem;
    x = Data.nTrials;
    newTrialCounts = TrialCounts;
    if infoSide == 0
        switch TrialTypes(x)
            case 1
                if sum(~isnan([Data.RawEvents.Trial{x}.States.LeftBigReward(1) Data.RawEvents.Trial{x}.States.LeftSmallReward(1)]))
                    newTrialCounts(1) = TrialCounts(1) + 1; % infochoice
                elseif sum(~isnan([Data.RawEvents.Trial{x}.States.RightBigReward(1) Data.RawEvents.Trial{x}.States.RightSmallReward(1)]))
                    newTrialCounts(2) = TrialCounts(2) + 1; % randChoice
                end
            case 2
                if sum(~isnan([Data.RawEvents.Trial{x}.States.LeftBigReward(1) Data.RawEvents.Trial{x}.States.LeftSmallReward(1)]))
                    newTrialCounts(3) = TrialCounts(3) + 1; % infoforced
                end
            case 3
                if sum(~isnan([Data.RawEvents.Trial{x}.States.RightBigReward(1) Data.RawEvents.Trial{x}.States.RightSmallReward(1)]))
                    newTrialCounts(4) = TrialCounts(4) + 1; % randforced
                end          
        end
    else
        switch TrialTypes(x)
            case 1
                if sum(~isnan([Data.RawEvents.Trial{x}.States.LeftBigReward(1) Data.RawEvents.Trial{x}.States.LeftSmallReward(1)]))
                    newTrialCounts(2) = TrialCounts(2) + 1; % randChoice
                elseif sum(~isnan([Data.RawEvents.Trial{x}.States.RightBigReward(1) Data.RawEvents.Trial{x}.States.RightSmallReward(1)]))
                    newTrialCounts(1) = TrialCounts(1) + 1; % infochoice
                end
            case 2
                if sum(~isnan([Data.RawEvents.Trial{x}.States.RightBigReward(1) Data.RawEvents.Trial{x}.States.RightSmallReward(1)]))
                    newTrialCounts(3) = TrialCounts(3) + 1; % infoforced

                end
            case 3
                if sum(~isnan([Data.RawEvents.Trial{x}.States.LeftBigReward(1) Data.RawEvents.Trial{x}.States.LeftSmallReward(1)]))
                    newTrialCounts(4) = TrialCounts(4) + 1; % randforced
                end          
        end            
    end
end
        
%% POKES PLOTTING

function state_colors = getStateColors
    state_colors = struct( ...
        'StartTrial', [0 0 0],...
        'WaitForCenter',[255 240 245]./255,...
        'CenterDelay', [255	255 102]./255,...
        'CenterOdor',[255 255 102]./255,... 
        'CenterPostOdorDelay',[255 255 102]./255,...
        'GoCue',[0 1 0],...
        'Response',[1 1 0.8],...
        'WaitForOdorLeft',[216 191 216]./255,...
        'OdorLeft',[128	0 128]./255,...
        'RewardDelayLeft',[216 191 216]./255,...
        'LeftBigReward',[0 1 0],...
        'LeftSmallReward',[1 0 1],...
        'IncorrectLeft',[0.2 0.2 0.2],...
        'LeftNotPresent',[0.8 0.8 0.8],...
        'WaitForOdorRight',[255 228 189]./255,...
        'OdorRight',[255 140 0]./255,...
        'RewardDelayRight',[255 228 189]./255,...
        'RightBigReward',[0 1 0],...
        'RightSmallReward',[1 0 1],...
        'IncorrectRight',[0.2 0.2 0.2],...    
        'RightNotPresent',[0.8 0.8 0.8],...
        'OutcomeDelivery',[0 0 1],...
        'OutcomeTimeout',[0.4 0.4 0.4],...
        'NoChoice',[0.4 0.4 0.4],...
        'Incorrect',[0.2 0.2 0.2],...
        'TimeoutOdor',[0.4 0.4 0.4],...
        'TimeoutRewardDelay',[0.2 0.2 0.2],...
        'TimeoutReward',[0.4 0.4 0.4],...
        'InterTrialInterval',[0.8 0.8 0.8]);
end


function poke_colors = getPokeColors
    poke_colors = struct( ...
          'L', 0.6*[1 0.66 0], ...
          'C', [0 0 0], ...
          'R',  0.9*[1 0.66 0]);
end