function [f, Z, diag] = uav_delivery_cost(X, env)
% UAV_DELIVERY_COST  联合目标函数：Makespan + 约束惩罚
%   X  : n×D 或 1×D 决策矩阵（支持向量化）
%   env: 场景结构体
%   f  : 标量目标值列向量 (n×1)
%   diag: 诊断信息结构体（仅当输入为单行且成功时返回）
%
% 鲁棒性：对每个候选解单独 try-catch；任何异常（如退化/奇异 X）
% 返回大惩罚值 1e6（视为不可行）并保存坏 X 到 badX.mat 供诊断，
% 保证优化算法不会因个别坏解而整体中断。

n = size(X, 1);
f = zeros(n, 1);
Z = zeros(n, 1);              % 约束代价 Z = makespan + 时间窗迟到（与 Table 3 同一指标）
diag = struct();

% 可行性优先：所有约束违反乘以一个大常数 PENW，使“违反约束的解”目标值
% 远超任何可行解（makespan 量级 ~ 数百秒）。算法因此优先消除约束违反；
% 一旦种群全部可行，目标值退化为 makespan，算法转而真正最小化完工时间。
PENW = 100;

for k = 1:n
    try
        R = decode_delivery(X(k,:), env);

        L_total = 0;              % 总航程（所有机）
        times    = zeros(env.Nu, 1);  % 各机完成时间
        pen_cap  = 0;             % 容量惩罚
        pen_obs  = 0;             % 障碍惩罚
        pen_conf = 0;             % 冲突惩罚
        pen_kin  = 0;             % 运动学惩罚
        pen_energy = 0;           % 能量超限惩罚（电池约束）
        pen_tw  = 0;              % 时间窗迟到惩罚

        Arr = cell(env.Nu, 1);
        for u = 1:env.Nu
            nodes = R.routes{u};
            if size(nodes,1) < 2, Arr{u} = []; continue; end

            seg = diff(nodes, 1, 1);
            slen = sqrt(sum(seg.^2, 2));
            Lu = sum(slen);                    % 该机总航程
            L_total = L_total + Lu;

            nc_u = R.nCust(u);

            % ---- 时间窗：到达时间 / 等待（计入 makespan）/ 迟到 ----
            [arr_u, late_u, completion_u] = route_timing(nodes, R.cust_seq{u}, env);
            Arr{u} = arr_u;
            times(u) = completion_u;          % 含等待，已计入 makespan

            % ---- 容量约束 ----
            if R.load0(u) > env.Q
                pen_cap = pen_cap + (R.load0(u) - env.Q)^2;
            end

            % ---- 障碍惩罚（沿航段采样）----
            pen_obs = pen_obs + obs_penalty(nodes, env);

            % ---- 运动学约束 ----
            climb = asind(abs(seg(:,3)) ./ max(slen, 1e-9));
            pen_kin = pen_kin + sum(max(0, climb - env.MAX_CLIMB).^2);
            pen_kin = pen_kin + sum(max(0, env.MIN_SEG - slen).^2);

            % ---- 电池/续航约束 ----
            if isfield(env, 'E_max') && env.E_max > 0
                E_cruise  = env.e_cruise * Lu;                          % 巡航基础能耗
                E_hover   = env.e_hover * nc_u * env.TS;               % 悬停投递能耗
                E_payload = env.e_payload * R.load0(u) * Lu;           % 载重附加能耗
                E_used    = E_cruise + E_hover + E_payload;
                if E_used > env.E_max
                    pen_energy = pen_energy + (E_used - env.E_max)^2;
                end
            end

            % ---- 时间窗迟到软惩罚 ----
            if isfield(env, 'tw_w') && env.tw_w > 0
                pen_tw = pen_tw + late_u * env.tw_w;
            end
        end

        % ---- Makespan 目标 ----
        makespan = max(times);

        % ---- 冲突检测（离散航点）----
        K = env.K;
        Pts = cell(env.Nu, 1);
        for u = 1:env.Nu
            Pts{u} = resample_route(R.routes{u}, K);
        end
        PtMat = cat(3, Pts{:});  % K × 3 × Nu
        for i = 1:K
            Pi = squeeze(PtMat(i,:,:));  % Nu × 3
            pd = pdist(Pi);
            pen_conf = pen_conf + sum(max(0, env.dmin - pd).^2);
        end

        f(k) = makespan + PENW * (pen_cap + pen_obs + pen_conf + pen_kin + pen_energy) + pen_tw;
        Z(k) = makespan + pen_tw;      % 约束代价（不含 ×100 的其它惩罚，用于收敛图与 Table 3）

        % 仅单行时记录诊断信息（供绘图用）
        % 注意：数组字段必须用 {} 包成单值，否则 struct() 会广播成
        % 结构体数组，导致外层 d.R.assign 变成“逗号列表+点索引”报错。
        if n == 1
            diag = struct('makespan', makespan, 'times', {times}, ...
                          'load0', {R.load0}, 'routes', {R.routes}, ...
                          'assign', {R.assign}, 'cust_seq', {R.cust_seq}, ...
                          'L_total', L_total, 'pen_cap', pen_cap, ...
                          'pen_obs', pen_obs, 'pen_conf', pen_conf, ...
                          'pen_kin', pen_kin, 'pen_energy', pen_energy, ...
                          'pen_tw', pen_tw, 'arr', {Arr}, ...
                          'R', {R});
        end

    catch ME
        % 个别坏解不应中断整体优化：记大惩罚并保存坏 X 供诊断
        try save('badX.mat','X','env','ME'); catch, end  %#ok<*TRYNC>
        f(k) = 1e6;
    end
end
end


%% ==================== 子函数 ====================

function pen = obs_penalty(nodes, env)
% 沿航段采样，计算障碍穿透惩罚
ns = 5;  % 每段采样点数
pts = [];
for i = 1:size(nodes,1)-1
    tt = linspace(0,1,ns+1)';
    seg = nodes(i,:) + (nodes(i+1,:) - nodes(i,:)) .* tt;
    if i == 1
        pts = seg;
    else
        pts = [pts; seg(2:end,:)]; %#ok<AGROW>
    end
end
pen = 0;
% 圆柱
for o = 1:size(env.cyl,1)
    c = env.cyl(o,:);
    dx = pts(:,1)-c(1); dy = pts(:,2)-c(2);
    dxy = sqrt(dx.^2 + dy.^2);
    inside = (pts(:,3) < c(4)) & (dxy < c(3));
    pen = pen + sum(max(0, c(3)-dxy).^2 .* inside);
end
% 球体
for o = 1:size(env.sph,1)
    c = env.sph(o,:);
    d3 = sqrt(sum((pts - c(1:3)).^2, 2));
    inside = d3 < c(4);
    pen = pen + sum(max(0, c(4)-d3).^2 .* inside);
end
% 棱柱
for o = 1:size(env.prism,1)
    b = env.prism(o,:);
    inside = (pts(:,1)>=b(1))&(pts(:,1)<=b(2))&...
             (pts(:,3)>=b(3))&(pts(:,3)<=b(4))&...
             (pts(:,5)>=b(5))&(pts(:,5)<=b(6));
    pen = pen + 100 * sum(inside);
end
end


function Pt = resample_route(nodes, K)
% 将航迹等弧长重采样为 K 个点（对退化/重复节点做保护）
    if size(nodes,1) < 2
        Pt = repmat(nodes(1,:), K, 1); return;
    end
    % 去掉连续重复节点，保证弧长严格递增（interp1 要求单调唯一 x）
    keep = [true; any(diff(nodes,1,1) ~= 0, 2)];
    nodes = nodes(keep,:);
    if size(nodes,1) < 2
        Pt = repmat(nodes(1,:), K, 1); return;
    end
    seg = diff(nodes, 1, 1);
    sl = sqrt(sum(seg.^2, 2));
    cum = [0; cumsum(sl)];
    ts = linspace(0, cum(end), K)';
    Pt = [interp1(cum, nodes(:,1), ts), ...
          interp1(cum, nodes(:,2), ts), ...
          interp1(cum, nodes(:,3), ts)];
end


function [arr, late, completion] = route_timing(nodes, seq, env)
% ROUTE_TIMING  沿航线累计到达时间，处理时间窗（早到等待 / 晚到软惩罚）
%   nodes      : M×3 节点序列（pad→cruise→hover_1..k→cruise→pad）
%   seq        : 该机服务客户编号（按访问顺序）
%   arr        : 各客户到达时刻（已含等待）
%   late       : 总迟到秒数（超过 l_j 的部分之和）
%   completion : 回到起降坪的完工时刻（含等待与服务）
nC = numel(seq);
if ~isfield(env, 'tw') || nC == 0
    % 无时间窗：退化为原 makespan
    seg = diff(nodes, 1, 1); sl = sqrt(sum(seg.^2, 2));
    completion = sum(sl)/env.V + nC*env.TS;
    arr = zeros(nC, 1); late = 0; return;
end
arr = zeros(nC, 1);
late = 0; t = 0;
prev = nodes(1, :);
hi = 0;
for idx = 2:size(nodes, 1)
    seg = nodes(idx, :) - prev; sl = sqrt(sum(seg.^2));
    t = t + sl/env.V;
    if idx >= 3 && idx <= 2 + nC          % 客户上方巡航悬停投递点
        hi = hi + 1;
        j = seq(hi);
        e = env.tw(j, 1); l = env.tw(j, 2);
        if t < e, t = e; end              % 早到等待（计入完工时间）
        if t > l, late = late + (t - l); end
        arr(hi) = t;
        t = t + env.TS;                   % 服务时间
    end
    prev = nodes(idx, :);
end
completion = t;
end
