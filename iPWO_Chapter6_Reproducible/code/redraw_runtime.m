function redraw_runtime()
% redraw_runtime - Rebuild Fig. 11 TIFF from saved runtime_times.csv
% without re-running the timing experiments.

    script_dir = fileparts(mfilename('fullpath'));
    if isempty(script_dir), script_dir = pwd; end
    root = fileparts(script_dir);
    cd(script_dir); addpath(script_dir);

    datadir = fullfile(root, 'data');
    figsdir = fullfile(root, 'figures');
    T = readtable(fullfile(datadir, 'runtime_times.csv'));
    algos = T.Properties.VariableNames;
    avg = mean(table2array(T), 1);

    colors = [0.85 0.15 0.20;   % iPWO (red)
              0.12 0.47 0.71;   % PWO  (blue)
              0.17 0.63 0.17;   % GWO  (green)
              0.58 0.40 0.74;   % PSO  (purple)
              0.20 0.20 0.20];  % DE   (dark gray)

    fig = figure('Visible', 'off', 'Position', [100 100 900 620]);
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

    fprintf('runtime figure redrawn\n');
end
