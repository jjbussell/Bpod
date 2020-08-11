function ValveProtocol
global BpodSystem

%% Setup (runs once before the first trial)
MaxTrials = 10000; % Set to some sane value, for preallocation

%--- Define parameters and trial structure
S = BpodSystem.ProtocolSettings; % Loads settings file chosen in launch manager into current workspace as a struct called 'S'
if isempty(fieldnames(S))  % If chosen settings file was an empty struct, populate struct with default settings
    % Define default settings here as fields of S (i.e S.InitialDelay = 3.2)
    % Note: Any parameters in S.GUI will be shown in UI edit boxes. 
    % See ParameterGUI plugin documentation to show parameters as other UI types (listboxes, checkboxes, buttons, text)
    
end


%% Main loop (runs once per trial)
for currentTrial = 1:MaxTrials
    
    %--- Typically, a block of code here will compute variables for assembling this trial's state machine
    
    cmd1 = {'ValveModule1',1};
    
    %--- Assemble state machine
    sma = NewStateMachine();
    sma = AddState(sma, 'Name', 'On', ...
        'Timer', 1,...
        'StateChangeConditions', {'Tup', 'Off'},...
        'OutputActions', cmd1);
    sma = AddState(sma, 'Name', 'Off', ...
        'Timer', 1,...
        'StateChangeConditions', {'Tup', '>exit'},...
        'OutputActions', cmd1);
    
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