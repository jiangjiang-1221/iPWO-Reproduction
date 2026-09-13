function [bestFitness, best_pos, Convergence_curve] = PSO(N, MaxFEs, lb, ub, dim, fobj)
% PSO - standard global-best particle swarm optimization (classic baseline)
%   Interface identical to LASBO: (N, MaxFEs, lb, ub, dim, fobj)
%   Kennedy & Eberhart (1995) with linearly decreasing inertia weight.
%   w: 0.9 -> 0.4, c1 = c2 = 1.49445, Vmax = 0.2*(ub-lb)

    if isscalar(lb), lb = repmat(lb, 1, dim); else, lb = lb(:)'; end
    if isscalar(ub), ub = repmat(ub, 1, dim); else, ub = ub(:)'; end
    range = ub - lb;

    w_max = 0.9; w_min = 0.4;
    c1 = 1.49445; c2 = 1.49445;
    Vmax = 0.2 * range;

    maxIter = ceil(MaxFEs / N);
    Convergence_curve = zeros(1, maxIter);

    X = rand(N, dim) .* repmat(range, N, 1) + repmat(lb, N, 1);
    V = (rand(N, dim) * 2 - 1) .* repmat(Vmax, N, 1);

    pbest_X = X;
    pbest_F = inf(N, 1);
    FEs = 0;

    for i = 1:N
        pbest_F(i) = fobj(X(i, :));
        FEs = FEs + 1;
    end
    [bestFitness, gi] = min(pbest_F);
    best_pos = pbest_X(gi, :);

    iter = 1;
    while FEs < MaxFEs && iter <= maxIter
        w = w_max - (w_max - w_min) * (iter - 1) / max(1, maxIter - 1);
        for i = 1:N
            V(i, :) = w * V(i, :) ...
                + c1 * rand(1, dim) .* (pbest_X(i, :) - X(i, :)) ...
                + c2 * rand(1, dim) .* (best_pos - X(i, :));
            V(i, :) = max(min(V(i, :), Vmax), -Vmax);
            X(i, :) = X(i, :) + V(i, :);
            X(i, :) = max(min(X(i, :), ub), lb);

            if FEs >= MaxFEs, break; end
            f = fobj(X(i, :));
            FEs = FEs + 1;

            if f < pbest_F(i)
                pbest_F(i) = f;
                pbest_X(i, :) = X(i, :);
                if f < bestFitness
                    bestFitness = f;
                    best_pos = X(i, :);
                end
            end
        end
        Convergence_curve(iter) = bestFitness;
        iter = iter + 1;
    end
    Convergence_curve = Convergence_curve(1:iter-1);
end
