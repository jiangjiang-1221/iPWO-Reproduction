function run_sensitivity()
% Parameter sensitivity of iPWO on CEC2017 F10 (D=10): theta vs rho heatmap.
    script_dir = fileparts(mfilename('fullpath'));
    root = fileparts(script_dir);
    cd(script_dir);
    addpath(script_dir);

    func = 10;
    dim = 10;
    pop = 30;
    maxFES = 10000 * dim;
    runs = 5;

    [lb, ub, ~, ~] = Get_Functions_cec2017(func, dim);
    fobj = @(X) cec17_func(X', func);

    thetas = [0.20, 0.25, 0.30, 0.35, 0.40, 0.45];
    rhos = [1.0, 1.1, 1.2, 1.3, 1.4, 1.5];
    nT = numel(thetas);
    nR = numel(rhos);

    Z = zeros(nT, nR);
    for i = 1:nT
        for j = 1:nR
            s = 0;
            for r = 1:runs
                rng(9000 + i * 100 + j * 10 + r);
                [sc, ~, ~] = iPWO_sens(pop, maxFES, lb, ub, dim, fobj, ...
                    true, true, true, true, thetas(i), rhos(j));
                s = s + sc;
            end
            Z(i, j) = s / runs;
        end
    end

    datadir = fullfile(root, 'data');
    figsdir = fullfile(root, 'figures');
    if ~exist(datadir, 'dir'), mkdir(datadir); end
    if ~exist(figsdir, 'dir'), mkdir(figsdir); end
    writematrix(Z, fullfile(datadir, 'sensitivity_theta_rho.csv'));
    fid = fopen(fullfile(datadir, 'sensitivity_axis.csv'), 'w');
    fprintf(fid, 'theta,rho\n');
    for i = 1:nT
        for j = 1:nR
            fprintf(fid, '%.4f,%.4f\n', thetas(i), rhos(j));
        end
    end
    fclose(fid);

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

    fprintf('sensitivity done\n');
end
