function R = decode_delivery(X, env)
% DECODE_DELIVERY  decode the continuous decision vector X into a delivery plan (engineering improved version)
%   design notes:
%   1) keep only the "assignment" dimension (X(1:Nc)) - which UAV serves which customer;
%      geometric routing is solved exactly by 2-opt inside each UAV, no dimension wasted on invalid waypoints.
%   2) each UAV uses its own pad pads(u), hovers at cruise altitude to deliver (hover-drop).
%   3) visit order = 2-opt TSP over the UAV's customer hover points (endpoints fixed at cruise point),
%      ensuring optimal path length under the given assignment, removing geometric gaps from continuous tweaking.
%
%   X : 1xD row vector (D = Nc)
%   env: scenario struct
%   returns struct R: .assign / .cust_seq / .routes / .load0 / .nCust

Nc = env.Nc; Nu = env.Nu;

%% --- assignment (use only the first Nc dimensions) ---
a = X(1:Nc);
R.assign = min(Nu, max(1, floor(a * Nu) + 1));  % map to 1..Nu

%% --- build per-UAV route (geometric order solved exactly by 2-opt) ---
R.cust_seq = cell(1, Nu);
R.routes    = cell(1, Nu);
R.load0     = zeros(1, Nu);
R.nCust     = zeros(1, Nu);

for u = 1:Nu
    cidx = find(R.assign == u);
    if isempty(cidx)
        % idle UAV: only "takeoff - cruise - landing" at its pad, no delivery task
        R.routes{u} = [env.pads(u,:); env.cruise_pts(u,:); ...
                       env.cruise_pts(u,:); env.pads(u,:)];
        R.cust_seq{u} = [];
        R.nCust(u) = 0;
        R.load0(u) = 0;
        continue;
    end
    seq = cidx;                      % customer index served by this UAV
    R.cust_seq{u} = seq;
    R.nCust(u) = numel(seq);
    R.load0(u) = sum(env.weights(seq));

    % this UAV's customer hover points (z = CRUISE), i.e. delivery positions (no descent to ground)
    hp = [env.customers(seq,1:2), repmat(env.CRUISE, numel(seq), 1)];

    % 2-opt exactly solves the visit order: endpoints fixed at cruise point cruise_pts(u,:)
    P = two_opt_idx(hp, env.cruise_pts(u,:));
    hp = hp(P,:);
    seq = seq(P);
    R.cust_seq{u} = seq;

    % build node sequence: ground pad -> vertical takeoff to cruise -> hover-deliver in turn -> return -> land at pad
    nodes = [];
    nodes(end+1,:) = env.pads(u,:);          % ground pad
    nodes(end+1,:) = env.cruise_pts(u,:);    % vertical takeoff to cruise altitude
    for k = 1:size(hp,1)
        nodes(end+1,:) = hp(k,:);            %#ok<AGROW>  % cruise hover point above customer
    end
    nodes(end+1,:) = env.cruise_pts(u,:);    % return to cruise altitude
    nodes(end+1,:) = env.pads(u,:);          % land at pad
    R.routes{u} = nodes;
end
end


%% ==================== subfunctions ====================
function perm = two_opt_idx(hp, anchor)
% find visit order for hover points hp (M x 3) minimizing path [anchor; hp(perm); anchor].
% returns the row-index permutation perm of hp. For small M (<= ~10) 2-opt is near-optimal and very fast.
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
% path length: [anchor; hp(P,:); anchor]
seq = [anchor; hp(P,:); anchor];
d = diff(seq, 1, 1);
L = sum(sqrt(sum(d.^2, 2)));
end
