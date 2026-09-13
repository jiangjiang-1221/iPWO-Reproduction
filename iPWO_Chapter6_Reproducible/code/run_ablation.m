function run_ablation(dims, funcs, runs, pop, tag, useParallel)
% run_ablation - Ablation study for iPWO on CEC2017.
% Variants:
%   1 iPWO   (full: ECR + NAS + OED)
%   2 noECR  (remove entropy monitor + chaotic reset)
%   3 noOED  (remove orthogonal local refinement)
%   4 noNAS  (replace nonlinear adaptive control with linear/fixed PWO params)
%   5 PWO    (original baseline)

    script_dir = fileparts(mfilename('fullpath'));
    if isempty(script_dir)
        script_dir = pwd;
    end
    root = fileparts(script_dir);
    cd(script_dir);

    if nargin < 1 || isempty(dims),  dims  = [10 30];   end
    if nargin < 2 || isempty(funcs), funcs = [1, 3:30]; end
    if nargin < 3 || isempty(runs),  runs  = 51;        end
    if nargin < 4 || isempty(pop),   pop   = 50;        end
    if nargin < 5 || isempty(tag),   tag   = '';        end
    if nargin < 6 || isempty(useParallel), useParallel = false; end
    useParallel = logical(useParallel);

    funcs = funcs(:).';
    dims = dims(:).';
    variants = {'iPWO', 'noECR', 'noOED', 'noNAS', 'PWO'};
    nVar = numel(variants);
    nF = numel(funcs);
    Lcurve = 1000;

    outdir = fullfile(root, 'data', 'ablation_results');
    figsdir = fullfile(root, 'figures', 'ablation_results');
    if ~exist(outdir, 'dir'), mkdir(outdir); end
    if ~exist(figsdir, 'dir'), mkdir(figsdir); end

    % Serial by default; pass useParallel=true to use a local parpool.

    tasks = zeros(numel(dims) * nF, 2);
    idx = 0;
    for di = 1:numel(dims)
        for fi = 1:nF
            idx = idx + 1;
            tasks(idx, :) = [dims(di), funcs(fi)];
        end
    end
    nTasks = size(tasks, 1);

    fprintf('Ablation: tasks=%d, runs=%d, variants=%d\n', nTasks, runs, nVar);
    t0 = tic;

    out = cell(nTasks, 1);

    if useParallel
        pool = gcp('nocreate');
        if isempty(pool), pool = parpool('local'); end
        pctRunOnAll(sprintf('addpath(''%s'')', script_dir));
        parfor k = 1:nTasks
            out{k} = run_one_task(tasks(k, 1), tasks(k, 2), runs, nVar, Lcurve, pop); %#ok<PFBNS>
        end
    else
        addpath(script_dir);
        for k = 1:nTasks
            out{k} = run_one_task(tasks(k, 1), tasks(k, 2), runs, nVar, Lcurve, pop);
        end
    end

    fprintf('Run phase done: %.1f s\n', toc(t0));

    % Aggregate, save data and figures.
    summary_rows = {};
    for k = 1:nTasks
        s = out{k};
        dim = s.dim;
        f = s.f;
        S = s.S;
        C = s.C;

        best = min(S, [], 1);
        med = median(S, 1);
        meanv = mean(S, 1);
        stdv = std(S, 0, 1);

        pv = nan(1, nVar);
        better = zeros(1, nVar);
        for v = 1:nVar
            if v == 1, continue; end
            pv(v) = ranksum(S(:, 1), S(:, v));
            better(v) = (med(1) < med(v)) && (pv(v) < 0.05);
        end

        save_conv_fig(dim, f, C, variants, Lcurve, figsdir);
        save_box_fig(dim, f, S, variants, figsdir);

        for v = 1:nVar
            summary_rows(end + 1, :) = {dim, f, variants{v}, ...
                best(v), med(v), meanv(v), stdv(v), pv(v), double(better(v))}; %#ok<AGROW>
        end
    end

    summary_table = cell2table(summary_rows, 'VariableNames', { ...
        'Dim', 'Func', 'Variant', 'Best', 'Median', 'Mean', 'Std', ...
        'p_vs_iPWO', 'iPWO_better'});
    writetable(summary_table, fullfile(outdir, sprintf('summary_ablation%s.csv', tag)));

    % Per-dimension raw data and average-rank figure.
    for di = 1:numel(dims)
        d = dims(di);
        sel = [out{:}];
        sel = sel([sel.dim] == d);
        Sd = cat(3, sel.S);        % runs x nVar x nF
        Cd = cat(3, sel.C);        % Lcurve x nVar x nF
        fd = [sel.f];
        save(fullfile(outdir, sprintf('results_ablation_D%d%s.mat', d, tag)), ...
            'd', 'fd', 'Sd', 'Cd', 'variants', 'runs', 'pop');
        if isempty(tag), save_rank_fig(d, fd, Sd, variants, outdir, figsdir); end
    end

    fprintf('All ablation results saved: %s\n', outdir);
    fprintf('Total elapsed: %.1f s\n', toc(t0));
end

% ========================================================================
function s = run_one_task(dim, f, runs, nVar, Lcurve, pop)
    [lb, ub, ~, ~] = Get_Functions_cec2017(f, dim);
    fobj = @(X) cec17_func(X', f);
    maxFES = 10000 * dim;

    S = zeros(runs, nVar);
    C = zeros(Lcurve, nVar);

    for r = 1:runs
        seed = 1000000 + dim * 10000 + f * 100 + r;
        for v = 1:nVar
            rng(seed);
            sc = inf;
            cg = [];
            switch v
                case 1
                    [sc, ~, cg] = iPWO_abl(pop, maxFES, lb, ub, dim, fobj, true, true, true, true);
                case 2
                    [sc, ~, cg] = iPWO_abl(pop, maxFES, lb, ub, dim, fobj, false, true, true, true);
                case 3
                    [sc, ~, cg] = iPWO_abl(pop, maxFES, lb, ub, dim, fobj, true, true, false, true);
                case 4
                    [sc, ~, cg] = iPWO_abl(pop, maxFES, lb, ub, dim, fobj, true, false, true, true);
                case 5
                    [sc, ~, cg] = PWO_vec(pop, maxFES, lb, ub, dim, fobj);
            end

            S(r, v) = sc;
            cg = cg(:);
            if isempty(cg)
                cg = sc;
            end
            cc = interp1((1:numel(cg))', cg, ...
                linspace(1, numel(cg), Lcurve)', 'linear', 'extrap');
            C(:, v) = C(:, v) + cc;
        end
    end
    C = C ./ runs;
    s = struct('dim', dim, 'f', f, 'S', S, 'C', C);
end

% ========================================================================
function save_conv_fig(dim, f, C, variants, Lcurve, figsdir)
    fig = figure('Visible', 'off', 'Position', [100 100 1200 780]);
    colors = lines(numel(variants));
    hold on;
    for v = 1:numel(variants)
        y = C(:, v);
        y(y <= 0) = eps;
        semilogy(1:Lcurve, y, 'LineWidth', 1.6, 'Color', colors(v, :));
    end
    hold off;
    grid on;
    xlabel('Iteration');
    ylabel('Best Score');
    title(sprintf('Convergence - D=%d, F%d', dim, f));
    legend(variants, 'Location', 'northeast', 'Interpreter', 'none');
    outfile = fullfile(figsdir, sprintf('conv_D%d_F%d.tif', dim, f));
    ch6_print(fig, outfile);
end

% ========================================================================
function save_box_fig(dim, f, S, variants, figsdir)
    fig = figure('Visible', 'off', 'Position', [100 100 1000 720]);
    boxplot(S, 'Labels', variants);
    set(gca, 'YScale', 'log');
    grid on;
    ylabel('Best Score');
    title(sprintf('Boxplot - D=%d, F%d', dim, f));
    outfile = fullfile(figsdir, sprintf('box_D%d_F%d.tif', dim, f));
    ch6_print(fig, outfile);
end

% ========================================================================
function save_rank_fig(dim, funcs, Sd, variants, outdir, figsdir)
    nVar = size(Sd, 2);
    nF = size(Sd, 3);
    mean_per_func = squeeze(mean(Sd, 1));   % nVar x nF
    ranks = nan(nF, nVar);
    for f = 1:numel(funcs)
        row = mean_per_func(:, f);
        [~, ord] = sort(row);
        ranks(f, ord) = 1:nVar;
    end
    avg_rank = mean(ranks, 1, 'omitnan');

    fig = figure('Visible', 'off', 'Position', [100 100 900 620]);
    b = bar(avg_rank, 'FaceColor', [0.18 0.45 0.75]);
    set(gca, 'XTickLabel', variants);
    ylabel('Average Rank (lower is better)');
    title(sprintf('Friedman-style Average Rank - D=%d', dim));
    grid on;
    ylim([0 nVar + 1]);
    outfile = fullfile(figsdir, sprintf('avg_rank_D%d.tif', dim));
    ch6_print(fig, outfile);

    T = array2table(ranks, 'VariableNames', cellstr(variants));
    T.Func = funcs(:);
    writetable(T, fullfile(outdir, sprintf('ranks_D%d.csv', dim)));
    fid = fopen(fullfile(outdir, sprintf('avg_rank_D%d.txt', dim)), 'w');
    for v = 1:nVar
        fprintf(fid, '%s\t%.4f\n', variants{v}, avg_rank(v));
    end
    fclose(fid);
end
