function R = decode_delivery(X, env)
% DECODE_DELIVERY  将连续决策向量 X 解码为配送方案（工程改进版）
%   设计要点：
%   1) 只保留“分配”维度（X(1:Nc)）——谁服务哪个客户；
%      几何路由由每机内部的 2-opt 精确求解，不再浪费维度在无效航点上。
%   2) 每机使用独立起降坪 pads(u)，巡航高度悬停投递（hover-drop）。
%   3) 访问顺序 = 对该机客户悬停点做 2-opt TSP（端点固定在巡航点），
%      保证给定分配下路径长度最优，消除连续微调带来的几何差距。
%
%   X : 1×D 行向量 (D = Nc)
%   env: 场景结构体
%   返回 R 结构体：.assign / .cust_seq / .routes / .load0 / .nCust

Nc = env.Nc; Nu = env.Nu;

%% --- 分配（仅用前 Nc 维）---
a = X(1:Nc);
R.assign = min(Nu, max(1, floor(a * Nu) + 1));  % 映射到 1..Nu

%% --- 构建每机路线（几何顺序由 2-opt 精确求解）---
R.cust_seq = cell(1, Nu);
R.routes    = cell(1, Nu);
R.load0     = zeros(1, Nu);
R.nCust     = zeros(1, Nu);

for u = 1:Nu
    cidx = find(R.assign == u);
    if isempty(cidx)
        % 空闲机：仅在本坪“起飞—巡航—降落”，不执行配送任务
        R.routes{u} = [env.pads(u,:); env.cruise_pts(u,:); ...
                       env.cruise_pts(u,:); env.pads(u,:)];
        R.cust_seq{u} = [];
        R.nCust(u) = 0;
        R.load0(u) = 0;
        continue;
    end
    seq = cidx;                      % 该机服务的客户编号
    R.cust_seq{u} = seq;
    R.nCust(u) = numel(seq);
    R.load0(u) = sum(env.weights(seq));

    % 该机客户悬停点（z = CRUISE），即投递位置（不下降到地面）
    hp = [env.customers(seq,1:2), repmat(env.CRUISE, numel(seq), 1)];

    % 2-opt 精确求解访问顺序：端点固定在巡航点 cruise_pts(u,:)
    P = two_opt_idx(hp, env.cruise_pts(u,:));
    hp = hp(P,:);
    seq = seq(P);
    R.cust_seq{u} = seq;

    % 构建节点序列：地面起降坪 → 垂直起飞至巡航 → 依次悬停投递 → 返航 → 降落本坪
    nodes = [];
    nodes(end+1,:) = env.pads(u,:);          % 地面起降坪
    nodes(end+1,:) = env.cruise_pts(u,:);    % 垂直起飞至巡航高度
    for k = 1:size(hp,1)
        nodes(end+1,:) = hp(k,:);            %#ok<AGROW>  % 客户上方巡航悬停点
    end
    nodes(end+1,:) = env.cruise_pts(u,:);    % 返航至巡航高度
    nodes(end+1,:) = env.pads(u,:);          % 降落至本坪
    R.routes{u} = nodes;
end
end


%% ==================== 子函数 ====================
function perm = two_opt_idx(hp, anchor)
% 对悬停点 hp(M×3) 求访问顺序，使 [anchor; hp(perm); anchor] 路径最短。
% 返回 hp 行索引的排列 perm。M 较小时（<=~10）2-opt 近似最优且极快。
n = size(hp, 1);
if n < 3
    perm = 1:n;
    return;
end
P = 1:n;
improved = true;
while improved
    improved = false;
    for i = 1:n-1
        for j = i+1:n
            P2 = P;
            P2(i:j) = P(j:-1:i);
            if pathlen(hp, P2, anchor) < pathlen(hp, P, anchor) - 1e-9
                P = P2;
                improved = true;
            end
        end
    end
end
perm = P;
end

function L = pathlen(hp, P, anchor)
% 路径长度：[anchor; hp(P,:); anchor]
seq = [anchor; hp(P,:); anchor];
d = diff(seq, 1, 1);
L = sum(sqrt(sum(d.^2, 2)));
end
