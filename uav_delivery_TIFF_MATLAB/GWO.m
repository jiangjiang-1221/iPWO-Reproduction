function [bestFitness, best_pos, Convergence_curve] = GWO(N, MaxFEs, lb, ub, dim, fobj)
% GWO - grey wolf optimizer (classic baseline)
%   Interface identical to LASBO: (N, MaxFEs, lb, ub, dim, fobj)
%   Mirjalili et al. (2014). a decreases linearly 2 -> 0.

    if isscalar(lb), lb = repmat(lb, 1, dim); else, lb = lb(:)'; end
    if isscalar(ub), ub = repmat(ub, 1, dim); else, ub = ub(:)'; end
    range = ub - lb;

    maxIter = ceil(MaxFEs / N);
    Convergence_curve = zeros(1, maxIter);

    Alpha_pos = zeros(1, dim); Alpha_score = inf;
    Beta_pos  = zeros(1, dim); Beta_score  = inf;
    Delta_pos = zeros(1, dim); Delta_score = inf;

    X = rand(N, dim) .* repmat(range, N, 1) + repmat(lb, N, 1);
    FEs = 0;
    iter = 1;

    while FEs < MaxFEs && iter <= maxIter
        for i = 1:N
            X(i, :) = max(min(X(i, :), ub), lb);
            if FEs >= MaxFEs, break; end
            f = fobj(X(i, :));
            FEs = FEs + 1;

            if f < Alpha_score
                Delta_score = Beta_score;  Delta_pos = Beta_pos;
                Beta_score  = Alpha_score; Beta_pos  = Alpha_pos;
                Alpha_score = f;           Alpha_pos = X(i, :);
            elseif f < Beta_score
                Delta_score = Beta_score;  Delta_pos = Beta_pos;
                Beta_score  = f;           Beta_pos  = X(i, :);
            elseif f < Delta_score
                Delta_score = f;           Delta_pos = X(i, :);
            end
        end

        a = 2 - (iter - 1) * (2 / max(1, maxIter - 1));
        for i = 1:N
            for j = 1:dim
                r1 = rand; r2 = rand;
                A1 = 2*a*r1 - a; C1 = 2*r2;
                D_alpha = abs(C1*Alpha_pos(j) - X(i, j));
                X1 = Alpha_pos(j) - A1*D_alpha;

                r1 = rand; r2 = rand;
                A2 = 2*a*r1 - a; C2 = 2*r2;
                D_beta = abs(C2*Beta_pos(j) - X(i, j));
                X2 = Beta_pos(j) - A2*D_beta;

                r1 = rand; r2 = rand;
                A3 = 2*a*r1 - a; C3 = 2*r2;
                D_delta = abs(C3*Delta_pos(j) - X(i, j));
                X3 = Delta_pos(j) - A3*D_delta;

                X(i, j) = (X1 + X2 + X3) / 3;
            end
        end

        Convergence_curve(iter) = Alpha_score;
        iter = iter + 1;
    end
    Convergence_curve = Convergence_curve(1:iter-1);
    bestFitness = Alpha_score;
    best_pos = Alpha_pos;
end
