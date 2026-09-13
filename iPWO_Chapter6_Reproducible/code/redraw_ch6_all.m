function redraw_ch6_all()
% redraw_ch6_all - Redraw ALL Chapter-6 figures from SAVED data
% (no re-optimization). Font styling (Times New Roman, 18pt, 330 DPI)
% is applied centrally by ch6_print.
%
%   1) runtime_times.tif        via redraw_runtime()   (data/runtime_times.csv)
%   2) scaling_D.tif            via finalize_scaling() (data/scaling_iPWO_results)
%   3) sensitivity_theta_rho    from data CSVs
%   4) ablation_results/        from results_ablation_D{10,30}.mat
%   5) ablation_rally_results/  from results_rally_D30.mat

    script_dir = fileparts(mfilename('fullpath'));
    if isempty(script_dir), script_dir = pwd; end
    root = fileparts(script_dir);
    cd(script_dir); addpath(script_dir);
    datadir = fullfile(root, 'data');
    figsdir = fullfile(root, 'figures');

    %% 1) runtime figure (existing helper, uses ch6_print)
    redraw_runtime();

    %% 2) scaling figure (existing helper, pure data aggregation)
    finalize_scaling();

    %% 3) sensitivity heatmap from saved CSVs
    Z = readmatrix(fullfile(datadir, 'sensitivity_theta_rho.csv'));
    A = readmatrix(fullfile(datadir, 'sensitivity_axis.csv'), 'NumHeaderLines', 1);
    thetas = unique(A(:, 1));
    rhos   = unique(A(:, 2));
    fig = figure('Visible', 'off', 'Position', [100 100 820 680]);
    imagesc(rhos, thetas, Z);
    colorbar;
    xlabel('\rho');
    ylabel('\theta');
    title('Sensitivity of iPWO to \theta and \rho (F10, D=10, mean of 5 runs)');
    set(gca, 'XTick', rhos, 'YTick', thetas);
    colormap(parula);
    axis xy;
    ch6_print(fig, fullfile(figsdir, 'sensitivity_theta_rho.tif'));
    fprintf('sensitivity figure redrawn\n');

    %% 4) component ablation (D10 + D30)
    abl_figs = fullfile(figsdir, 'ablation_results');
    for d = [10, 30]
        m = load(fullfile(datadir, 'ablation_results', ...
                          sprintf('results_ablation_D%d.mat', d)));
        Lcurve = size(m.Cd, 1);
        for k = 1:numel(m.fd)
            draw_conv(m.d, m.fd(k), m.Cd(:, :, k), m.variants, Lcurve, ...
                      abl_figs, sprintf('conv_D%d_F%d.tif', m.d, m.fd(k)));
            draw_box(m.d, m.fd(k), m.Sd(:, :, k), m.variants, ...
                     abl_figs, sprintf('box_D%d_F%d.tif', m.d, m.fd(k)));
        end
        draw_rank(m.d, m.fd, m.Sd, m.variants, abl_figs, ...
                  sprintf('avg_rank_D%d.tif', m.d));
        fprintf('component ablation D=%d redrawn (%d funcs)\n', m.d, numel(m.fd));
    end

    %% 5) rally ablation (D30)
    rly_figs = fullfile(figsdir, 'ablation_rally_results');
    r = load(fullfile(datadir, 'ablation_rally_results', 'results_rally_D30.mat'));
    Lcurve = size(r.Call, 1);
    for k = 1:numel(r.fnames)
        draw_conv(r.dim, r.fnames(k), r.Call(:, :, k), r.variants, Lcurve, ...
                  rly_figs, sprintf('conv_F%d.tif', r.fnames(k)));
        draw_box(r.dim, r.fnames(k), r.Sall(:, :, k), r.variants, ...
                 rly_figs, sprintf('box_F%d.tif', r.fnames(k)));
    end
    draw_rank(r.dim, r.fnames, r.Sall, r.variants, rly_figs, 'avg_rank.tif');
    fprintf('rally ablation redrawn (%d funcs)\n', numel(r.fnames));

    fprintf('ALL CHAPTER6 FIGURES REDRAWN\n');
end

% ===== local plotting helpers (style identical to run_ablation*.m) =====
function draw_conv(dim, f, C, variants, Lcurve, figsdir, fname)
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
    ch6_print(fig, fullfile(figsdir, fname));
end

function draw_box(dim, f, S, variants, figsdir, fname)
    fig = figure('Visible', 'off', 'Position', [100 100 1000 720]);
    boxplot(S, 'Labels', variants);
    set(gca, 'YScale', 'log');
    grid on;
    ylabel('Best Score');
    title(sprintf('Boxplot - D=%d, F%d', dim, f));
    ch6_print(fig, fullfile(figsdir, fname));
end

function draw_rank(dim, funcs, Sd, variants, figsdir, fname) %#ok<INUSD>
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
    title(sprintf('Friedman-style Average Rank - D=%d', dim));
    grid on;
    ylim([0 nVar + 1]);
    ch6_print(fig, fullfile(figsdir, fname));
end
