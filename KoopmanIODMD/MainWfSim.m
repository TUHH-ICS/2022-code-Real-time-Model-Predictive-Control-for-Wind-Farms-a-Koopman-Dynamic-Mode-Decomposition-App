function MainWfSim(yawmode,filenameId,filenameVal,noStates,useVal,percentTrain)
% Code based on
% Model Predictive Control For Wake Steering: a Koopman Dynamic Mode
% Decomposition Approach
% Master Thesis Dissertation
% Author: Nassir Rodrigues Cassamo
% Supervisors: Professor Jan-Willem Van Wingerden and Professor Jo?o Sousa
% First official commit (1.0): December 2020

%% RELEVAT INFORMATION
%This script has the following goals:
% (1) Assess Simulation data, both qualitatively (animations) and
% quantitatively (graphics)
% (2) Derives a low dimensional model using Dynamic Mode Decomposition
% (variations included to take into account input-output data and other
% known states - deterministic states)
% (3) Validates the models with a set of validaiton data

%% (0) INITIALISE
% define type of simulation
%clc; clear; close all;
if ~nargin
    % directory for identification and validation data, yaw and pitch
    yawmode = 0; %0 for ct (pitch/torque) control, 1 for additional yaw control
    
    filenameId = 'Vinf8dot5_sowfa_2turb_alm_turbl_AllComb.mat';
    filenameVal = 'Vinf8dot5_sowfa_2turb_alm_turbl.mat';
    
    % filenameId = 'Vinf8dot5_sowfa_2turb_yaw_alm_uniform'; %'Vinf8dot5_sowfa_2turb_yaw_alm_combined.mat'; %'Vinf8dot5_sowfa_2turb_yaw_alm_turbl_AllComb.mat';
    % filenameVal = 'Vinf8dot5_sowfa_2turb_yaw_alm_uniform'; %'Vinf8dot5_sowfa_2turb_yaw_alm_combined.mat';
    
    % User input
    noStates = [6,12,12,12,14,18,24]; %number of Koopman states [,12,12,14,18,24]
    useVal = 0; % use extra data for validation
    percentTrain = .6;% 60% data for validation
end


PolyVec = zeros(size(noStates)); % 1: use only polynomial, 0: otherwise
idxPolyOn = find(noStates == 12, 1, 'first');
PolyVec(idxPolyOn) = 1;

detrendingstates = 0; %1 to take mean flow and consider turbulent fluctuations
method = -2; %0: DMD ; 1:DMDc; 2:IODMD; 3:EXTIODMD -1: EDMD
koopman = 1; %to add deterministic states to flow field data


% Simulation characterisitc (resampling)
dt = 1; %time sampling (s)


KoopmanDir = fileparts(mfilename('fullpath')); % Get Koopman directory
pathFunctions = genpath(fullfile(KoopmanDir,'Functions'));


addpath(fullfile(KoopmanDir,'2.DYNAMIC_MODE_DECOMPOSITION'),...
    pathFunctions);
codedir = mfilename('fullpath');
parentdir = fileparts(fileparts(codedir));

% DEFINE MAIN output data DIRECTORY TO STORE ALL RESULTS
DataOut = fullfile(parentdir,'DataInOutWfSim');
if ~isfolder(DataOut)
    mkdir(DataOut)
end

DataIn = fullfile(parentdir,'DataT2OLWFSim');
if ~isfolder(DataIn)
    warning('DataIn directory does not exist')
    return
end

%% Loop for  'Vinf8dot5_sowfa_2turb_yaw_alm_combined2.mat'
if yawmode == 0 %pitch control
    sepStr = strfind(filenameId,'_');
    dirName = fullfile(DataIn, [filenameId(1:sepStr-1),'_OL_Ct'], filenameId);
    tmpId = load(dirName,'Ct1', 'Ct2', 'FT1', 'FT2', 'PT1', 'PT2', ...
        'Ur1', 'Ur2', 'p', 'phi1', 'phi2', 'u', 'v');
    
    if useVal == 1
        dirNameVal = fullfile(DataIn, filenameVal);
        tmpVal = load(dirNameVal,'Ct1', 'Ct2', 'FT1', 'FT2', 'PT1', 'PT2', ...
            'Ur1', 'Ur2', 'p', 'phi1', 'phi2', 'u', 'v');
    end
    
else
    
    dirName = fullfile(DataIn,filenameId);
    tmpId = load(dirName,'Ct1', 'Ct2', 'FT1', 'FT2', 'PT1', 'PT2', ...
        'Ur1', 'Ur2', 'p', 'phi1', 'phi2', 'u', 'v');
    if useVal == 1
        dirNameVal = fullfile(DataIn, filenameVal);
        tmpVal = load(dirNameVal,'Ct1', 'Ct2', 'FT1', 'FT2', 'PT1', 'PT2', ...
            'Ur1', 'Ur2', 'p', 'phi1', 'phi2', 'u', 'v');
    end
end

%% (1) ASSESS DATA
% easy solution to augment u flow field data matricx with other flow
% field data
fieldCell = fieldnames(tmpId);

useVal = exist('tmpVal','var') && useVal;

for idx = 1:length(fieldCell)
    if useVal
        tmp = [tmpId.(fieldCell{idx}), tmpVal.(fieldCell{idx})]; %#ok<NASGU>
    else
        tmp = [tmpId.(fieldCell{idx})]; %#ok<NASGU>
    end
    eval([fieldCell{idx},'= tmp;']);
end

t0 = 1;
if useVal
    tident = length(tmpId.Ct1);
else
    tident = floor(length(Ur1)*percentTrain);
end
tval = tident+1;
QQ_u1 = u(:,t0:tident); %#ok<*USENS>
QQ_v1 = v(:,t0:tident);
QQ_p1 = p(:,t0:tident);

valid.QQ_u1 = u(:,tval:end);
valid.QQ_v1 = u(:,tval:end);
valid.QQ_p1 = u(:,tval:end);

%% (2) DYNAMIC MODE DECOMPOSITION
states_u = QQ_u1;%fluid flow as states, identification data set
statesvalid_u = valid.QQ_u1; %fluid flow as states, validaiton data set for comparison

if yawmode == 0
    Inputs = [Ct1(t0:tident);Ct2(t0:tident)];
    Inputs_val = [Ct1(tval:end);Ct2(tval:end)];
else
    Inputs = [Ct1(t0:tident);Ct2(t0:tident); phi1(t0:tident)];
    Inputs_val = [Ct1(tval:end);Ct2(tval:end); phi1(tval:end)];
end

Outputs = [PT1(t0:tident);PT2(t0:tident);FT1(t0:tident);FT2(t0:tident)];
Outputs_val = [PT1(tval:end);PT2(tval:end);FT1(tval:end);FT2(tval:end)];

% ToDo check
if detrendingstates == 1
    [states_u, meansteadystate, scalingfactor] = preprocessstates(states_u); %remove meanflow or other pre processing techniques to experiment
end

strVAF = cell(length(noStates),1);
for idx = 1: length(noStates)
    
    n = noStates(idx);
    poly = PolyVec(idx);
    
    % subdirectories in dataOut
    if poly == 1 && yawmode == 0
        dirdmdName = 'eDMDresults_UasOutput_poly';
    elseif poly == 0 && yawmode == 0
        dirdmdName = 'eDMDresults_UasOutput';
    elseif poly == 1
        dirdmdName = 'eDMDresults_UasOutput_MIMO_poly';
    else
        dirdmdName = 'eDMDresults_UasOutput_MIMO';
    end
    
    dirdmd = fullfile(DataOut,dirdmdName);
    if ~ isfolder(dirdmd)
        mkdir(dirdmd);
    end
    
    %include non linear observables - Koopman extensions to better recover non linear dynamics
    if koopman == 1
        %         states_v = QQ_v1; %fluid flow as states, identification data set
        %         states_p = QQ_p1;
        Deterministic = [Ur1(t0:tident); Ur2(t0:tident)];
        [states,stateName] = koopmanstateextensionWFSim(Deterministic,poly,n);
        
        %         statesvalid_v = valid.QQ_v1; %fluid flow as states, identification data set
        %         statesvalid_p = valid.QQ_p1;
        Deterministic_val = [Ur1(tval:end); Ur2(tval:end)];
        statesvalid  = koopmanstateextensionWFSim(Deterministic_val,poly,n);
    else
        states = states_u;
        statesvalid = statesvalid_u;
        temp = sprintf('u%d;',1: size(states,1));
        stateName = temp(1:end-1);
    end
    
    Vinf = QQ_u1(1,1);
    folderName = strrep(sprintf('Vinf%2.1f_states%02d',Vinf,n),'.','dot');%'Vinf%d_diffComb_states%d'
    fileName = sprintf('stateName_K%02d_P%d.mat',n,poly); %stateName);
    
    dirFig = fullfile(dirdmd,folderName); % this depends on vinf 
    if ~exist(dirFig,'dir')
        mkdir(dirFig);
    end
    
    Deterministic = [Ur1(t0:tident); Ur2(t0:tident)];
    Deterministic_val = [Ur1(tval:end); Ur2(tval:end)];
    [sys_red,FITje,Xd,Xd_p,x,FITje_val,fig1,xo,Koop] = ...
        eDynamicmodedecomposition(states,statesvalid,Inputs,Outputs,...
        Deterministic,Deterministic_val,Inputs_val,Outputs_val,method,codedir,dirFig,dt,stateName,dirFig);
    
    
    save(fullfile(dirFig,fileName),'sys_red','FITje','FITje_val','dirName','xo','Koop');
    
    strVAF{idx} = sprintf('%s \t\t %d\t\t\t %d\t\t\t %d \t\t%d\n',num2str(n,'%02d'),...
        round(FITje(1)), round(FITje_val(1)),round(FITje(2)), round(FITje_val(2)));
    
end

fid = fopen(['VAF_',strrep(filenameId,'.mat',''),'.txt'],'w');
fprintf(fid,'No K.\tT1(Id)\t\tT1(Val)\t\t T2(Id)\t\tT2(Val)\n');

for idx = 1: length(noStates)
    fprintf(fid,'%s',strVAF{idx});
end
fclose(fid);

%% Unused code
% Turbine and flow characteristics to be used
% rho = 1.20; %air density in [kg m^-3]
% D = 126.4; %Rotor Diameter used in simulations = 110 [m] %ToDo AD Check this in WFSim

