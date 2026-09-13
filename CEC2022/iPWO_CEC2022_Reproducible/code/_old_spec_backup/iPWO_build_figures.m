function iPWO_build_figures(Function_name, dim, lb, ub, fobj, best_run, avg_best_curve, avg_fit_curve, Lcurve, outDir, opts)
% iPWO_BUILD_FIGURES  生成 CEC2017 iPWO 五联图与图片复现数据（论文出版规格）
%
%  输出规格:
%    - TIFF(.tif) 格式, 分辨率 330 DPI
%    - 全图字体 18pt（标题/坐标轴/刻度/图例/色标）
%    - 五联图统一切边（所有函数使用相同画布尺寸与布局）
%    - 中间面板(Trajectory)的图例位于右下角(southeast)
%    - 同时把复现图片所需的全部数据保存到 repro_data 目录
%
%  输入:
%    Function_name : CEC2017 函数编号
%    dim           : 维度
%    lb, ub        : 边界
%    fobj          : 目标函数句柄; 若已有缓存地形或提供 opts.landscape 可传 []
%    best_run      : 最优一次运行结果 (score/pos/curve/history/time)
%    avg_best_curve, avg_fit_curve : 多次运行平均曲线
%    Lcurve        : 曲线长度
%    outDir        : 输出目录（五联图与子图 TIFF）
%    opts          : 可选参数
%        .dpi              默认 330
%        .fontSize         默认 18
%        .alg_name         默认 'iPWO'
%        .landscapeCacheDir 地形缓存目录, 默认 outDir/landscape_cache
%        .reproDataDir      复现数据目录, 默认 outDir/repro_data
%        .landscape         预计算地形 struct(x1g,x2g,zGrid,base_point,zbest)
%        .trajIter/.trajDist/.trajectoryOK  预提取轨迹(用于纯数据复现)
%        .searchXY/.searchIter/.historyOK   预提取搜索历史(用于纯数据复现)
%        .prefix            文件名前缀, 默认 'CEC2017' (CEC2022 传 'CEC2022')
%        .benchLabel        图中基准名称, 默认 'CEC2017' (CEC2022 传 'CEC2022')
%        .gridN             地形网格数, 默认 120

if nargin < 11, opts = struct(); end
dpi      = getOpt(opts, 'dpi', 330);
fs       = getOpt(opts, 'fontSize', 18);
algName  = getOpt(opts, 'alg_name', 'iPWO');
prefix   = getOpt(opts, 'prefix', 'CEC2017');
benchLab = getOpt(opts, 'benchLabel', 'CEC2017');
gridN    = getOpt(opts, 'gridN', 120);
cacheDir = getOpt(opts, 'landscapeCacheDir', fullfile(outDir, 'landscape_cache'));
reproDir = getOpt(opts, 'reproDataDir', fullfile(outDir, 'repro_data'));
if ~exist(cacheDir, 'dir'), mkdir(cacheDir); end
if ~exist(reproDir, 'dir'), mkdir(reproDir); end

% ---------- 全局默认字体 ----------
set(0, 'DefaultAxesFontSize', fs);
set(0, 'DefaultTextFontSize', fs);
set(0, 'DefaultLegendFontSize', fs);
set(0, 'DefaultColorbarFontSize', fs);

%% ==================== 1. 地形切片(优先缓存/预计算) ====================
cacheFile = fullfile(cacheDir, sprintf('%s_F%d_Dim%d_landscape.mat', prefix, Function_name, dim));
if isfield(opts, 'landscape') && ~isempty(opts.landscape)
    land = opts.landscape;
elseif isfile(cacheFile)
    C = load(cacheFile);
    land = C.land;
else
    base_point = (lb(:)' + ub(:)') / 2;
    if ~isempty(best_run.pos) && numel(best_run.pos) >= dim
        base_point = best_run.pos(1:dim);
    end
    [x1g, x2g, zGrid] = buildLandscape2D(fobj, lb, ub, dim, base_point, gridN);
    zbest = NaN;
    if ~isempty(best_run.pos) && ~isempty(fobj)
        zbest = safeEvalFobj(fobj, best_run.pos);
    end
    land = struct('x1g', x1g, 'x2g', x2g, 'zGrid', zGrid, ...
        'base_point', base_point, 'zbest', zbest, ...
        'lb', lb(:)', 'ub', ub(:)', 'gridN', gridN, ...
        'Function_name', Function_name, 'dim', dim);
    save(cacheFile, 'land');
end
x1g = land.x1g; x2g = land.x2g; zGrid = land.zGrid;
if isfield(land, 'zbest'), zbest = land.zbest; else, zbest = NaN; end

%% ==================== 2. 轨迹与搜索历史 ====================
if isfield(opts, 'trajectoryOK') && opts.trajectoryOK
    trajIter = opts.trajIter;
    trajDist = opts.trajDist;
    trajectoryOK = opts.trajectoryOK;
else
    [trajIter, trajDist, trajectoryOK] = extractTrajectoryDistance(best_run.history);
end
if isfield(opts, 'historyOK') && opts.historyOK
    allXY = opts.searchXY;
    allIter = opts.searchIter;
    historyOK = opts.historyOK;
else
    [allXY, allIter, historyOK] = extractSearchHistory(best_run.history);
end
best_xy = [];
if ~isempty(best_run.pos) && numel(best_run.pos) >= 2
    best_xy = best_run.pos(1:2);
end

%% ==================== 3. 五联图(统一画布, 统一切边) ====================
fig = figure('Position', [50 80 1800 360], 'Color', 'w', 'PaperPositionMode', 'auto');
tiledlayout(1, 5, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile; fillPanel1(ax1, x1g, x2g, zGrid, lb, ub, Function_name, best_xy, zbest, fs, benchLab);
ax2 = nexttile; fillPanel2(ax2, 1:Lcurve, avg_best_curve, algName, fs);
ax3 = nexttile; fillPanel3(ax3, trajIter, trajDist, trajectoryOK, fs);
ax4 = nexttile; fillPanel4(ax4, 1:Lcurve, avg_fit_curve, dim, algName, fs);
ax5 = nexttile; fillPanel5(ax5, x1g, x2g, zGrid, lb, ub, allXY, allIter, historyOK, best_xy, fs);

combinedTif = fullfile(outDir, sprintf('%s_F%d_Dim%d_iPWO_5Panels.tif', prefix, Function_name, dim));
saveTiffFig(fig, combinedTif, dpi);
close(fig);
fprintf('  五联图已保存: %s\n', combinedTif);

%% ==================== 4. 单独面板(独立 figure, 避免句柄失效) ====================
fp = [50 80 560 520];   % 统一面板画布, 保证各函数子图裁剪一致

fig1 = figure('Position', fp, 'Color', 'w', 'PaperPositionMode', 'auto');
fillPanel1(axes('Parent', fig1, 'Position', [0.10 0.13 0.82 0.74]), x1g, x2g, zGrid, lb, ub, Function_name, best_xy, zbest, fs, benchLab);
saveTiffFig(fig1, fullfile(outDir, sprintf('F%d_Dim%d_1_3D_Landscape.tif', Function_name, dim)), dpi); close(fig1);

fig2 = figure('Position', fp, 'Color', 'w', 'PaperPositionMode', 'auto');
fillPanel2(axes('Parent', fig2, 'Position', [0.10 0.13 0.82 0.74]), 1:Lcurve, avg_best_curve, algName, fs);
saveTiffFig(fig2, fullfile(outDir, sprintf('F%d_Dim%d_2_Objective_Space.tif', Function_name, dim)), dpi); close(fig2);

fig3 = figure('Position', fp, 'Color', 'w', 'PaperPositionMode', 'auto');
fillPanel3(axes('Parent', fig3, 'Position', [0.10 0.13 0.82 0.74]), trajIter, trajDist, trajectoryOK, fs);
saveTiffFig(fig3, fullfile(outDir, sprintf('F%d_Dim%d_3_Trajectory.tif', Function_name, dim)), dpi); close(fig3);

fig4 = figure('Position', fp, 'Color', 'w', 'PaperPositionMode', 'auto');
fillPanel4(axes('Parent', fig4, 'Position', [0.10 0.13 0.82 0.74]), 1:Lcurve, avg_fit_curve, dim, algName, fs);
saveTiffFig(fig4, fullfile(outDir, sprintf('F%d_Dim%d_4_Average_Fitness.tif', Function_name, dim)), dpi); close(fig4);

fig5 = figure('Position', fp, 'Color', 'w', 'PaperPositionMode', 'auto');
fillPanel5(axes('Parent', fig5, 'Position', [0.10 0.13 0.82 0.74]), x1g, x2g, zGrid, lb, ub, allXY, allIter, historyOK, best_xy, fs);
saveTiffFig(fig5, fullfile(outDir, sprintf('F%d_Dim%d_5_Search_History.tif', Function_name, dim)), dpi); close(fig5);

%% ==================== 5. 保存图片复现数据 ====================
repro.alg_name        = algName;
repro.Function_name   = Function_name;
repro.dim             = dim;
repro.lb              = lb(:)';
repro.ub              = ub(:)';
repro.Lcurve          = Lcurve;
repro.avg_best_curve  = avg_best_curve(:);
repro.avg_fit_curve   = avg_fit_curve(:);
repro.best_score      = best_run.score;
repro.best_pos        = best_run.pos;
repro.best_curve      = best_run.curve(:);
repro.trajIter        = trajIter;
repro.trajDist        = trajDist;
repro.trajectoryOK    = trajectoryOK;
repro.searchXY        = single(allXY);
repro.searchIter      = single(allIter);
repro.historyOK       = historyOK;
repro.x1g             = single(x1g);
repro.x2g             = single(x2g);
repro.zGrid           = single(zGrid);
repro.zbest           = zbest;
repro.base_point      = land.base_point;
repro.best_xy         = best_xy;
repro.figSpecs.dpi        = dpi;
repro.figSpecs.fontSize   = fs;
repro.figSpecs.format     = 'tiff';
repro.figSpecs.legendPos3 = 'southeast';
repro.prefix = prefix;
repro.benchLabel = benchLab;
reproFile = fullfile(reproDir, sprintf('%s_F%d_Dim%d_iPWO_ReproData.mat', prefix, Function_name, dim));
save(reproFile, 'repro');
fprintf('  复现数据已保存: %s\n', reproFile);
end

%% ==================== 面板绘制函数 ====================
function fillPanel1(ax, x1g, x2g, zGrid, lb, ub, fn, best_xy, zbest, fs, benchLab)
surf(ax, x1g, x2g, zGrid, 'EdgeColor', 'none', 'FaceAlpha', 0.95);
hold(ax, 'on');
contour3(ax, x1g, x2g, zGrid, 25, 'k', 'LineWidth', 0.6);
shading(ax, 'interp');
grid(ax, 'on');
box(ax, 'on');
xlabel(ax, 'x_1');
ylabel(ax, 'x_2');
zlabel(ax, 'f(x)');
title(ax, sprintf('%s-F%d', benchLab, fn));
view(ax, 45, 40);
if ~isempty(best_xy) && ~isnan(zbest)
    plot3(ax, best_xy(1), best_xy(2), zbest, 'rp', ...
        'MarkerSize', 11, 'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'k');
end
xlim(ax, [lb(1), ub(1)]);
ylim(ax, [lb(2), ub(2)]);
cb = colorbar(ax);
cb.FontSize = fs;
applyFont(ax, fs);
end

function fillPanel2(ax, x, y, algName, fs)
plot(ax, x, y, 'LineWidth', 1.6, 'Color', [0.20 0.45 0.80]);
grid(ax, 'on');
box(ax, 'on');
xlabel(ax, 'Iteration');
ylabel(ax, 'Best score obtained so far');
title(ax, 'Objective space');
legend(ax, algName, 'Location', 'northeast', 'FontSize', fs);
xlim(ax, [1, max(x)]);
applyFont(ax, fs);
end

function fillPanel3(ax, trajIter, trajDist, trajectoryOK, fs)
grid(ax, 'on');
box(ax, 'on');
xlabel(ax, 'Iteration');
ylabel(ax, 'Trajectory distance');
title(ax, 'Trajectory');
if trajectoryOK
    plot(ax, trajIter, trajDist, 'LineWidth', 1.8, 'Color', [0.20 0.45 0.80]);
    hold(ax, 'on');
    plot(ax, trajIter(1), trajDist(1), 'bs', 'MarkerSize', 7, 'MarkerFaceColor', 'b');
    plot(ax, trajIter(end), trajDist(end), 'rp', 'MarkerSize', 11, 'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'k');
    % 图例置于右下角(中间面板要求)
    legend(ax, 'Distance to initial best', 'Start', 'Best', ...
        'Location', 'southeast', 'FontSize', fs);
    xlim(ax, [1, max(trajIter)]);
else
    text(ax, 0.5, 0.5, 'Trajectory data not available', ...
        'Units', 'normalized', 'HorizontalAlignment', 'center', ...
        'FontSize', fs, 'Color', 'r');
end
applyFont(ax, fs);
end

function fillPanel4(ax, x, y, dim, algName, fs)
plot(ax, x, y, 'LineWidth', 1.6, 'Color', [0.20 0.45 0.80]);
grid(ax, 'on');
box(ax, 'on');
xlabel(ax, 'Iteration');
ylabel(ax, sprintf('Fitness value (Dim=%d)', dim));
title(ax, 'Average fitness');
legend(ax, algName, 'Location', 'northeast', 'FontSize', fs);
xlim(ax, [1, max(x)]);
applyFont(ax, fs);
end

function fillPanel5(ax, x1g, x2g, zGrid, lb, ub, allXY, allIter, historyOK, best_xy, fs)
contour(ax, x1g, x2g, zGrid, 30, 'LineWidth', 0.8);
hold(ax, 'on');
grid(ax, 'on');
box(ax, 'on');
xlabel(ax, 'x_1');
ylabel(ax, 'x_2');
title(ax, 'Search history');
xlim(ax, [lb(1), ub(1)]);
ylim(ax, [lb(2), ub(2)]);
if historyOK && ~isempty(allXY)
    scatter(ax, allXY(:,1), allXY(:,2), 14, allIter, 'filled', ...
        'MarkerFaceAlpha', 0.55, 'MarkerEdgeColor', 'none');
    colormap(ax, parula);
    cb = colorbar(ax);
    ylabel(cb, 'Iteration');
    cb.FontSize = fs;
    if ~isempty(best_xy)
        plot(ax, best_xy(1), best_xy(2), 'rp', ...
            'MarkerSize', 13, 'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'k');
    end
else
    text(ax, 0.5, 0.5, 'Search history data not available', ...
        'Units', 'normalized', 'HorizontalAlignment', 'center', ...
        'FontSize', fs, 'Color', 'r');
end
applyFont(ax, fs);
end

function applyFont(ax, fs)
ax.FontSize = fs;
ax.Title.FontSize = fs;
ax.XLabel.FontSize = fs;
ax.YLabel.FontSize = fs;
ax.ZLabel.FontSize = fs;
end

%% ==================== 工具函数 ====================
function v = getOpt(opts, name, default)
if isfield(opts, name) && ~isempty(opts.(name))
    v = opts.(name);
else
    v = default;
end
end

function saveTiffFig(fig, filePath, dpi)
drawnow;
try
    exportgraphics(fig, filePath, 'Resolution', dpi, 'ContentType', 'image');
catch
    print(fig, filePath, '-dtiff', sprintf('-r%d', dpi));
end
end

function y = safeEvalFobj(fobj, x)
try
    y = fobj(x);
catch
    y = fobj(x(:)');
end
y = double(y);
if isempty(y) || ~isscalar(y) || ~isfinite(y)
    y = NaN;
end
end

function [X1, X2, Z] = buildLandscape2D(fobj, lb, ub, dim, basePoint, gridN)
x1 = linspace(lb(1), ub(1), gridN);
x2 = linspace(lb(2), ub(2), gridN);
[X1, X2] = meshgrid(x1, x2);
Z = zeros(gridN, gridN);
x = basePoint(:)';
if numel(x) < dim
    x(dim) = 0;
end
for i = 1:gridN
    for j = 1:gridN
        xtmp = x;
        xtmp(1) = X1(i, j);
        xtmp(2) = X2(i, j);
        Z(i, j) = safeEvalFobj(fobj, xtmp);
    end
end
end

function [trajIter, trajDist, ok] = extractTrajectoryDistance(history)
trajIter = [];
trajDist = [];
ok = false;
if isempty(history) || ~isstruct(history)
    return;
end
if isfield(history, 'bestPosIter') && ~isempty(history.bestPosIter)
    bp = history.bestPosIter;
    if isnumeric(bp)
        bp = bp(~any(isnan(bp), 2), :);
        if size(bp,1) > 1
            trajIter = (1:size(bp,1))';
            ref = bp(1,:);
            trajDist = sqrt(sum((bp - ref).^2, 2));
            ok = true;
            return;
        end
    elseif iscell(bp)
        tmp = [];
        for t = 1:numel(bp)
            x = bp{t};
            if ~isempty(x) && numel(x) >= 2
                tmp = [tmp; x(:)']; %#ok<AGROW>
            end
        end
        if size(tmp,1) > 1
            tmp = tmp(:,1:min(2,size(tmp,2)));
            trajIter = (1:size(tmp,1))';
            ref = tmp(1,:);
            trajDist = sqrt(sum((tmp - ref).^2, 2));
            ok = true;
        end
        return;
    end
end
end

function [allXY, allIter, ok] = extractSearchHistory(history)
allXY = [];
allIter = [];
ok = false;
if isempty(history) || ~isstruct(history)
    return;
end
if ~isfield(history, 'popPos') || isempty(history.popPos)
    return;
end
popPos = history.popPos;
try
    if iscell(popPos)
        for t = 1:numel(popPos)
            P = popPos{t};
            if isempty(P) || size(P,2) < 2
                continue;
            end
            allXY = [allXY; P(:,1:2)]; %#ok<AGROW>
            allIter = [allIter; t * ones(size(P,1), 1)]; %#ok<AGROW>
        end
        ok = ~isempty(allXY);
        return;
    elseif isnumeric(popPos)
        sz = size(popPos);
        if numel(sz) == 3 && sz(2) >= 2
            T = sz(3);
            for t = 1:T
                P = popPos(:,:,t);
                allXY = [allXY; P(:,1:2)]; %#ok<AGROW>
                allIter = [allIter; t * ones(size(P,1), 1)]; %#ok<AGROW>
            end
            ok = ~isempty(allXY);
            return;
        end
    end
catch
    ok = false;
end
end
