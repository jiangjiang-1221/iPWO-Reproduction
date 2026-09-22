function env = uav_delivery_env(nuav, dmin)
% UAV_DELIVERY_ENV  multi-UAV multi-package delivery scenario generator (reproducible, fixed seed)
%   nuav : number of UAVs (default 4)
%   dmin : minimum safety distance m (default 6)
%   returns env struct: scenario params, obstacles, lb/ub/D, decode params, etc.
%
% usage:
%   env = uav_delivery_env();           % default 4 UAVs / d_min=6
%   env = uav_delivery_env(6, 8);       % 6 UAVs / d_min=8 (for sensitivity analysis)

if nargin < 1 || isempty(nuav), nuav = 4; end
if nargin < 2 || isempty(dmin), dmin = 6; end

rng(42);  % fixed seed for reproducibility

%% === basic parameters ===
env.Nu    = nuav;
env.Nc    = 20;                         % number of customers / packages
env.Q     = 12.0;                       % max capacity per UAV kg
env.V     = 15.0;                       % cruise speed m/s
env.TS    = 30.0;                       % single delivery service time s
env.dmin  = dmin;                       % minimum safety distance m
env.CRUISE = 35.0;                      % cruise altitude m
env.MAX_CLIMB = 90;                     % max climb angle deg (multirotor can take off/land vertically, so relaxed to 90)
env.MIN_SEG   = 3;                      % min segment length m
env.F     = 0;                          % free waypoints deprecated: geometric routing now solved exactly by 2-opt
env.K     = 60;                         % conflict-detection sample count (equal arc length)

%% === battery / endurance constraint ===
env.E_max   = 160;                     % battery capacity Wh per UAV (tuned so the constraint is active: balanced load ~135Wh is feasible, heavy concentration exceeds limit)
env.e_cruise = 0.15;                   % cruise power coefficient Wh/m
env.e_hover = 0.08;                    % hover power coefficient Wh/s (hover during delivery)
env.e_payload = 0.005;                 % payload extra power Wh/(kg·m)
env.wEnergy = 8000;                    % energy-exceeded penalty weight (same order as wObs/wConf)

%% === depot (delivery center) + multiple launch pads ===
% single depot (building center O), but each UAV has its own launch pad, evenly distributed around the depot center.
% this makes UAVs start/return at different positions, removing the "all UAVs crowd one point, routes all return to the same extreme" issue.
env.depot = [50, 50, 0];                 % depot ground coordinate (warehouse building center)
Rpad = 14;                              % launch-pad radius from depot center
env.pads = zeros(env.Nu, 3);
env.cruise_pts = zeros(env.Nu, 3);
for u = 1:env.Nu
    ang = pi/4 + 2*pi*(u-1)/env.Nu;     % evenly distributed around center, starting at 45 deg
    px = env.depot(1) + Rpad*cos(ang);
    py = env.depot(2) + Rpad*sin(ang);
    env.pads(u,:)       = [px, py, 0];            % ground launch pad
    env.cruise_pts(u,:) = [px, py, env.CRUISE];   % cruise-and-hover point above that pad
end

%% === customers (position + package weight)===
pos = rand(env.Nc, 2) .* 90 + 5;        % x,y ∈ [5,95]
env.customers = [pos, zeros(env.Nc, 1)]; % z=0 ground delivery
env.weights   = rand(env.Nc, 1) * 2.5 + 0.5;  % w_j ∈ [0.5, 3.0] kg

%% === obstacles (cylinder + sphere)===
env.cyl = [30 30 7 40;                 % [x y radius height]
          70 70 7 40;
          50 20 6 35];
env.sph = [35 60 25 7;                % [x y z radius]
          65 35 25 7];
env.prism = [];                        % no prism obstacle
env.threat = [];

%% === encoding dimension and bounds (engineering fix: keep only the "assignment" dimension)===
% encoding: [assign(Nc)]  -- only decides "which UAV serves which customer";
%       the visit order and geometric path within each UAV are solved exactly by 2-opt in decode,
%       no more wasting dimensions on nearly useless free waypoints (the original ~120 dead dimensions removed).
env.D = env.Nc;                        % decision dimension = number of customers (all meaningful)
env.lb = zeros(1, env.D);
env.ub = ones(1, env.D);               % assign in [0,1]

%% === penalty weights (tuned so terms are comparable in magnitude)===
env.wCap   = 100;                      % capacity-exceeded penalty
env.wObs   = 5000;                     % obstacle-penetration penalty
env.wConf  = 2000;                     % conflict penalty
env.wKin   = 50;                       % kinematic penalty
end
