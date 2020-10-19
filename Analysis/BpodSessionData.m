%% GOALS

%{
need to put data in a structure to facilitate calcs/plots of

% numTrials
% water
% numtrials of each type


% outcomes across trials per day
% % error
% licks in diff trial epochs
% % choice / pref (by side)
% leaving
% reaction time
% image time stamp

so structurce with row for each trial
fields: mouse, day, session, trial outcome,
 licks rel to trial start,image
events, port exit events/state txn

% good to preserve data in easy to understand original format and just have
script that can run reproducibly on it

load in files, record names, store date, mouse, protocol, time, ntrials as
metadata and rawevents (a.files with length of numfiles)


%}


%%

clear all;
close all;

%% LOAD DATA

% loadData = 1;
loadData = 0;

if loadData == 1
    fname = 'infoSeekBpodData.mat';
    load(fname); % opens structure "a" with previous data, if available
    for fn = 1:a.numFiles
        names{fn} = a.files(fn).name; 
    end
end

%% LOAD NEW DATA

% select folder with new data file(s) to load
pathname=uigetdir;
files=dir([pathname,'/*.mat']);
numFiles = size(files,1);

f = 3;

for f = 1:numFiles

    clearvars -except a names pathname files numFiles f loadData;

    filename = files(f).name;

    filepath = fullfile(pathname,filename);
    
    
    % need to check for duplicates!!!
    
%     breaks = strfind(filename,'_');
    
%     b.filename(f,1) = cellstr(filename);
%     b.mouse(f,1) = cellstr(filename(1:breaks(1)-1));
%     b.protocol(f,1) = cellstr(filename(breaks(1)+1:breaks(2)-1));
%     b.day(f,1) = cellstr(filename(breaks(2)+1:breaks(3)-1));
%     b.startTime(f,1) = cellstr(filename(breaks(3)+1:strfind(filename,'.')-1));    
    
    % Pull raw data from matfile
    load(filepath);    
%     b.data{f,1} = SessionData;
    
%     % Break down session data into per-file variables
%     sessionVariables = {'nTrials','SettingsFile','TrialSettings','Notes',...
%         'TrialCounts','EventNames','TrialTypes','Outcomes','TrialStartTimestamp','TrialEndTimestamp','RawEvents'};
%     
%     for i = 1:numel(sessionVariables)
%         name = sessionVariables{i};
%        if isfield(SessionData,name)
%           b.(name){f,1} = SessionData.(name);
%        else
%           b.(name){f,1} = []; 
%        end
%     end
    
    % Session-level data    
    session(f).name = filename;
    session(f).settings = SessionData.SettingsFile.GUI;
    session(f).eventNames = SessionData.EventNames;
    session(f).nTrials = SessionData.nTrials;
    

    
    % Trial-level data
    for t = 1:SessionData.nTrials
       b.file(t,1) = f;  
    end
    b.trialSettings = [SessionData.TrialSettings(:)];
%     b.trialSettings = [settings{:}]';
    b.trialType = SessionData.TrialTypes';
    b.startTime = SessionData.TrialStartTimestamp';
    b.endTime = SessionData.TrialEndTimestamp';
    b.outcome = SessionData.Outcomes';
    trialData = [SessionData.RawEvents(:).Trial];
    b.trialData = [trialData{:}]'; 
    b.States = [b.trialData(:)];
    
    % Add this file's data to struct 'a'
    if exist('a','var') == 0
        a = b;
        
    else
       a.file = [a.file; b.file];
       a.trialSettings = [a.trialSettings; b.trialSettings];
       a.trialType = [a.trialType; b.trialType];
       a.startTime = [a.startTime; b.startTime];
       a.endTime = [a.endTime; b.endTime];
       a.outcome = [a.outcome; b.outcome];
       a.trialData = [a.trialData; b.trialData];
    end    
    
end % end for each file

if isfield(a,'files') == 0
   a.files = session;
else       
    a.files = [a.files; session];
end

save('infoSeekBpodData.mat','a');
% uisave({'a'},'infoSeekFSMData.mat');

save(['infoSeekFSMBpodData' datestr(now,'yyyymmdd')],'a');


%%

% change this to be a hardcoded list of fields to go forward with (from
% protocol)

% try if file has field

% if so, add SessionData.Field for that file to a.field (do this within
% file loop

% then, unpack per-trial data

% fields = fieldnames(a.data);
% for i = 1:length(fieldnames(a.data))
%     a.(fields{i}) = [a.data(:).(fields{i})]';    
% end

% a.trialCt = [a.data(:).nTrials];

save('infoSeekBpodData.mat','a');
% uisave({'a'},'infoSeekFSMData.mat');

save(['infoSeekFSMBpodData' datestr(now,'yyyymmdd')],'a');



    
    