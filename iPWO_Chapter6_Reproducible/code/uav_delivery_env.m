function env = uav_delivery_env(nuav, dmin)
% UAV_DELIVERY_ENV  多无人机多包裹配送场景生成器（可复现，固定种子）
%   nuav : 无人机数量（默认 4）
%   dmin : 最小安全距离 m（默认 6）
%   返回 env 结构体：场景参数、障碍、lb/ub/D、解码参数等。
%
% 用法：
%   env = uav_delivery_env();           % 默认 4 机 / d_min=6
%   env = uav_delivery_env(6, 8);       % 6 机 / d_min=8（敏感性分析用）

if nargin < 1 || isempty(nuav), nuav = 4; end
if nargin < 2 || isempty(dmin), dmin = 6; end

rng(42);  % 固定种子保证可复现

%% === 基础参数 ===
env.Nu    = nuav;
env.Nc    = 20;                         % 客户数 / 包裹数
env.Q     = 12.0;                       % 单机最大载重 kg
env.V     = 15.0;                       % 巡航速度 m/s
env.TS    = 30.0;                       % 单次投递服务时间 s
env.dmin  = dmin;                       % 最小安全距离 m
env.CRUISE = 35.0;                      % 巡航高度 m
env.MAX_CLIMB = 90;                     % 最大爬升角 deg（多旋翼可垂直起降，故放宽至 90）
env.MIN_SEG   = 3;                      % 最小航段长 m
env.F     = 0;                          % 自由航点已废弃：几何路由改由 2-opt 精确求解
env.K     = 60;                         % 冲突检测采样点数（弧长等距）

%% === 电池/续航约束 ===
env.E_max   = 160;                     % 单机电池容量 Wh（调到使约束真正生效：均衡分配~135Wh可行，过度集中会超限）
env.e_cruise = 0.15;                   % 巡航功耗系数 Wh/m
env.e_hover = 0.08;                    % 悬停功耗系数 Wh/s（投递时悬停）
env.e_payload = 0.005;                 % 载重附加功耗 Wh/(kg·m)
env.wEnergy = 8000;                    % 能量超限惩罚权重（与 wObs/wConf 同量级）

%% === 仓库（配送中心）+ 多起降坪 ===
% 单仓库（建筑中心 O），但每架无人机有自己独立的起降坪，围绕仓库中心均布。
% 这样各机从/回到不同位置，消除“所有机挤在同一点、路线都回到同一最高/最低点”的问题。
env.depot = [50, 50, 0];                 % 配送中心地面坐标（仓库建筑中心）
Rpad = 14;                              % 起降坪距仓库中心半径
env.pads = zeros(env.Nu, 3);
env.cruise_pts = zeros(env.Nu, 3);
for u = 1:env.Nu
    ang = pi/4 + 2*pi*(u-1)/env.Nu;     % 围绕中心均布，起始 45°
    px = env.depot(1) + Rpad*cos(ang);
    py = env.depot(2) + Rpad*sin(ang);
    env.pads(u,:)       = [px, py, 0];            % 地面起降坪
    env.cruise_pts(u,:) = [px, py, env.CRUISE];   % 该坪对应的巡航高度悬停点
end

%% === 客户（位置 + 包裹重量）===
pos = rand(env.Nc, 2) .* 90 + 5;        % x,y ∈ [5,95]
env.customers = [pos, zeros(env.Nc, 1)]; % z=0 地面交付
env.weights   = rand(env.Nc, 1) * 2.5 + 0.5;  % w_j ∈ [0.5, 3.0] kg

%% === 障碍物（圆柱 + 球体）===
env.cyl = [30 30 7 40;                 % [x y radius height]
          70 70 7 40;
          50 20 6 35];
env.sph = [35 60 25 7;                % [x y z radius]
          65 35 25 7];
env.prism = [];                        % 无棱柱障碍
env.threat = [];

%% === 编码维度与边界（工程改进：只保留“分配”维度）===
% 编码: [assign(Nc)]  —— 仅决定“谁服务哪个客户”；
%       每机内部的访问顺序与几何路径由 decode 中的 2-opt 精确求解，
%       不再浪费维度在几乎无用的自由航点上（原 ~120 个死维度已删除）。
env.D = env.Nc;                        % 决策维度 = 客户数（全部有意义）
env.lb = zeros(1, env.D);
env.ub = ones(1, env.D);               % assign 在 [0,1]

%% === 惩罚权重（需调参使各项量级可比）===
env.wCap   = 100;                      % 容量超限惩罚
env.wObs   = 5000;                     % 障碍穿透惩罚
env.wConf  = 2000;                     % 冲突惩罚
env.wKin   = 50;                       % 运动学惩罚
end
