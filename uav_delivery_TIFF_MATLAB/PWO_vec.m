function [best_fitness, best_solution, Convergence_curve] = PWO_vec(N, maxFES, lb, ub, dim, fobj)
% PWO_vec - Faithful, batch-evaluation version of Painted Wolf Optimization (PWO).
%
% This function preserves the update equations and the scalar-replication
% exploration behaviour of the published PWO.m, but batches all objective
% evaluations through a single call to fobj(X) (X is N x dim) so that the
% CEC2017 10000*D evaluation budget can actually be executed in high
% dimensions.  Progress printing is removed.  The population mean used in
% the exploration branch is evaluated once per iteration for tractability
% (the original recomputes mean() inside the dimension loop, which is an
% O(N*D^2) implementation detail rather than part of the update rule).

    if numel(lb) == 1
        lb = lb .* ones(1, dim);
        ub = ub .* ones(1, dim);
    end
    lb = lb(:).';
    ub = ub(:).';

    VOTE_INCREMENT = 0.04;

    Positions = lb + (ub - lb) .* rand(N, dim);
    Alpha_pos = zeros(1, dim);
    Alpha_score = inf;
    Alpha_index = 0;

    FES = 0;
    t = 0;
    T = max(1, floor(maxFES / N));
    Convergence_curve = zeros(1, T);

    while FES + N <= maxFES
        t = t + 1;

        % Boundary handling and batch fitness evaluation.
        Positions = min(max(Positions, lb), ub);
        fitness = reshape(fobj(Positions), [], 1);
        FES = FES + N;

        % Update alpha (best ever) sequentially, as in the original.
        for i = 1:N
            if fitness(i) < Alpha_score
                Alpha_score = fitness(i);
                Alpha_pos = Positions(i, :);
                Alpha_index = i;
            end
        end

        % Dynamic exploration-exploitation parameter.
        a = 2 * (1 - t / T);
        if a < eps, a = eps; end
        Alpha_influence = abs(VOTE_INCREMENT / a);

        % Voting rally simulation.
        rally_strength = 0;
        for i = 1:N
            if i ~= Alpha_index
                cost_comparison = fitness(i) - (Alpha_influence * Alpha_score);
                if cost_comparison <= Alpha_score
                    rally_strength = rally_strength + VOTE_INCREMENT;
                end
            end
        end

        E0 = 2 * rand() - rand();
        rally_threshold = round((a * E0 / Alpha_influence + rand()));

        pop_mean = mean(Positions, 1);

        for i = 1:N
            if rally_strength < rally_threshold
                % EXPLORATION PHASE.
                q = rand();
                if q < 0.5
                    k = randi(N);
                    X_rand = Positions(k, :);
                    r1 = rand(1, dim);
                    r2 = rand(1, dim);
                    A1 = 2 * a * r1 - a;
                    vel = 2 * Alpha_influence * r1 + r2;
                    % Original scalar-replication behaviour: the whole row is
                    % overwritten by a scalar derived from one dimension.
                    j = dim;
                    D_X_rand = abs(vel(j) * X_rand(j) - Positions(i, j));
                    Positions(i, :) = X_rand(j) - A1(j) * D_X_rand;
                else
                    Positions(i, :) = (Alpha_pos - pop_mean) - ...
                        rally_strength * abs(Alpha_pos - Positions(i, :));
                end
            else
                % EXPLOITATION PHASE.
                r1 = rand(1, dim);
                r2 = rand(1, dim);
                A1 = 2 * a * r1 - a;
                D_alpha = abs(Alpha_pos - Positions(i, :));
                A2 = rally_strength + a .* A1 .* Alpha_influence;
                Positions(i, :) = Alpha_pos - A2 .* D_alpha;
            end
        end

        Convergence_curve(t) = Alpha_score;
    end

    best_fitness = Alpha_score;
    best_solution = Alpha_pos;
    Convergence_curve = Convergence_curve(1:t);
end
