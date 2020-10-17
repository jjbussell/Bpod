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
end

%% LOAD NEW DATA

% select folder with new data file(s) to load
pathname=uigetdir;
files=dir([pathname,'/*.mat']);
numFiles = size(files,1);

f = 3;

    b = struct;
for f = 1:numFiles


    filename = files(f).name;

    fname = fullfile(pathname,filename);
    breaks = strfind(filename,'_');
    
    b.filename(f,1) = cellstr(filename);
    b.mouse(f,1) = cellstr(filename(1:breaks(1)-1));
    b.protocol(f,1) = cellstr(filename(breaks(1)+1:breaks(2)-1));
    b.day(f,1) = cellstr(filename(breaks(2)+1:breaks(3)-1));
    b.startTime(f,1) = cellstr(filename(breaks(3)+1:strfind(filename,'.')-1));
    
    % Pull raw data from matfile
    load(fname);    
    b.data(f,1) = SessionData;
    
    % Break down session data into per-file variables
    sessionVariables = {'nTrials','SettingsFile','TrialSettings','Notes',...
        'TrialCounts','EventNames','TrialTypes','Outcomes','TrialStartTimestamp','TrialEndTimestamp','RawEvents'};
    
    for i = 1:numel(sessionVariables)
        name = sessionVariables{i};
       if isfield(SessionData,name)
          b.(name){f,1} = SessionData.(name); 
       end
    end
    
end
    
    if exist('a','var') == 0

        a = b;
        
    else
       a.filename = [a.filename; b.filename];
       a.mouse = [a.mouse; b.mouse];
       a.protocol = [a.protocol; b.protocol];
       a.day = [a.day; b.day];
       a.startTime = [a.startTime; b.startTime];
       a.data = [a.data; b.data];
    end
    
% end

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



    
    