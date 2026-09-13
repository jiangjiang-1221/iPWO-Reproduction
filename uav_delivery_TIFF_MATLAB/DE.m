function [bestFitness, best_pos, Convergence_curve] = DE(N, MaxFEs, lb, ub, dim, fobj)
% DE - differential evolution DE/rand/1/bin (classic baseline)
%   Interface identical to LASBO: (N, MaxFEs, lb, ub, dim, fobj)
%   Storn & Price (1997). F = 0.5, CR = 0.9.

    if isscalar(lb), lb = repmat(lb, 1, dim); else, lb = lb(:)'; end
    if isscalar(ub), ub = repmat(ub, 1, dim); else, ub = ub(:)'; end
    range = ub - lb;

    F = 0.5; CR = 0.9;
    maxIter = ceil(MaxFEs / N);
    Convergence_curve = zeros(1, maxIter);

    X = rand(N, dim) .* repmat(range, N, 1) + repmat(lb, N, 1);
    Fit = inf(N, 1);
    FEs = 0;
    for i = 1:N
        Fit(i) = fobj(X(i, :));
        FEs = FEs + 1;
    end
    [bestFitness, bi] = min(Fit);
    best_pos = X(bi, :);

    iter = 1;
    while FEs < MaxFEs && iter <= maxIter
        for i = 1:N
            idx = randperm(N, 3);
            while any(idx == i)
                idx = randperm(N, 3);
            end
            v = X(idx(1), :) + F * (X(idx(2), :) - X(idx(3), :));
            v = max(min(v, ub), lb);

            jrand = randi(dim);
            mask = rand(1, dim) < CR;
            mask(jrand) = true;
            u = X(i, :);
            u(mask) = v(mask);

            if FEs >= MaxFEs, break; end
            fu = fobj(u);
            FEs = FEs + 1;

            if fu < Fit(i)
                X(i, :) = u;
                Fit(i) = fu;
                if fu < bestFitness
                    bestFitness = fu;
                    best_pos = u;
                end
            end
        end
        Convergence_curve(iter) = bestFitness;
        iter = iter + 1;
    end
    Convergence_curve = Convergence_curve(1:iter-1);
end
