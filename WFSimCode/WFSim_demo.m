function [sol_array,JR,JQ] = WFSim_demo(R,refstairs,measured,KoopmanStates,PolyLiftingFunction,...
    controller,ControlSetStr,Vinf, vinfStr)
% WFSim_demo is the WIND FARM SIMULATOR (WFSIM) by S. Boersma and B. Doekemeijer
% from https://github.com/TUDelft-DataDrivenControl/WFSim
%
% A. Dittmer, B. Sharan: Reformulated as a function to enable running
% as a test suite with different input combinations.
%
% Inputs
% - R: Weights on control input changed (J = sum(e'Qe + dU'Rdu)
% - refstairs: Set reference to stairs
% - measured (for Koopman model): Use measured values as feedback
% - KoopmanStates (for Koopman model):  Number of Koopman states
% - PolyLiftingFunction(for Koopman model): Higher order lifting function
% - controller: integer switch: Open-loop: 0,  Wfsim NMPC: 1, KMPC: 2


if ~nargin
    R = 1e-6;
    refstairs = 1;
    measured = 0;
    KoopmanStates =  12;
    PolyLiftingFunction = 0;% 2,4,6,10,12,14,18,24
end

if nargin < 6
    % Define the control to be used
    % 0. Run the simulation open loop
    % 1. NMPC Controller by TU Delft
    % 2. KLMPC/ qLMPC controller solved by quadprog solver
    controller = 0;
end

if nargin < 7    
    ControlSetStr = 'sowfa_2turb_alm_turbl'; %'sowfa_2turb_yaw_alm_turbl';
    % ControlSetStr = 'sowfa_2turb_yaw_alm_uniform';
    % ControlSetStr = 'sowfa_2turb_yaw_alm_combined';
    % ControlSetStr = 'sowfa_2turb_yaw_alm_combined2';
    % ControlSetStr = 'sowfa_2turb_alm_turbl_AllComb';
    % ControlSetStr = 'sowfa_2turb_yaw_alm_turbl_AllComb1';
end

if nargin < 8

    Vinf = [8]; 
end

if nargin < 9
    vinfStr =''; %'_Vinf'; %alternativ '';
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%
%%      WIND FARM SIMULATOR (WFSIM) by S. Boersma and B. Doekemeijer
%                 Delft University of Technology, 2018
%          Repo: https://github.com/TUDelft-DataDrivenControl/WFSim
%
%  %  %  %  %  %  %  %  %  %  %  %  %  %  %  %  %  %  %  %  %  %  %  %  %
%
%%   Quick use:
%     1. Specify the wind farm you would like to simulate on line 73.
%        A list of all the wind farm scenarios can be found in
%        the 'layoutDefinitions' folder. You can also create your own
%        wind farm scenario here.
%     2. Either load a predefined timeseries of control inputs using line
%        74, or alternatively add your turbine/farm controllers in lines
%        115-119.
%     3. Setup the model solver settings in line 75. The default selection
%        is 'solverSet_default(Wp)', as defined in 'solverDefintions'.
%     4. Setup the simulation settings in lines 78-81.
%     5. Press start.
%
%%   Relevant input/output variables:
%     - modelOptions: this struct contains simulation settings
%     related to the wind farm itself (solution methodology, etc.)
%     - scriptOptions: this struct contains simulation settings, not
%     related to the wind farm itself (outputs, etc.)
%
%     - Wp: this struct contains all the simulation settings related to the
%           wind farm, the turbine inputs, the atmospheric properties, etc.
%         Wp.Nu:      Number of model states concerning longitudinal flow.
%         Wp.Nv:      Number of model states concerning lateral flow.
%         Wp.Np:      Number of model states concerning pressure terms.
%         Wp.sim:     Substruct containing timestep and simulation length.
%         Wp.turbine: Substruct containing turbine properties and settings.
%         Wp.site:    Substruct containing freestream atmospheric properties.
%         Wp.mesh:    Substruct containing topology and meshing settings.
%
%     - sol: this struct contains the system states at a certain timestep.
%         sol.k:     Discrete timestep  to which these system states belong
%         sol.time:  Actual time (in s) to which these system states belong
%         sol.x:     True system state (basically flow field excluding bcs)
%         sol.u:     Instantaneous longitudinal flow field over the mesh (in m/s)
%         sol.v:     Instantaneous longitudinal flow field over the mesh (in m/s)
%         sol.p:     Instantaneous pressure field over the mesh (in Pa)
%         sol.uu:    Same as sol.u, used for convergence
%         sol.vv:    Same as sol.v, used for convergence
%         sol.pp:    Same as sol.p, used for convergence
%         sol.turbine: a struct containing relevant turbine outputs such as
%         the ax. ind. factor, the generated power, and the ct coefficient
%         sol.turbInput: turbine inputs at current time
%
%     - sys: this struct contains the system matrices at a certain timestep.
%         sys.A:     System matrix A in the grand picture: A*sol.x = b
%         sys.b:     System vector b in the grand picture: A*sol.x = b
%         sys.pRCM:  Reverse Cuthill-McKee algorithm for solving A*x=b faster.
%         sys.B1:    Submatrix in the matrix sys.A.
%         sys.B2:    Submatrix in the matrix sys.A.
%         sys.bc:    Vector with boundary conditions of the continuity equation (part of sys.b).
%
%%   Debugging and contributing:
%     - First, try to locate any errors by turning all possible outputs
%       on (printProgress, printConvergence, Animate, plotMesh).
%     - If you cannot solve your problems, reach out on the Github.
%
%%   Nonlinear or stochastic MPC provinding active power control:
%     - In line 104 set if sol.k>=0 for open-loop (no control)
%       and sol.k<=0 for closed-loop (wind farm will track a power reference).
%     - Call in line 117 NMPCcontroller.m or SMPCcontroller.m for the nonlinear or stochastic controller, respectively.
%     - When the simulation is finished, run MPC_animation.m to see the results
%     - Note that to run a controller, installation of YALMIP and a solver
%       is required. Current controller settings belong to the sowfa_9turb_apc_alm_turbl
%       case and CPLEX 12.8 solver.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
profile ON
tic

%% Define simulation settings: layout, control inputs and simulation duration
[DataKoopman,DataOut,S] = WFSim_addpaths(controller,PolyLiftingFunction); % Add essential paths to MATLABs environment
eval(['Wp = layoutSet_sowfa_2turb_alm_turbl',vinfStr]); %alternativ; %layoutSet_sowfa_9turb_apc_alm_turbl(); % Choose which scenario to simulate. See 'layoutDefinitions' folder for the full list.


if ~isempty(Vinf) && length(Wp.site.u_Inf) == 1 %Vinf is set by the user
    Wp.site.u_Inf = Vinf(1); % Wp.turbine.Crx(2) = Wp.turbine.Crx(1) + 3 * Wp.turbine.Drotor;
end
turbInputSet = eval(['controlSet_',ControlSetStr,'(Wp)']); % turbInputSet = controlSet_greedy(Wp);% for greedy control input
modelOptions = solverSet_default(Wp); % Choose model solver options

% Simulation length, display and visualization settings
NN = floor(turbInputSet.t(end))/Wp.sim.h; %min(1200,floor(turbInputSet.t(end)/Wp.sim.h)); % Number of timesteps in simulation
verboseOptions.printProgress = 0;    % Print progress in cmd window every timestep. Default: true.
verboseOptions.Animate       = 0;    % Plot flow fields every [X] iterations (0: no plots). Default: 10.
verboseOptions.plotMesh      = 0;    % Plot mesh, turbine locations, and print grid offset values. Default: false.

% KoopmanStates = 24; % 2,4,6,10,12,14,18,24
if refstairs == 1
    NN = 2000;
end

%% Script core functions
[Wp,sol,sys] = InitWFSim(Wp,modelOptions,verboseOptions.plotMesh); % Initialize WFSim model
if length(Vinf) > 1 && length(Wp.site.u_Inf) == 1 %Vinf is set by the user
    VinfStr = strrep(sprintf('Vinf%2.1fTo%2.1f',Vinf(1),Vinf(2)),'.','dot');
elseif length(Wp.site.u_Inf) == 1
    VinfStr = strrep(sprintf('Vinf%2.1f',Wp.site.u_Inf),'.','dot'); % information for plot
else
    VinfStr = strrep(sprintf('Vinf%2.1fNTM',mean(Wp.site.u_Inf)),'.','dot'); % information for plot
end
sol.kUinfChange = 0; %counter since change of Uinf %ToDo ADi remove this
sol.nkUinfChange = 0; %counter since this effected the grid points
sol.diffV = 0;

% Information for storage
if controller == 0
    folderName = sprintf('%s_OL_Ct',VinfStr);
    Rprint = ControlSetStr;
elseif controller == 1 || measured == 1
    folderName = sprintf('%s_CLmeasWind',VinfStr);
    Rprint = strrep(strrep(sprintf('R%2.1e',R),'.','dot'),'-','_neg');
else
    folderName = sprintf('%s_CL_K%02d_P%d',VinfStr,KoopmanStates,PolyLiftingFunction);%'Vinf%d_diffComb_states%d'
    Rprint = strrep(strrep(sprintf('R%2.1e',R),'.','dot'),'-','_neg');
end


dirFig = fullfile(DataOut,folderName);
if ~exist(dirFig,'dir')
    mkdir(dirFig);
end

if refstairs
    figName = sprintf('Stairs%d%s',refstairs,Rprint);
else
    figName = sprintf('%s',Rprint);
end

fileName = [strrep(sprintf('Vinf%2.1f_%s',Wp.site.u_Inf,ControlSetStr),'.','dot'),'.mat'];
matFileExists = exist(fullfile(DataOut,fileName),'file') == 2;

filenamepng = matlab.lang.makeValidName(figName);
fullFigName = fullfile(dirFig,[filenamepng,'.fig']);

figFileExists = exist(fullfile(DataOut,fileName),'file') == 2;

if matFileExists && figFileExists && controller == 0
    disp(['Mat file exists: ',fileName]);
    disp(['Fig file exists: ',filenamepng]);
    open(fullFigName);
    return;
end


% Initialize variables and figure specific to this script
CPUTime   = nan(NN,1);% Create empty matrix to save CPU timings
if verboseOptions.Animate > 0 % Create empty figure if Animation is on
    hfig = figure('color',[0 166/255 214/255],'units','normalized',...
        'outerposition',[0 0 1 1],'ToolBar','none','visible', 'on');
end


if controller > 0 % for all controllers
    NN = min(length(S.AGCdata(:,2)),NN);
end
if controller == 1 %for original MPC controller
    mpc = MPCinit(sol,Wp,NN);
elseif controller == 2
    [mpc,K] = MPCinitv(sol,Wp,NN,refstairs,DataKoopman,KoopmanStates,R,PolyLiftingFunction,S);
    mpc.controller = controller;
end

% Performing forward time propagations
disp(['Performing ' num2str(NN) ' simulations..']);
kVinf = 0;

%Vinf = Wp.site.u_Inf;
Wp.site.u_Inf = Vinf(1);
Wp.site.v_Inf  = 0;
while sol.k < NN
    
    
    tic; % Start stopwatch
    
    % Determine control setting at current time by interpolation of time series
    turbInput = struct('t',sol.time);
    
    if ~controller || sol.k<=0 % sol.k>=0 % set to ">=0" for open-loop |or| "<=" for closed-loop -> changed to be able to run this as a function
        for i = 1:Wp.turbine.N
            % calculate the thrust coefficent and yaw angle with the help
            % of interpolation method from the given loop up table.
            turbInput.CT_prime(i,1) = interp1(turbInputSet.t,turbInputSet.CT_prime(i,:),sol.time,turbInputSet.interpMethod);
            turbInput.phi(i,1)      = interp1(turbInputSet.t,turbInputSet.phi(i,:),sol.time,turbInputSet.interpMethod);
        end
    else
        switch controller % decided controller will run under the close-loop configuration.
            case 1
                % uses YALMIP toolbox and its optimizer function
                [turbInput.CT_prime(:,1),turbInput.phi(:,1),mpc] = NMPCcontroller(sol,Wp,mpc);
            case 2
                % MATLAB quadprog (QP cost fun: min f(x) = 1/2*x'Hx+f'x s.t. Ax <= b
                % measured = 0: Koopman model for wind
                [turbInput.CT_prime(:,1),turbInput.phi(:,1),mpc] = qLPVMPCcontroller_dU_quadprog(sol,Wp,mpc,K,measured);
            otherwise
                % not yet implemented -> this should stop
                error('Controller switch has to be set to 0,1 or 2')
        end
    end
    
    % Propagate the WFSim model to the next timestep.
    if sol.k >= 400 && length(Vinf) == 2 && Wp.site.u_Inf < Vinf(2) && length(Vinf) <= 2
        %kVinf = kVinf + 1;
        Wp.site.u_Inf = Vinf(2); %Vinf(1) + kVinf*0.01;
    elseif length(Vinf) > 2
        Wp.site.u_Inf = Vinf(max(1,sol.k)); %Vinf(1) + kVinf*0.01;
    end
    [sol,sys]      = WFSim_timestepping(sol,sys,Wp,turbInput,modelOptions); % forward timestep: x_k+1 = f(x_k)
    CPUTime(sol.k) = toc;   % Stop stopwatch
    if controller > 1
        sol.xprev = mpc.xprev;
sol.error_norm = mpc.error_norm;
    end
    % Save sol to cell array
    sol_array(sol.k) = sol; %#ok<AGROW> this is not a huge delay
    
    % Print progress, if necessary
    if verboseOptions.printProgress
        disp(['Simulated t(' num2str(sol.k) ') = ' num2str(sol.time) ...
            ' s. CPU: ' num2str(CPUTime(sol.k)*1e3,3) ' ms.']);
    end
    
    % Plot animations, if necessary
    if verboseOptions.Animate > 0
        if ~rem(sol.k,verboseOptions.Animate)
            hfig = WFSim_animation(Wp,sol,hfig);
        end
    end
end

disp(' ')
disp(['Completed ' num2str(NN) ' forward simulations. Average CPU time: ' num2str(mean(CPUTime)*10^3,3) ' ms.']);
t_display = toc;
fprintf('Lemke qLPVMPC solved in %2.3f \n',t_display);
profile off

%% plot figures and save data
[time, CT_prime, Phi, Power, ~, V, JR] = saveDataEDMD(Wp,sol_array,controller,figName,dirFig);

if controller == 0
    [JR,JQ] = plotWFSimTimeseries(Wp,sol_array,controller,Power,CT_prime,Phi,V,JR,time,measured,figName,dirFig);
elseif controller == 1
    [JR,JQ] = plotWFSimTimeseries(Wp,sol_array,controller,Power,CT_prime,Phi,V,JR,time,measured,figName,dirFig,mpc);
else
    [JR,JQ] = plotWFSimTimeseries(Wp,sol_array,controller,Power,CT_prime,Phi,V,JR,time,measured,figName,dirFig,mpc,K);
end