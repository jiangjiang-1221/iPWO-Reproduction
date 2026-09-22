function finalize_scaling()
% finalize_scaling - Combine D=30/50/100 scaling results and produce the
% final Chapter-6 Fig. 12 (TIFF / 330 DPI / 18 pt).

    script_dir = fileparts(mfilename('fullpath'));
    if isempty(script_dir), script_dir = pwd; end
    root = fileparts(script_dir);
    cd(script_dir); addpath(script_dir);

    outdir = fullfile(root, 'data', 'scaling_iPWO_results');
    figsdir = fullfile(root, 'figures');
    if ~exist(figsdir, 'dir'), mkdir(figsdir); end

    funcs = [1, 4, 5, 6, 7, 8, 9, 10, 15, 21];
    dims = [30, 50, 100];
    nF = numel(funcs); nVar = 2; nDims = numel(dims);
    variants = {'iPWO', 'PWO'};

    medAll = zeros(nF, nVar, nDims);
    meanAll = zeros(nF, nVar, nDims);
    Sall100 = [];
    Call100 = [];

    for di = 1:2
        m = load(fullfile(outdir, sprintf('results_scaling_D%d.mat', dims(di))));
        medAll(:, :, di) = m.medV;
        meanAll(:, :, di) = m.meanV;
    end

    ckdir = fullfile(outdir, 'checkpoints_D100');
    if ~exist(ckdir, 'dir')
        error('D100 checkpoints not found: %s', ckdir);
    end
    Sall = [];
    Call = [];
    medV = zeros(nF, nVar);
    meanV = zeros(nF, nVar);
    for k = 1:nF
        f = funcs(k);
        ckfile = fullfile(ckdir, sprintf('results_scaling_D100_f%d.mat', f));
        if ~exist(ckfile, 'file')
            error('Missing D100 checkpoint for F%d', f);
        end
        c = load(ckfile);
        Sall(:,:,k) = c.s.S;
        Call(:,:,k) = c.s.C;
        medV(k,:) = c.s.med;
        meanV(k,:) = c.s.mean;
    end
    medAll(:,:,3) = medV;
    meanAll(:,:,3) = meanV;

    dim = 100; runs = 51; pop = 50; maxFES = 10000 * dim;
    save(fullfile(outdir, 'results_scaling_D100.mat'), ...
        'dim', 'funcs', 'runs', 'pop', 'maxFES', 'variants', ...
        'Sall', 'Call', 'medV', 'meanV');

    meanMed = squeeze(mean(medAll, 1));   % nVar x nDims
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
    % title was originally one line; at 27pt it is too wide and extends left
    % over the y-axis tick labels and collides with the 10^10 exponent; split into two lines halves the width.
    title({'Dimension scalability:', 'iPWO vs PWO on CEC2017'});
    % legend was originally 'northwest' and overlapped the title above; moved to
    % the left-center blank band between the two curves, avoiding both title and curves.
    legend('Location', 'west', 'Interpreter', 'none');
    ch6_print(fig, fullfile(figsdir, 'scaling_D.tif'));

    fprintf('Scaling finalized: %s\n', fullfile(figsdir, 'scaling_D.tif'));
end
