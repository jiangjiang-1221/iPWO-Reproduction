function run_ablation_rally(funcs, runs, pop, tag, useParallel)
% run_ablation_rally - Ablation to isolate the PWO rally contribution at D=30.
% Variants:
%   1 iPWO           : rally + ECR + NAS + OED
%   2 SHADE          : pure current-to-pbest/1 (no rally, no ECR, no OED)
%   3 SHADE_ECR_OED  : SHADE + ECR + OED (no rally)
%   4 PWO            : original PWO baseline

    script_dir = fileparts(mfilename('fullpath'));
    if isempty(script_dir)
        script_dir = pwd;
    end
    root = fileparts(script_dir);
    cd(script_dir);

    dim = 30;
    if nargin < 1 || isempty(funcs), funcs = [1, 3:30]; end
    if nargin < 2 || isempty(runs),  runs  = 51;        end
    if nargin < 3 || isempty(pop),   pop   = 50;        end
    if nargin < 4 || isempty(tag),   tag   = '';        end
    if nargin < 5 || isempty(useParallel), useParallel = false; end
    useParallel = logical(useParallel);

    funcs = funcs(:).';
    variants = {'iPWO', 'SHADE', 'SHADE_ECR_OED', 'PWO'};
    nVar = numel(variants);
    nF = numel(funcs);
    Lcurve = 1000;

    outdir = fullfile(root, 'data', 'ablation_rally_results');
    figsdir = fullfile(root, 'figures', 'ablation_rally_results');
    if ~exist(outdir, 'dir'), mkdir(outdir); end
    if ~exist(figsdir, 'dir'), mkdir(figsdir); end

    % Serial by default; pass useParallel=true to use a local parpool.

    out = cell(nF, 1);
    fprintf('Rally ablation: functions=%d, runs=%d, variants=%d\n', nF, runs, nVar);
    t0 = tic;

    if useParallel
        pool = gcp('nocreate');
        if isempty(pool), pool = parpool('local'); end
        pctRunOnAll(sprintf('addpath(''%s'')', script_dir));
        parfor k = 1:nF
            out{k} = run_one_task(funcs(k), dim, runs, nVar, Lcurve, pop); %#ok<PFBNS>
        end
    else
        addpath(script_dir);
        for k = 1:nF
            out{k} = run_one_task(funcs(k), dim, runs, nVar, Lcurve, pop);
        end
    end

    fprintf('Run phase done: %.1f s\n', toc(t0));

    summary_rows = {};
    for k = 1:nF
        s = out{k};
        f = s.f;
        S = s.S;
        C = s.C;
        best = min(S, [], 1);
        med = median(S, 1);
        meanv = mean(S, 1);
        stdv = std(S, 0, 1);
        pv = nan(1, nVar);
        better = zeros(1, nVar);
        for v = 2:nVar
            pv(v) = ranksum(S(:, 1), S(:, v));
            better(v) = (med(1) < med(v)) && (pv(v) < 0.05);
        end
        save_conv_fig(dim, f, C, variants, Lcurve, figsdir);
        save_box_fig(dim, f, S, variants, figsdir);
        for v = 1:nVar
            summary_rows(end + 1, :) = {f, variants{v}, best(v), med(v), ...
                meanv(v), stdv(v), pv(v), double(better(v))}; %#ok<AGROW>
        end
    end

    summary_table = cell2table(summary_rows, 'VariableNames', { ...
        'Func', 'Variant', 'Best', 'Median', 'Mean', 'Std', 'p_vs_iPWO', 'iPWO_better'});
    writetable(summary_table, fullfile(outdir, sprintf('summary_rally%s.csv', tag)));

    sel = [out{:}];
    Sall = cat(3, sel.S);   % runs x nVar x nF
    Call = cat(3, sel.C);   % Lcurve x nVar x nF
    fnames = [sel.f];
    save(fullfile(outdir, sprintf('results_rally_D30%s.mat', tag)), 'dim', 'fnames', 'Sall', 'Call', 'variants', 'runs', 'pop');
    if isempty(tag), save_rank_fig(dim, fnames, Sall, variants, outdir, figsdir); end

    fprintf('All rally ablation results saved: %s\n', outdir);
    fprintf('Total elapsed: %.1f s\n', toc(t0));
end

% ========================================================================
function s = run_one_task(f, dim, runs, nVar, Lcurve, pop)
    [lb, ub, ~, ~] = Get_Functions_cec2017(f, dim);
    fobj = @(X) cec17_func(X', f);
    maxFES = 10000 * dim;

    S = zeros(runs, nVar);
    C = zeros(Lcurve, nVar);
    for r = 1:runs
        seed = 2000000 + dim * 10000 + f * 100 + r;
        for v = 1:nVar
            rng(seed);
            sc = inf;
            cg = [];
            switch v
                case 1
                    [sc, ~, cg] = iPWO_abl(pop, maxFES, lb, ub, dim, fobj, true, true, true, true);
                case 2
                    [sc, ~, cg] = iPWO_abl(pop, maxFES, lb, ub, dim, fobj, false, false, false, false);
                case 3
                    [sc, ~, cg] = iPWO_abl(pop, maxFES, lb, ub, dim, fobj, true, false, true, false);
                case 4
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
    s = struct('f', f, 'S', S, 'C', C);
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
    ch6_print(fig, fullfile(figsdir, sprintf('conv_F%d.tif', f)));
end

% ========================================================================
function save_box_fig(dim, f, S, variants, figsdir)
    fig = figure('Visible', 'off', 'Position', [100 100 1000 720]);
    boxplot(S, 'Labels', variants);
    set(gca, 'YScale', 'log');
    grid on;
    ylabel('Best Score');
    title(sprintf('Boxplot - D=%d, F%d', dim, f));
    ch6_print(fig, fullfile(figsdir, sprintf('box_F%d.tif', f)));
end

% ========================================================================
function save_rank_fig(dim, funcs, Sd, variants, outdir, figsdir)
    nVar = size(Sd, 2);
    nF = size(Sd, 3);
    mean_per_func = squeeze(mean(Sd, 1));
    ranks = nan(nF, nVar);
    for f = 1:nF
        [~, ord] = sort(mean_per_func(:, f));
        ranks(f, ord) = 1:nVar;
    end
    avg_rank = mean(ranks, 1, 'omitnan');

    fig = figure('Visible', 'off', 'Position', [100 100 900 620]);
    bar(avg_rank, 'FaceColor', [0.18 0.45 0.75]);
    set(gca, 'XTickLabel', variants);
    ylabel('Average Rank (lower is better)');
    title(sprintf('Average Rank - D=%d', dim));
    grid on;
    ylim([0 nVar + 1]);
    ch6_print(fig, fullfile(figsdir, 'avg_rank.tif'));

    writetable(array2table(ranks, 'VariableNames', cellstr(variants)), fullfile(outdir, 'ranks.csv'));
    fid = fopen(fullfile(outdir, 'avg_rank.txt'), 'w');
    for v = 1:nVar
        fprintf(fid, '%s\t%.4f\n', variants{v}, avg_rank(v));
    end
    fclose(fid);
end
