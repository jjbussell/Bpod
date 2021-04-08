
function HeadfixedTraining

global BpodSystem


%% Define parameters

S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.SessionTrials = 10;%
    S.GUI.TrialTypes = 2;% % 1 both, 2 left, 3 right
    S.GUI.RewardAmount = 4;
    S.GUI.OdorTime = 0.5;
    S.GUI.LeftOdor = 1;
    S.GUI.RightOdor = 2;
    S.GUI.LicksRequired = 2;
    S.GUI.ITI = 2;
    S.GUI.DrinkingDelay = 2; 
end

%% DEFINE TRIAL TYPES

S.TrialTypes = [];
S = SetTrialTypes(S); % Sets S.TrialTypes from trial 1 to maxTrials
BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.

%% Initialize plots

BpodNotebook('init');
BpodParameterGUI('init', S); % Initialize parameter GUI plugin
TotalRewardDisplay('init');

%% INITIALIZE SERIAL MESSAGES / DIO

ResetSerialMessages();

% 19-23 output, 2-7 input

% lick inputs 2, 3

% buzzer output = 5
buzzer1 = [254 1];
buzzer2 = [253 1];
houseLight = 21;

modules = BpodSystem.Modules.Name;
DIOmodule = [modules(strncmp('DIO',modules,3))];
DIOmodule = DIOmodule{1};

LoadSerialMessages(DIOmodule, {buzzer1, buzzer2, [houseLight 1],[houseLight 0]});
 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ODOR CONTROL SERIAL MESSAGES
LoadSerialMessages('ValveModule1',{[1,2],[1,3],[1,4],[1,5],[1,6],[1,7],[1,8]}); % switch control and odor 1-7, valves before
LoadSerialMessages('ValveModule2',{[1,2],[1,3],[1,4],[1,5],[1,6],[1,7],[1,8]}); % switch control and odor 1-7, valves after
LoadSerialMessages('ValveModule3',{[1,2]}); % final valves before animal

BpodSystem.Data.EventNames = BpodSystem.StateMachineInfo.EventNames;

%% MAIN TRIAL LOOP

MaxTrials = S.GUI.SessionTrials;

for currentTrial = 1:MaxTrials
    
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    
    modules = BpodSystem.Modules.Name;
    DIOmodule = [modules(strncmp('DIO',modules,3))];
    DIOmodule = DIOmodule{1};    

    MaxTrials = S.GUI.SessionTrials;
    
    sma = NewStateMachine();
    
    nextTrialType = S.TrialTypes(currentTrial);

    % Determine trial-specific state matrix fields
    % Set trialParams (reward and odor)
    % set rewardstate, rewardamount/valvetime,odor
    switch nextTrialType
        case 0 % left
            % response state
            Odor = S.GUI.LeftOdor;
            RewardState = 'RewardLeft';

        case 1 % right
            Odor = S.GUI.RightOdor;
            RewardState = 'RewardRight';
    end

    OdorHeadstart = 0.500;

    % Water parameters
    R = GetValveTimes(S.GUI.RewardAmount, [1 2]);
    % R = [0.100 0.100];
    LeftValveTime = R(1); RightValveTime = R(2); % Update reward amounts

    sma = SetGlobalCounter(sma,1,'DIOhf1_LeftLick_Hi',S.GUI.LicksRequired);
    sma = SetGlobalCounter(sma,2,'DIOhf1_RightLick_Hi',S.GUI.LicksRequired);


    % STATES
    sma = AddState(sma, 'Name', 'InterTrialInterval', ...
        'Timer', S.GUI.ITI-OdorHeadstart,...
        'StateChangeConditions', {'Tup', 'OdorPreload'},...
        'OutputActions', {DIOmodule,3});
    sma = AddState(sma, 'Name', 'OdorPreload',...
        'Timer', OdorHeadstart,...
        'StateChangeConditions', {'Tup', 'StartTrial'},...
        'OutputActions',PreloadOdor(Odor)); %Preload odor
    sma = AddState(sma, 'Name', 'StartTrial', ...
        'Timer', 0.2,...
        'StateChangeConditions', {'Tup', 'Odor'},...
        'OutputActions', {DIOmodule,4});
    sma = AddState(sma, 'Name', 'Odor', ...
        'Timer', S.GUI.OdorTime,...
        'StateChangeConditions', {'Tup', 'GoCue'},...
        'OutputActions',PresentOdor());
    sma = AddState(sma, 'Name', 'GoCue', ...
        'Timer', 0.05,...
        'StateChangeConditions', {'Tup',RewardState},...
        'OutputActions', [{DIOmodule,2},PresentOdor(),PreloadOdor(Odor)]);

    % REWARD AND LICKS
    sma = AddState(sma, 'Name', 'RewardLeft', ...
        'Timer', LeftValveTime,...
        'StateChangeConditions', {'Tup','ResponseLeft'},...
        'OutputActions', {'ValveState', 1});
    
    sma = AddState(sma, 'Name', 'ResponseLeft', ...
        'Timer', 0,...
        'StateChangeConditions', {'GlobalCounter1_End','Drinking'},...
        'OutputActions', {'GlobalCounterReset',1,'GlobalCounterReset',2});

    sma = AddState(sma, 'Name', 'RewardRight', ...
        'Timer', RightValveTime,...
        'StateChangeConditions', {'Tup','ResponseRight'},...
        'OutputActions', {'ValveState', 2});
    
    sma = AddState(sma, 'Name', 'ResponseRight', ...
        'Timer', 0,...
        'StateChangeConditions', {'GlobalCounter2_End','Drinking'},...
        'OutputActions', {'GlobalCounterReset',1,'GlobalCounterReset',2});

    sma = AddState(sma, 'Name', 'Drinking',...
        'Timer', S.GUI.DrinkingDelay,...
        'StateChangeConditions', {'Tup','>exit'},...
        'OutputActions', {});      
        
    SendStateMatrix(sma); % Send state machine to the Bpod state machine device
    RawEvents = RunStateMatrix; % Run the trial and return events

    %--- Package and save the trial's data, update plots
    if ~isempty(fieldnames(RawEvents)) % If you didn't stop the session manually mid-trial
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Adds raw events to a human-readable data struct
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file

        %--- Typically a block of code here will update online plots using the newly updated BpodSystem.Data
        TotalRewardDisplay('add',S.GUI.RewardAmount);

    end

    %--- This final block of code is necessary for the Bpod console's pause and stop buttons to work
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0
        TurnOffAllOdors();
        return
    end
end


end % end of protocol main function

%% TRIAL TYPES

function S = SetTrialTypes(S)

    global BpodSystem;

    nTrials = S.GUI.SessionTrials;

    typesAvailable = S.GUI.TrialTypes;

    switch typesAvailable 
        case 1
            trialTypes = ceil(rand(1,nTrials)*2);
        case 2
            trialTypes = ones(1,nTrials);
        case 3
            trialTypes = ones(1,nTrials)*2; 
    end

    S.TrialTypes = trialTypes;   
end

%% ODOR CONTROL

% to preload, turn off control and turn on other odor (still going to
% exhaust)

function Actions = PreloadOdor(odorID)          
    cmd1 = {'ValveModule1',odorID};
    cmd2 = {'ValveModule2',odorID}; 
    Actions = [cmd1,cmd2];
end

function Actions = PresentOdor()
    Actions = {'ValveModule3',1};
end

function TurnOffAllOdors()
    for v = 1:8
        ModuleWrite('ValveModule1',['C' v]);
        ModuleWrite('ValveModule2',['C' v]);
    end
    for v = 1:2
        ModuleWrite('ValveModule3',['C' v]);
    end    
end

function UpdateOutcomePlot(TrialTypes, Data)
global BpodSystem
Outcomes = zeros(1,Data.nTrials);
for x = 1:Data.nTrials
    if ~isnan(Data.RawEvents.Trial{x}.States.Drinking(1))
        Outcomes(x) = 1;
    else
        Outcomes(x) = 3;
    end
end
TrialTypeOutcomePlot(BpodSystem.GUIHandles.OutcomePlot,'update',Data.nTrials+1,TrialTypes,Outcomes);
end