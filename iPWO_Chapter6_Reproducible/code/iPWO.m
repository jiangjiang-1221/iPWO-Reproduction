function [best_fitness, best_solution, Convergence_curve] = iPWO(N, maxFES, lb, ub, dim, fobj)
% iPWO - Improved Painted Wolf Optimization.
%
% The original PWO position update is replaced by a success-history adaptive
% DE core (current-to-pbest/1 with external archive and linear population
% size reduction), while the PWO rally keeps its exploration/exploitation
% role by switching between rand/1 (exploration) and current-to-pbest/1
% (exploitation).  Three targeted innovations are layered on top:
%
%   I1  ECR : Shannon-entropy population monitor + chaotic logistic reset
%             of the worst individuals when the swarm stagnates/collapses.
%   I2  NAS : nonlinear control parameter a_t = 2(1-(t/T)^rho), bounded
%             influence coefficient, entropy-adaptive vote increment, and
%             success-history adaptation of F and CR.
%   I3  OED : two-level orthogonal-experimental-design local refinement
%             around the elite in the late stage.

    if numel(lb) == 1
        lb = lb .* ones(1, dim);
        ub = ub .* ones(1, dim);
    end
    lb = lb(:).';
    ub = ub(:).';
    range = ub - lb;

    NPmin = 4;
    X = lb + range .* rand(N, dim);
    f = reshape(fobj(X), [], 1);
    FES = N;

    pBestX = X;
    pBestF = f;
    [best_fitness, bi] = min(f);
    best_solution = X(bi, :);

    % Success-history memory (SHADE).
    Hmem = 6;
    MF  = 0.5 * ones(1, Hmem);
    MCR = 0.5 * ones(1, Hmem);
    mem_ptr = 1;
    c = 0.1;
    p_pb = 0.11;

    archiveX = zeros(0, dim);
    archiveF = zeros(0, 1);
    archive_cap = 2.6 * N;

    % ECR / NAS / OED controls.
    Q = 10;
    theta = 0.35;
    reset_frac = 0.30;
    V_min = 0.01;
    V_max = 0.20;
    rho = 1.2;
    T = max(1, floor(maxFES / N));
    stall = 0;
    stall_limit = max(10, round(0.10 * T));
    ls_period = max(5, floor(T / 20));
    K_oed = min(3, dim);
    prev_best = best_fitness;

    iter = 0;
    NP = N;
    Convergence_curve = zeros(1, T);

    while FES + NP <= maxFES && iter < T
        iter = iter + 1;
        u = iter / T;

        % ---- I1: entropy monitor ----
        H = population_entropy(X, lb, ub, Q);

        if abs(prev_best - best_fitness) <= 1e-12 * max(1, abs(best_fitness))
            stall = stall + 1;
        else
            stall = 0;
        end

        if stall >= stall_limit && H < theta
            [X, f, pBestX, pBestF, best_fitness, best_solution, FES] = chaotic_reset( ...
                X, f, pBestX, pBestF, best_fitness, best_solution, lb, ub, range, ...
                fobj, FES, maxFES, iter, T, reset_frac);
            NP = size(X, 1);
            stall = 0;
        end
        prev_best = best_fitness;

        % ---- I2: nonlinear adaptive control + rally phase switch ----
        a = 2 * (1 - u^rho);
        if a < 0, a = 0; end
        V = V_min + (V_max - V_min) * H;
        Alpha_influence = V / (a + eps);

        [~, alpha_idx] = min(f);
        rally_strength = 0;
        for i = 1:NP
            if i ~= alpha_idx
                if f(i) - Alpha_influence * best_fitness <= best_fitness
                    rally_strength = rally_strength + V;
                end
            end
        end
        E0 = 2 * rand() - rand();
        rally_threshold = round((a * E0 / Alpha_influence + rand()));
        exploration = rally_strength < rally_threshold;

        % ---- SHADE-style mutation + crossover (vectorized) ----
        [~, sorted] = sort(f);
        pbest_pool = sorted(1:max(2, ceil(p_pb * NP)));

        ri = randi(Hmem, NP, 1);
        Fi = min(max(MF(ri)' + 0.1 * tan(pi * (rand(NP, 1) - 0.5)), 0.05), 1.0);
        CRi = min(max(MCR(ri)' + 0.1 * randn(NP, 1), 0.05), 0.95);

        p = pbest_pool(randi(numel(pbest_pool), NP, 1));
        r1 = randi(NP, NP, 1);
        fix = (r1 == (1:NP)');
        while any(fix)
            r1(fix) = randi(NP, sum(fix), 1);
            fix = (r1 == (1:NP)');
        end

        if exploration
            r2 = randi(NP, NP, 1);
            bad = (r2 == (1:NP)') | (r2 == r1);
            while any(bad)
                r2(bad) = randi(NP, sum(bad), 1);
                bad = (r2 == (1:NP)') | (r2 == r1);
            end
            r3 = randi(NP, NP, 1);
            bad = (r3 == (1:NP)') | (r3 == r1) | (r3 == r2);
            while any(bad)
                r3(bad) = randi(NP, sum(bad), 1);
                bad = (r3 == (1:NP)') | (r3 == r1) | (r3 == r2);
            end
            Vx = X(r1, :) + Fi .* (X(r2, :) - X(r3, :));
        else
            union_size = NP + size(archiveX, 1);
            r2 = randi(union_size, NP, 1);
            bad = (r2 == (1:NP)') | (r2 == r1);
            while any(bad)
                r2(bad) = randi(union_size, sum(bad), 1);
                bad = (r2 == (1:NP)') | (r2 == r1);
            end
            Xr1 = X(r1, :);
            xr2 = zeros(NP, dim);
            pop_idx = r2 <= NP;
            xr2(pop_idx, :) = X(r2(pop_idx), :);
            arch_idx = r2 > NP;
            xr2(arch_idx, :) = archiveX(r2(arch_idx) - NP, :);
            Vx = X + Fi .* (pBestX(p, :) - X) + Fi .* (Xr1 - xr2);
        end

        jrand = randi(dim, NP, 1);
        mask = rand(NP, dim) < CRi;
        lin = (jrand - 1) * NP + (1:NP)';
        mask(lin) = true;

        trial = X;
        trial(mask) = Vx(mask);
        trial = bound_mid(X, lb, ub, trial);

        newF = reshape(fobj(trial), [], 1);
        FES = FES + NP;

        improved = newF <= f;
        strictly = newF < f;
        if any(strictly)
            archiveX = [archiveX; X(strictly, :)]; %#ok<AGROW>
            archiveF = [archiveF; f(strictly)]; %#ok<AGROW>
        end

        old_f = f;
        X(improved, :) = trial(improved, :);
        f(improved) = newF(improved);

        pbetter = newF < pBestF;
        pBestX(pbetter, :) = trial(pbetter, :);
        pBestF(pbetter) = newF(pbetter);

        [iter_best, iter_bi] = min(f);
        if iter_best < best_fitness
            best_fitness = iter_best;
            best_solution = X(iter_bi, :);
        end

        % Success-history update (improvement-weighted).
        if any(improved)
            SF  = Fi(improved);
            SCR = CRi(improved);
            df  = abs(newF(improved) - old_f(improved)) + 1e-30;
            wF  = df / sum(df);
            if any(SF > 0)
                meanL = sum(wF .* SF.^2) / max(sum(wF .* SF), eps);
                MF(mem_ptr) = (1 - c) * MF(mem_ptr) + c * meanL;
            end
            if any(SCR > 0)
                MCR(mem_ptr) = (1 - c) * MCR(mem_ptr) + c * sum(wF .* SCR);
            end
            mem_ptr = mod(mem_ptr, Hmem) + 1;
        end

        % Archive cap.
        if size(archiveX, 1) > archive_cap
            keep = randperm(size(archiveX, 1), round(archive_cap));
            archiveX = archiveX(keep, :);
            archiveF = archiveF(keep);
        end

        % ---- I3: OED local refinement ----
        if mod(iter, ls_period) == 0 && FES + 2^K_oed <= maxFES
            [best_solution, best_fitness, FES] = oed_refine( ...
                best_solution, best_fitness, lb, ub, range, fobj, ...
                FES, maxFES, dim, u, K_oed);
            [~, wi] = max(f);
            X(wi, :) = best_solution;
            f(wi) = best_fitness;
            pBestX(wi, :) = best_solution;
            pBestF(wi) = best_fitness;
        end

        Convergence_curve(iter) = best_fitness;

        % Linear population-size reduction.
        nextNP = max(NPmin, round(N - (N - NPmin) * (FES / maxFES)));
        if nextNP < NP
            remove = NP - nextNP;
            [~, worst] = sort(f, 'descend');
            keep_mask = true(NP, 1);
            keep_mask(worst(1:remove)) = false;
            X = X(keep_mask, :);
            f = f(keep_mask);
            pBestX = pBestX(keep_mask, :);
            pBestF = pBestF(keep_mask);
            NP = nextNP;
            archive_cap = 2.6 * NP;
        end
    end

    Convergence_curve = Convergence_curve(1:iter);
end

% ========================================================================
function H = population_entropy(X, lb, ub, Q)
    [N, D] = size(X);
    if N == 0
        H = 0;
        return;
    end
    range = max(ub - lb, eps);
    Z = (X - lb) ./ range;
    Z = min(max(Z, 0), 1);
    idx = min(Q, max(1, floor(Z * Q) + 1));
    H = 0;
    for j = 1:D
        counts = accumarray(idx(:, j), 1, [Q 1]);
        p = counts / N;
        p = p(p > 0);
        H = H + (-sum(p .* log(p)) / log(Q));
    end
    H = H / D;
end

% ========================================================================
function [X, f, pBestX, pBestF, best_fitness, best_solution, FES] = chaotic_reset( ...
        X, f, pBestX, pBestF, best_fitness, best_solution, lb, ub, range, ...
        fobj, FES, maxFES, t, T, reset_frac)
    [N, D] = size(X);
    [~, order] = sort(f, 'descend');
    W = round(reset_frac * N);
    W = max(2, min(W, N));
    idx = order(1:W);

    newX = zeros(W, D);
    for m = 1:W
        z = rand;
        if z <= 0 || z >= 1, z = 0.37; end
        for j = 1:D
            z = 4 * z * (1 - z);
            if z <= 0 || z >= 1, z = 0.5 + 0.1 * rand; end
            if mod(m, 2) == 1
                newX(m, j) = lb(j) + range(j) * z;
            else
                s = (0.5 * (1 - t / T) + 0.10) * range(j);
                newX(m, j) = best_solution(j) + (2 * z - 1) * s;
            end
        end
    end

    newX = min(max(newX, lb), ub);
    nE = min(W, maxFES - FES);
    if nE <= 0
        return;
    end
    if nE < W
        newX = newX(1:nE, :);
        idx = idx(1:nE);
    end

    fnew = reshape(fobj(newX), [], 1);
    X(idx, :) = newX;
    f(idx) = fnew;
    pBestX(idx, :) = newX;
    pBestF(idx) = fnew;
    FES = FES + nE;

    for q = 1:nE
        if fnew(q) < best_fitness
            best_fitness = fnew(q);
            best_solution = newX(q, :);
        end
    end
end

% ========================================================================
function [best_solution, best_fitness, FES] = oed_refine( ...
        best_solution, best_fitness, lb, ub, range, fobj, FES, maxFES, dim, u, K)
    dims = randperm(dim, K);
    delta = (0.15 * (1 - u) + 0.01) .* range;

    patterns = zeros(2^K, K);
    for r = 0:(2^K - 1)
        bits = bitget(uint8(r), K:-1:1);
        patterns(r + 1, :) = 2 * double(bits) - 1;
    end

    cand = repmat(best_solution, 2^K, 1);
    for r = 1:(2^K)
        for k = 1:K
            j = dims(k);
            cand(r, j) = best_solution(j) + patterns(r, k) * delta(j);
        end
    end
    cand = min(max(cand, lb), ub);

    nE = min(size(cand, 1), maxFES - FES);
    if nE <= 0
        return;
    end
    if nE < size(cand, 1)
        cand = cand(1:nE, :);
    end

    fc = reshape(fobj(cand), [], 1);
    FES = FES + nE;
    [mf, mi] = min(fc);
    if mf < best_fitness
        best_fitness = mf;
        best_solution = cand(mi, :);
    end
end

% ========================================================================
function x = bound_mid(oldx, lb, ub, x)
    lbM = lb(ones(size(x, 1), 1), :);
    ubM = ub(ones(size(x, 1), 1), :);
    below = x < lbM;
    above = x > ubM;
    x(below) = (oldx(below) + lbM(below)) / 2;
    x(above) = (oldx(above) + ubM(above)) / 2;
end
