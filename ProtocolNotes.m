%{

To implement:

LEAVE PLOTTING FOR LATER, CHOOSE TYPE OF NEXT TRIAL FROM TRIAL TYPES LIST
MOVING ON ONLY IF MAKE CORRECT CHOICE ON LAST TRIAL (no incorrect or no
choice state)

reshuffling trial types so don't move on from no choice/incorrect?

training protocols!!

scope sync

center reward protocol, must stay in port protocol

outcome plot

total liquid/performance

GUI to load and set session parameters BEFORE trial types are chosen (json
files?)

camera


Params

ChooseLeft
ChooseRight
StimulusOutput - for now, light
CenterOdor
RewardLeft
RewardRight
RightSideOdor
LeftSideOdor
OutcomeStateLeft
OutcomeStateRight
LeftRewardDrops
RightRewardDrops

GlobalTimer1 = Odor delay
Condition7 = when it expires

For time of max drops but with no water:
GlobalCounter2 = globaltimer2 end, maxdrops

Left reward:
GlobalTimer 3 = valve time for reward drops
global counter 3 = counts those for left drops

Right reward:
4"" for right



incorrect = wrong choice, duration odor delay
nochoice = no choice, duration odor delay
both then go to timeout odor, timeout reward delay, timeout reward (global
timer 2)

outcomestate:
rightbigreward-timer 4
rightsmallreward-timer 4
incorrectright-timer 2 NEVER HAPPENS?
rightnotpresent - timer 2 NEVER HAPPENS?
%}
