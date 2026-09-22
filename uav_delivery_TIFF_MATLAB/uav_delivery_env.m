function env = uav_delivery_env(nuav, dmin)
% UAV_DELIVERY_ENV  multi-UAV multi-package delivery scenario generator (reproducible, fixed seed)
%   nuav : number of UAVs (default 4)
%   dmin : minimum safety distance m (default 6)
%   returns env struct: scenario parameters, obstacles, lb/ub/D, decode parameters, etc.
%
% usage:
%   env = uav_delivery_env();           % default 4 UAVs / d_min=6
%   env = uav_delivery_env(6, 8);       % 6 UAVs / d_min=8 (for sensitivity analysis)

if nargin < 1 || isempty(nuav), nuav = 4; end
if nargin < 2 || isempty(dmin), dmin = 6; end

rng(42);  % fixed seed for reproducibility

%% === base parameters ===
env.Nu    = nuav;
env.Nc    = 30;                         % number of customers / packages (engineering instance: 30 customers)
env.Q     = 10.0;                       % max per-UAV capacity kg (tightened so it occasionally violates, making the capacity constraint actually active)
env.V     = 15.0;                       % cruise speed m/s
env.TS    = 30.0;                       % single delivery service time s
env.dmin  = dmin;                       % minimum safety distance m
env.CRUISE = 35.0;                      % cruise altitude m
env.MAX_CLIMB = 90;                     % max climb angle deg (multirotor can take off vertically, so relaxed to 90)
env.MIN_SEG   = 3;                      % minimum segment length m
env.F     = 0;                          % free waypoints removed: geometric routing now solved exactly by 2-opt
env.K     = 60;                         % conflict-detection sample count (equal arc length)

%% === battery / endurance constraints ===
env.E_max   = 160;                     % per-UAV battery capacity Wh (tuned so the constraint is actually active: balanced assignment ~135Wh feasible, over-concentration exceeds)
env.e_cruise = 0.15;                   % cruise power coefficient Wh/m
env.e_hover = 0.08;                    % hover power coefficient Wh/s (during delivery)
env.e_payload = 0.005;                 % payload extra power Wh/(kg·m)
env.wEnergy = 8000;                    % energy-excess penalty weight (same order as wObs/wConf)

%% === depot (distribution center) + multiple launch pads ===
% single depot (building center O), but each UAV has its own launch pad, evenly distributed around the depot.
% this removes the "all UAVs crowd one point, all routes return to the same highest/lowest point" issue.
env.depot = [50, 50, 0];                 % depot ground coordinates (building center)
Rpad = 14;                              % launch-pad radius around depot center
env.pads = zeros(env.Nu, 3);
env.cruise_pts = zeros(env.Nu, 3);
for u = 1:env.Nu
    ang = pi/4 + 2*pi*(u-1)/env.Nu;     % evenly distributed around center, starting at 45deg
    px = env.depot(1) + Rpad*cos(ang);
    py = env.depot(2) + Rpad*sin(ang);
    env.pads(u,:)       = [px, py, 0];            % ground launch pad
    env.cruise_pts(u,:) = [px, py, env.CRUISE];   % cruise-altitude hover point above that pad
end

%% === customers (position + package weight) ===
pos = rand(env.Nc, 2) .* 90 + 5;        % x,y in [5,95]
env.customers = [pos, zeros(env.Nc, 1)]; % z=0 ground delivery
env.weights   = rand(env.Nc, 1) * 2.5 + 0.5;  % w_j in [0.5, 3.0] kg

%% === time windows (VRPTW, medium difficulty; window anchored to a naturally feasible visit plan) ===
% idea: first build a "reference feasible assignment" (assign customers to UAVs by rotating polar angle
% around the depot), using its wait-free arrival times as each customer's window center; half-width H controls difficulty.
% this guarantees at least one feasible solution exists (lateness ~ 0), so the constraint is truly active but
% "not all infeasible"; the algorithm must trade off "assignment + visit order", creating a rugged feasibility landscape that highlights differences in search intelligence.
[~, ord] = sort(atan2(env.customers(:,2)-env.depot(2), ...
                      env.customers(:,1)-env.depot(1)));
assign_ref = zeros(env.Nc, 1);
for k = 1:env.Nc
    assign_ref(ord(k)) = mod(k-1, env.Nu) + 1;
end
Xref = (assign_ref - 0.5) / env.Nu;     % map back to [0,1] continuous encoding
Rref = decode_delivery(Xref, env);
arr_ref = zeros(env.Nc, 1);
for u = 1:env.Nu
    nodes = Rref.routes{u};
    seq   = Rref.cust_seq{u};
    if isempty(seq), continue; end
    t = 0; prev = nodes(1,:); hi = 0;
    for idx = 2:size(nodes,1)
        t = t + norm(nodes(idx,:) - prev) / env.V;
        if idx >= 3 && idx <= 2 + numel(seq)
            hi = hi + 1;
            arr_ref(seq(hi)) = t;
            t = t + env.TS;
        end
        prev = nodes(idx,:);
    end
end
H = 60;                                 % time-window half-width (s); smaller = harder (first relaxed to guarantee a feasible solution is reachable)
env.tw   = [max(0, arr_ref - H), arr_ref + H];
env.tw_w = 2.0;                         % lateness penalty weight (seconds scale, same order as makespan)

%% === obstacles (cylinders + spheres) ===
env.cyl = [30 30 7 40;                 % [x y radius height]
          70 70 7 40;
          50 20 6 35];
env.sph = [35 60 25 7;                % [x y z radius]
          65 35 25 7];
env.prism = [];                        % no prism obstacle
env.threat = [];

%% === encoding dimension and bounds (engineering improvement: keep only the "assignment" dimension) ===
% encoding: [assign(Nc)]  -- only decides "who serves which customer";
%   the intra-UAV visit order and geometric path are solved exactly by 2-opt inside decode,
%   no more wasted dimensions on nearly useless free waypoints (the original ~120 dead dimensions removed).
env.D = env.Nc;                        % decision dimension = number of customers (all meaningful)
env.lb = zeros(1, env.D);
env.ub = ones(1, env.D);               % assign in [0,1]

%% === penalty weights (tuned so the terms are comparable in magnitude) ===
env.wCap   = 100;                      % capacity-excess penalty
env.wObs   = 5000;                     % obstacle-penetration penalty
env.wConf  = 2000;                     % conflict penalty
env.wKin   = 50;                       % kinematic penalty
end
