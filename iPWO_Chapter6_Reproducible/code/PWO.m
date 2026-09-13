function [Alpha_score, Alpha_pos, Convergence_curve] = PWO(num_agents, max_iterations, lb, ub, dim, fobj)
% PWO - Painted Wolf Optimization Algorithm
%
% This function implements the Painted Wolf Optimization (PWO) algorithm.
% The code is structured for clarity and readability, while precisely 
% preserving the original logic to ensure the reproducibility of research results.
%
% Title: Painted Wolf Optimization: A Novel Nature-Inspired Metaheuristic 
%        Algorithm for Real-World Optimization Problems
%
% Inputs:
%   num_agents      - Number of search agents (the pack size)
%   max_iterations  - Maximum number of iterations
%   lb              - Lower bound of the search space (scalar or vector)
%   ub              - Upper bound of the search space (scalar or vector)
%   dim             - Number of dimensions (variables) in the problem
%   fobj            - Objective function handle (e.g., @(x) sum(x.^2))
%
% Outputs:
%   Alpha_score     - The best score found (cost of the alpha wolf)
%   Alpha_pos       - The position of the best solution (alpha's position)
%   Convergence_curve - Vector containing the best score at each iteration
%
% Example Usage:
%   npop = 30;
%   MaxIter = 500;
%   dim = 10;
%   lb = -100;
%   ub = 100;
%   fobj = @YourObjectiveFunction;
%   [Best_score, Best_pos, cg_curve] = PWO(npop, MaxIter, lb, ub, dim, fobj);
%--------------------------------------------------------------------------

%==========================================================================
% 1. Initialization
%==========================================================================

% --- Algorithm-specific Parameters ---
% These parameters are central to the PWO logic.
VOTE_INCREMENT = 0.04; % The contribution of each wolf to the rally strength.

% --- Initialize the Pack ---
% The 'pack' struct holds the position and cost for each wolf.
wolf.Position = [];
wolf.Cost = [];
pack = repmat(wolf, num_agents, 1);

% --- Initialize Alpha (Leader) Wolf ---
Alpha_pos = zeros(1, dim);
Alpha_score = inf; % Use -inf for maximization problems
Alpha_index = 0;   % Index of the alpha wolf in the pack

% --- Initialize Agent Positions ---
% Randomly distribute the wolves within the search space boundaries.
if numel(lb) == 1
    lb_vec = repmat(lb, 1, dim);
    ub_vec = repmat(ub, 1, dim);
else
    lb_vec = lb;
    ub_vec = ub;
end
Positions = lb_vec + rand(num_agents, dim) .* (ub_vec - lb_vec);

% --- Housekeeping ---
Convergence_curve = zeros(1, max_iterations);
fprintf('PWO Algorithm starting...\n');
fprintf('Iter  |  Best Score Found\n');
fprintf('---------------------------\n');

%==========================================================================
% 2. Main Optimization Loop
%==========================================================================

for t = 1:max_iterations
    
    % --- Fitness Evaluation and Alpha Update ---
    for i = 1:size(Positions, 1)
        % Ensure agents are within the search space boundaries.
        Flag4ub = Positions(i, :) > ub_vec;
        Flag4lb = Positions(i, :) < lb_vec;
        Positions(i, :) = (Positions(i, :) .* (~(Flag4ub + Flag4lb))) + ub_vec .* Flag4ub + lb_vec .* Flag4lb;
        
        % Calculate the objective function for the current wolf
        fitness = fobj(Positions(i, :));
        
        % Store the cost and position for the current wolf
        pack(i).Cost = fitness;
        pack(i).Position = Positions(i, :);
        
        % Update the Alpha wolf if a better solution is found
        if fitness < Alpha_score
            Alpha_score = fitness;
            Alpha_pos = Positions(i, :);
            Alpha_index = i;
        end
    end
    
    % --- PWO Dynamic Parameters ---
    % 'a' linearly decreases from 2 to 0 to balance exploration and exploitation.
    a = 2 * (1 - (t / max_iterations));
    
    % --- Voting Rally Simulation ---
    % This section simulates the pre-hunting rally. Wolves "vote" based on their
    % fitness relative to the alpha, determining the pack's collective action.
    
    Alpha_influence = abs(VOTE_INCREMENT / a);
    rally_strength = 0; % Renamed from 'sign' for clarity
    
    for i = 1:num_agents
        if i ~= Alpha_index
            % Compare wolf's cost against the alpha's influenced cost
            cost_comparison = pack(i).Cost - (Alpha_influence * Alpha_score);
            if cost_comparison <= Alpha_score
                rally_strength = rally_strength + VOTE_INCREMENT;
            end
        end
    end
    
    % The rally_threshold determines whether the pack will explore or exploit.
    E0 = 2 * rand() - rand();
    rally_threshold = round((a * E0 / Alpha_influence + rand()));

    % --- Position Update Mechanism ---
    for i = 1:num_agents
        for j = 1:dim % Loop over each dimension
            r1 = rand();
            r2 = rand();
            
            A1 = 2 * a * r1 - a; % Corresponds to Eq. (2.7) in the paper
            
            if rally_strength < rally_threshold
                % EXPLORATION PHASE (Searching for prey)
                % The pack scatters to find new potential solutions.
                q = rand();
                if q < 0.5
                    % Move towards a random wolf
                    rand_agent_idx = floor(num_agents * rand() + 1);
                    X_rand = Positions(rand_agent_idx, :);
                    
                    vel = 2 * Alpha_influence * r1 + r2;
                    D_X_rand = abs(vel * X_rand(j) - Positions(i, j));
                    
                    % NOTE: The following line is a specific mechanism of this algorithm.
                    % It intentionally uses a scalar value derived from a single dimension (j)
                    % to update the entire position vector.
                    Positions(i, :) = X_rand(j) - A1 * D_X_rand;
                    
                else % q >= 0.5
                    % Alternative exploration strategy based on alpha and pack mean
                    Positions(i, :) = (Alpha_pos - mean(Positions)) - rally_strength * abs(Alpha_pos - Positions(i, :));
                end
            else % rally_strength >= rally_threshold
                % EXPLOITATION PHASE (Attacking the prey)
                % The pack converges on the best solution found so far (the alpha).
                D_alpha = abs(Alpha_pos(j) - Positions(i, j));
                A2 = rally_strength + a * A1 * Alpha_influence;
                Positions(i, j) = Alpha_pos(j) - A2 * D_alpha;
            end
        end
    end
    
    Convergence_curve(t) = Alpha_score;
    
    % Display progress at intervals
    if mod(t, 20) == 0 || t == 1 || t == max_iterations
        fprintf('%5d |  %e\n', t, Alpha_score);
    end
end

fprintf('---------------------------\n');
fprintf('PWO Algorithm Finished.\n');
fprintf('Best Score Found: %e\n', Alpha_score);

end
