function [f, diag] = uav_delivery_cost(X, env)
% UAV_DELIVERY_COST  joint objective: makespan + constraint penalty term
%   X  : n×D or 1×D decision matrix (vectorized)
%   env: scenario struct
%   f  : scalar objective column vector (n×1)
%   diag: diagnostic struct (returned only for single-row successful input)
%
% robustness: per-candidate-solution try-catch; any exception (e.g. degenerate/singular X)
% returns a large penalty 1e6 (treated as infeasible) and saves the bad X to badX.mat for diagnosis,
% so the optimizer is never interrupted by a single bad solution.

n = size(X, 1);
f = zeros(n, 1);
diag = struct();

% feasibility first: all constraint violations times a large constant PENW, so constraint-violating
% solutions score far above any feasible one (makespan ~ hundreds of seconds). The algorithm thus removes
% violations first; once the whole population is feasible the objective reduces to makespan and the algorithm minimizes completion time.
PENW = 100;

for k = 1:n
    try
        R = decode_delivery(X(k,:), env);

        L_total = 0;              % total flight distance (all UAVs)
        times    = zeros(env.Nu, 1);  % per-UAV completion time
        pen_cap  = 0;             % capacity penalty
        pen_obs  = 0;             % obstacle penalty
        pen_conf = 0;             % conflict penalty
        pen_kin  = 0;             % kinematic penalty
        pen_energy = 0;           % energy-exceeded penalty (battery constraint)

        for u = 1:env.Nu
            nodes = R.routes{u};
            if size(nodes,1) < 2, continue; end

            seg = diff(nodes, 1, 1);
            slen = sqrt(sum(seg.^2, 2));
            Lu = sum(slen);                    % this UAV total distance
            L_total = L_total + Lu;

            nc_u = R.nCust(u);
            times(u) = Lu/env.V + nc_u * env.TS;

            % ---- capacity constraint ----
            if R.load0(u) > env.Q
                pen_cap = pen_cap + (R.load0(u) - env.Q)^2;
            end

            % ---- obstacle penalty (sample along segments)----
            pen_obs = pen_obs + obs_penalty(nodes, env);

            % ---- kinematic constraint ----
            climb = asind(abs(seg(:,3)) ./ max(slen, 1e-9));
            pen_kin = pen_kin + sum(max(0, climb - env.MAX_CLIMB).^2);
            pen_kin = pen_kin + sum(max(0, env.MIN_SEG - slen).^2);

            % ---- battery / endurance constraint ----
            if isfield(env, 'E_max') && env.E_max > 0
                E_cruise  = env.e_cruise * Lu;                          % cruise base energy
                E_hover   = env.e_hover * nc_u * env.TS;               % hover delivery energy
                E_payload = env.e_payload * R.load0(u) * Lu;           % payload extra energy
                E_used    = E_cruise + E_hover + E_payload;
                if E_used > env.E_max
                    pen_energy = pen_energy + (E_used - env.E_max)^2;
                end
            end
        end

        % ---- makespan objective ----
        makespan = max(times);

        % ---- conflict detection (discrete waypoints)----
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

        f(k) = makespan + PENW * (pen_cap + pen_obs + pen_conf + pen_kin + pen_energy);

        % record diagnostics only for single-row input (for plotting)
        % note: array fields must be wrapped in {} as single values, otherwise struct() broadcasts them
        % into a struct array, making outer d.R.assign a "comma list + dot index" error.
        if n == 1
            diag = struct('makespan', makespan, 'times', {times}, ...
                          'load0', {R.load0}, 'routes', {R.routes}, ...
                          'assign', {R.assign}, 'cust_seq', {R.cust_seq}, ...
                          'L_total', L_total, 'pen_cap', pen_cap, ...
                          'pen_obs', pen_obs, 'pen_conf', pen_conf, ...
                          'pen_kin', pen_kin, 'pen_energy', pen_energy, ...
                          'R', {R});
        end

    catch ME
        % a single bad solution must not interrupt the whole optimization: record a large penalty and save bad X for diagnosis
        try save('badX.mat','X','env','ME'); catch, end  %#ok<*TRYNC>
        f(k) = 1e6;
    end
end
end


%% ==================== subfunctions ====================

function pen = obs_penalty(nodes, env)
% sample along segments and compute obstacle penetration penalty
ns = 5;  % sample points per segment
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
% cylinder
for o = 1:size(env.cyl,1)
    c = env.cyl(o,:);
    dx = pts(:,1)-c(1); dy = pts(:,2)-c(2);
    dxy = sqrt(dx.^2 + dy.^2);
    inside = (pts(:,3) < c(4)) & (dxy < c(3));
    pen = pen + sum(max(0, c(3)-dxy).^2 .* inside);
end
% sphere
for o = 1:size(env.sph,1)
    c = env.sph(o,:);
    d3 = sqrt(sum((pts - c(1:3)).^2, 2));
    inside = d3 < c(4);
    pen = pen + sum(max(0, c(4)-d3).^2 .* inside);
end
% prism
for o = 1:size(env.prism,1)
    b = env.prism(o,:);
    inside = (pts(:,1)>=b(1))&(pts(:,1)<=b(2))&...
             (pts(:,3)>=b(3))&(pts(:,3)<=b(4))&...
             (pts(:,5)>=b(5))&(pts(:,5)<=b(6));
    pen = pen + 100 * sum(inside);
end
end


function Pt = resample_route(nodes, K)
% resample trajectory to K points at equal arc length (guard against degenerate/duplicate nodes)
    if size(nodes,1) < 2
        Pt = repmat(nodes(1,:), K, 1); return;
    end
    % drop consecutive duplicate nodes to keep arc length strictly increasing (interp1 needs monotonic unique x)
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
