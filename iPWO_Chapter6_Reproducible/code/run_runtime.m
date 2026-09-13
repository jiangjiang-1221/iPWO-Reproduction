function run_runtime()
% run_runtime - Average CPU time for one MTA-PP solve (Chapter 6, Fig. 11).
% The measurement uses the same delivery environment and the same five
% algorithms as the MTA-PP comparison in Chapter 5 (MaxFEs = 8000, 5 runs).

    script_dir = fileparts(mfilename('fullpath'));
    if isempty(script_dir), script_dir = pwd; end
    root = fileparts(script_dir);
    cd(script_dir); addpath(script_dir);

    datadir = fullfile(root, 'data');
    figsdir = fullfile(root, 'figures');
    if ~exist(datadir, 'dir'), mkdir(datadir); end
    if ~exist(figsdir, 'dir'), mkdir(figsdir); end

    pop = 30;
    MaxFEs = 8000;
    runs = 5;

    env = uav_delivery_env();   % 4 UAVs, 20 customers, d_min = 6 m
    dim = env.D;
    fobj = @(X) uav_delivery_cost(X, env);

    algos = {'iPWO', 'PWO', 'GWO', 'PSO', 'DE'};
    nAlg = numel(algos);
    times = zeros(nAlg, runs);

    for a = 1:nAlg
        for r = 1:runs
            rng(6000 + a * 100 + r);
            t0 = tic;
            switch algos{a}
                case 'iPWO', iPWO(pop, MaxFEs, env.lb, env.ub, dim, fobj);
                case 'PWO',  PWO_vec(pop, MaxFEs, env.lb, env.ub, dim, fobj);
                case 'GWO',  GWO(pop, MaxFEs, env.lb, env.ub, dim, fobj);
                case 'PSO',  PSO(pop, MaxFEs, env.lb, env.ub, dim, fobj);
                case 'DE',   DE(pop, MaxFEs, env.lb, env.ub, dim, fobj);
            end
            times(a, r) = toc(t0);
        end
    end

    avg = mean(times, 2);
    T = array2table(times', 'VariableNames', algos);
    writetable(T, fullfile(datadir, 'runtime_times.csv'));

    fig = figure('Visible', 'off', 'Position', [100 100 900 620]);
    colors = [0.85 0.15 0.20;   % iPWO (red)
              0.12 0.47 0.71;   % PWO  (blue)
              0.17 0.63 0.17;   % GWO  (green)
              0.58 0.40 0.74;   % PSO  (purple)
              0.20 0.20 0.20];  % DE   (dark gray)
    b = bar(avg, 'FaceColor', 'flat');
    b.CData = colors;
    b.LineStyle = 'none';
    set(gca, 'XTickLabel', algos);
    ylabel('Average CPU time (s)');
    % 标题原为单行, 27pt 下比绘图区更宽、向左溢出到 y 轴标签处;
    % 拆成两行后宽度减半, 完整落在绘图区正上方。
    title({'Average runtime per MTA-PP solve', '(MaxFEs=8000, 5 runs)'});
    grid on;
    set(gca, 'GridAlpha', 0.35, 'Box', 'on');
    ch6_print(fig, fullfile(figsdir, 'runtime_times.tif'));

    fprintf('runtime done\n');
    for a = 1:nAlg
        fprintf('%s: %.3f s\n', algos{a}, avg(a));
    end
end
