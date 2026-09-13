function run_scaling_iPWO(funcs, dims, runs, pop, tag, useParallel)
% run_scaling_iPWO - Light dimension-scalability check: iPWO vs PWO on CEC2017.
% Reuses the proven setup from run_ablation_rally.m:
%   fobj = @(X) cec17_func(X', f)
%   full iPWO  -> iPWO_abl(pop, maxFES, lb, ub, dim, fobj, true,true,true,true)
%   baseline   -> PWO_vec(pop, maxFES, lb, ub, dim, fobj)
% Only 10 representative functions are used to keep the run light; both
% algorithms are evaluated under the SAME budget/functions so the figure is fair.

    script_dir = fileparts(mfilename('fullpath'));
    if isempty(script_dir), script_dir = pwd; end
    root = fileparts(script_dir);
    cd(script_dir);
    addpath(script_dir);

    % ---- user-tunable (light) settings ----
    if nargin < 1 || isempty(funcs), funcs = [1, 4, 5, 6, 7, 8, 9, 10, 15, 21]; end
    if nargin < 2 || isempty(dims),   dims  = [30, 50, 100]; end
    if nargin < 3 || isempty(runs),   runs  = 51;  end
    if nargin < 4 || isempty(pop),    pop   = 50;  end
    if nargin < 5 || isempty(tag),    tag   = '';  end
    if nargin < 6 || isempty(useParallel), useParallel = false; end
    useParallel = logical(useParallel);

    funcs = funcs(:).';
    variants = {'iPWO', 'PWO'};
    nVar = numel(variants);
    nF = numel(funcs);
    Lcurve = 1000;

    outdir = fullfile(root, 'data', 'scaling_iPWO_results');
    if ~exist(outdir, 'dir'), mkdir(outdir); end
    figsdir = fullfile(root, 'figures');
    if ~exist(figsdir, 'dir'), mkdir(figsdir); end

    % Serial by default; pass useParallel=true to use a local parpool.

    for d_idx = 1:numel(dims)
        dim = dims(d_idx);
        maxFES = 10000 * dim;

        % preallocate per-dimension results
        Sall = zeros(runs, nVar, nF);
        Call = zeros(Lcurve, nVar, nF);
        medV = zeros(nF, nVar);
        meanV = zeros(nF, nVar);
        medAll = zeros(nF, nVar, numel(dims));

        fprintf('\n===== Dimension D=%d (runs=%d, maxFES=%d) =====\n', dim, runs, maxFES);
        t0 = tic;

        if useParallel
            pool = gcp('nocreate');
            if isempty(pool), pool = parpool('local', 4); end
            pctRunOnAll(sprintf('addpath(''%s'')', script_dir));
            parfor k = 1:nF
                s = run_one_task(funcs(k), dim, runs, nVar, Lcurve, pop); %#ok<PFBNS>
                Sall(:,:,k) = s.S;
                Call(:,:,k) = s.C;
                medV(k,:)  = s.med;
                meanV(k,:) = s.mean;
            end
        else
            addpath(script_dir);
            for k = 1:nF
                s = run_one_task(funcs(k), dim, runs, nVar, Lcurve, pop);
                Sall(:,:,k) = s.S;
                Call(:,:,k) = s.C;
                medV(k,:)  = s.med;
                meanV(k,:) = s.mean;
            end
        end
        medAll(:,:,d_idx) = medV;

        fprintf('D=%d done: %.1f s\n', dim, toc(t0));

        % ---- save per dimension ----
        save(fullfile(outdir, sprintf('results_scaling_D%d%s.mat', dim, tag)), ...
            'dim', 'funcs', 'runs', 'pop', 'maxFES', 'variants', ...
            'Sall', 'Call', 'medV', 'meanV');

        % ---- per-function CSV for inspection ----
        T = array2table([funcs(:), medV, meanV], ...
            'VariableNames', {'Func','iPWO_med','PWO_med','iPWO_mean','PWO_mean'});
        writetable(T, fullfile(outdir, sprintf('summary_scaling_D%d.csv', dim)));
    end

    % ---- 维度可扩展性图（中位数目标，跨函数均值，iPWO vs PWO）----
    meanMed = squeeze(mean(medAll, 1));     % nVar x nDims
    save(fullfile(outdir, 'scaling_summary.mat'), 'dims', 'funcs', 'variants', 'meanMed');
    Tsum = array2table(meanMed', 'VariableNames', variants);
    Tsum.Dimension = dims(:);
    writetable(Tsum, fullfile(outdir, 'scaling_summary.csv'));
    fig = figure('Visible', 'off', 'Position', [100 100 1000 720]);
    hold on;
    plot(dims, meanMed(1, :), 'o-', 'LineWidth', 2, 'Color', [0.90 0.15 0.20], 'MarkerSize', 10, 'DisplayName', 'iPWO');
    plot(dims, meanMed(2, :), 's--', 'LineWidth', 2, 'Color', [0.18 0.48 0.80], 'MarkerSize', 10, 'DisplayName', 'PWO');
    hold off;
    set(gca, 'XScale', 'log', 'YScale', 'log');
    grid on;
    xlabel('Dimension D (log)');
    ylabel('Median objective (log, lower is better)');
    % 标题原为单行, 27pt 下太宽、向左伸到 y 轴刻度标签上方,
    % 与顶部 10^10 的指数部分相撞; 拆两行后宽度减半。
    title({'Dimension scalability:', 'iPWO vs PWO on CEC2017'});
    % legend 原为 northwest, 会与上方标题重叠; 移到绘图区左侧中部空白带.
    legend('Location', 'west', 'Interpreter', 'none');
    if isempty(tag), ch6_print(fig, fullfile(figsdir, 'scaling_D.tif')); end

    fprintf('\nALL DIMENSIONS DONE. Results in: %s\n', outdir);
end

% ========================================================================
function s = run_one_task(f, dim, runs, nVar, Lcurve, pop)
    [lb, ub, ~, ~] = Get_Functions_cec2017(f, dim);
    fobj = @(X) cec17_func(X', f);
    maxFES = 10000 * dim;

    S = zeros(runs, nVar);
    C = zeros(Lcurve, nVar);
    for r = 1:runs
        seed = 3000000 + dim * 10000 + f * 100 + r;
        for v = 1:nVar
            rng(seed);
            sc = inf; cg = [];
            if v == 1
                [sc, ~, cg] = iPWO_abl(pop, maxFES, lb, ub, dim, fobj, true, true, true, true);
            else
                [sc, ~, cg] = PWO_vec(pop, maxFES, lb, ub, dim, fobj);
            end
            S(r, v) = sc;
            cg = cg(:);
            if isempty(cg), cg = sc; end
            cc = interp1((1:numel(cg))', cg, linspace(1, numel(cg), Lcurve)', 'linear', 'extrap');
            C(:, v) = C(:, v) + cc;
        end
    end
    C = C ./ runs;
    s = struct('S', S, 'C', C, 'med', median(S, 1), 'mean', mean(S, 1));
end
