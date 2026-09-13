function iPWO_build_figures(Function_name, dim, lb, ub, fobj, best_run, avg_best_curve, avg_fit_curve, Lcurve, outDir, opts)
% iPWO_BUILD_FIGURES  生成 CEC2017 iPWO 单独面板图(论文出版规格)
%
%  ===== 版面规格(由 A4 版面反推) =====
%    A4 = 21.0 x 29.7 cm, 上下边距 2.54 cm, 左右边距 3.18 cm
%    => 正文可用宽度 = 21.0 - 2*3.18 = 14.64 cm
%    => 一行恰好放 5 张 => 每张边长 = 14.64 / 5 = 2.928 cm (正方形)
%    => TIFF, 600 DPI  => 2.928/2.54*600 = 692 x 692 px
%    => 导出物理字号 6 pt (比正文五号 10.5pt 显著小, 绘图区更大更舒展)
%
%  ===== 绘制方式 =====
%    所见即所得: 画布即 2.928cm, 字号即 6pt, print -r600 按 1:1 输出。
%    axes 使用 OuterPosition=[0 0 1 1] 自动布局, MATLAB 自动为
%    标题/轴标签/刻度留出空间, 标签保证不被裁切。
%
%  ===== 输出内容 =====
%    - 不再生成五联图, 仅输出 5 个单独面板:
%        1_3D_Landscape / 2_Objective_Space / 3_Trajectory
%        4_Average_Fitness / 5_Search_History
%    - 每个面板同时保存 .fig 源文件到 <outDir>/fig, 便于后续修改:
%      .fig 为等比放大的编辑版(默认 8cm 画布, 字号同步放大),
%      视觉比例与导出图完全一致; 修改后可用 export_figs_to_tiff.m
%      一键重新按论文规格导出。
%    - 复现图片所需的全部数据保存到 reproDir
%
%  输入:
%    Function_name : CEC2017 函数编号
%    dim           : 维度
%    lb, ub        : 边界
%    fobj          : 目标函数句柄; 若已有缓存地形或提供 opts.landscape 可传 []
%    best_run      : 最优一次运行结果 (score/pos/curve/history/time)
%    avg_best_curve, avg_fit_curve : 多次运行平均曲线
%    Lcurve        : 曲线长度
%    outDir        : 输出目录(各面板 TIFF)
%    opts          : 可选参数
%        .dpi              默认 600
%        .fontSize         默认 6   (导出后的物理字号 pt)
%        .panelCm          默认 2.928 (导出物理边长 cm)
%        .editCm           默认 8   (.fig 编辑画布边长 cm)
%        .saveFig          默认 true (保存 .fig 源文件)
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

%% ==================== 0. 版面规格 ====================
K        = 4;                                  % 渲染放大倍数(小画布渲染不稳, 大画布绘制后等比缩回)
dpi      = getOpt(opts, 'dpi', 600);
fs       = getOpt(opts, 'fontSize', 6) * K;    % 绘制字号(导出缩回后物理 6pt)
tgtCm    = getOpt(opts, 'panelCm', 2.928) * K; % 绘制画布边长(导出缩回后 2.928cm)
editCm   = getOpt(opts, 'editCm', 8);          % .fig 编辑画布边长(cm)
saveFigFile = getOpt(opts, 'saveFig', true);
algName  = getOpt(opts, 'alg_name', 'iPWO');
prefix   = getOpt(opts, 'prefix', 'CEC2017');
benchLab = getOpt(opts, 'benchLabel', 'CEC2017');
gridN    = getOpt(opts, 'gridN', 120);
cacheDir = getOpt(opts, 'landscapeCacheDir', fullfile(outDir, 'landscape_cache'));
reproDir = getOpt(opts, 'reproDataDir', fullfile(outDir, 'repro_data'));
figSrcDir = fullfile(outDir, 'fig');

if ~exist(cacheDir, 'dir'),  mkdir(cacheDir);  end
if ~exist(reproDir, 'dir'),  mkdir(reproDir);  end
if ~exist(figSrcDir, 'dir'), mkdir(figSrcDir); end
if ~exist(outDir, 'dir'),    mkdir(outDir);    end

% ---------- 全局默认字体 ----------
set(0, 'DefaultAxesFontSize',     fs);
set(0, 'DefaultTextFontSize',     fs);
set(0, 'DefaultLegendFontSize',   fs);
set(0, 'DefaultColorbarFontSize', fs);
% 统一字体族为 Times New Roman（论文出版常用衬线字体）
set(0, 'DefaultAxesFontName',     'Times New Roman');
set(0, 'DefaultTextFontName',     'Times New Roman');
set(0, 'DefaultLegendFontName',   'Times New Roman');
set(0, 'DefaultColorbarFontName', 'Times New Roman');

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

%% ==================== 3. 五个单独面板 ====================
% 布局策略: 绘制时 axes 占满画布, 导出前由 finalizeLayout 依据
% MATLAB 度量的 TightInset(标题/轴标签/刻度实际所需空间)精确收缩,
% 标签要多少空间就留多少, 保证不被裁切且绘图区最大化。
LAYOUT_MARGIN = 0.008;   % TightInset 外的安全余量(归一化, 缩印以扩大绘图区)

% Panel 1: 3D 地形(固定布局: 投影轴标签伸出较远, 四周预留空间; 固定框跨函数一致)
fig = newPanelFig(tgtCm);
ax1 = newAxes(fig, [0.33 0.22 0.42 0.58]);   % 3D 固定框(左0.33 宽0.42: 3D投影会向左右两侧伸出, 需更大留白防裁切)
fillPanel1(ax1, x1g, x2g, zGrid, lb, ub, Function_name, best_xy, zbest, fs, benchLab);
finishPanel(fig, ax1, outDir, figSrcDir, sprintf('F%d_Dim%d_1_3D_Landscape', Function_name, dim), ...
    tgtCm, tgtCm / K, dpi, editCm, saveFigFile);

% Panel 2: 目标空间(收敛曲线)
fig = newPanelFig(tgtCm);
ax2 = newAxes(fig);
fillPanel2(ax2, 1:Lcurve, avg_best_curve, algName, fs);
finishPanel(fig, ax2, outDir, figSrcDir, sprintf('F%d_Dim%d_2_Objective_Space', Function_name, dim), ...
    tgtCm, tgtCm / K, dpi, editCm, saveFigFile);

% Panel 3: 轨迹
fig = newPanelFig(tgtCm);
ax3 = newAxes(fig);
fillPanel3(ax3, trajIter, trajDist, trajectoryOK, fs);
finishPanel(fig, ax3, outDir, figSrcDir, sprintf('F%d_Dim%d_3_Trajectory', Function_name, dim), ...
    tgtCm, tgtCm / K, dpi, editCm, saveFigFile);

% Panel 4: 平均适应度
fig = newPanelFig(tgtCm);
ax4 = newAxes(fig);
fillPanel4(ax4, 1:Lcurve, avg_fit_curve, dim, algName, fs);
finishPanel(fig, ax4, outDir, figSrcDir, sprintf('F%d_Dim%d_4_Average_Fitness', Function_name, dim), ...
    tgtCm, tgtCm / K, dpi, editCm, saveFigFile);

% Panel 5: 搜索历史
fig = newPanelFig(tgtCm);
ax5 = newAxes(fig);
fillPanel5(ax5, x1g, x2g, zGrid, lb, ub, allXY, allIter, historyOK, best_xy, fs);
finishPanel(fig, ax5, outDir, figSrcDir, sprintf('F%d_Dim%d_5_Search_History', Function_name, dim), ...
    tgtCm, tgtCm / K, dpi, editCm, saveFigFile);

%% ==================== 4. 保存图片复现数据 ====================
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
repro.figSpecs.fontSize   = fs;           % 导出后物理字号
repro.figSpecs.panelCm    = tgtCm;        % 导出物理边长
repro.figSpecs.editCm     = editCm;       % .fig 编辑画布边长
repro.figSpecs.format     = 'tiff';
repro.figSpecs.panelLayout= 'single';     % 仅单独面板(不再生成五联图)
repro.prefix = prefix;
repro.benchLabel = benchLab;
reproFile = fullfile(reproDir, sprintf('%s_F%d_Dim%d_iPWO_ReproData.mat', prefix, Function_name, dim));
save(reproFile, 'repro');
fprintf('  复现数据已保存: %s\n', reproFile);
end

%% ==================== 面板画布与导出 ====================
function fig = newPanelFig(tgtCm)
% 所见即所得画布: 逻辑尺寸 = 导出物理尺寸, 字号即物理 pt
fig = figure('Units', 'centimeters', 'Position', [3 3 tgtCm tgtCm], ...
    'Color', 'w', 'InvertHardcopy', 'off', 'PaperPositionMode', 'manual');
end

function ax = newAxes(fig, fixedPos)
% 2D 面板: 传出后由 finalizeLayout 套用统一固定框(所有 2D 面板绘图区大小一致, 标签位置固定)
% 3D 面板: 传入 fixedPos 使用专用固定框(投影轴标签需更大边距, 但仍为固定框, 跨函数一致)
if nargin >= 2 && ~isempty(fixedPos)
    ax = axes('Parent', fig);
    ax.Position = fixedPos;
    setappdata(ax, 'fixedBox', fixedPos);
else
    ax = axes('Parent', fig);
    ax.OuterPosition = [0 0 1 1];
    setappdata(ax, 'fixedBox', [0.28 0.26 0.51 0.54]);   % 2D 统一框(归一化): 左0.28(容纳y轴刻度标签+ylabel) 下0.26 宽0.51 高0.54
end
end

function finalizeLayout(ax)
% 固定布局: 直接套用统一绘图框(归一化), 不再按 TightInset 逐图自适应收缩
%   => 所有图片绘图区大小一致, x/y 轴标签位置固定(便于论文中多面板对齐)
%   数轴(刻度数值)仍可因函数不同而异, 无需统一
b = getappdata(ax, 'fixedBox');
if isempty(b)
    b = [0.16 0.15 0.69 0.70];   % 默认 2D 统一框
end
ax.Position = b;
% 显式禁止刻度标签旋转(个别渲染路径下会出现斜转导致溢出)
try
    ax.XAxis.TickLabelRotation = 0;
    ax.YAxis.TickLabelRotation = 0;
catch
end
drawnow;
% 色标(若有): 固定在绘图框右侧留白, 不挤压/改变绘图框(保证绘图区与其他面板一致)
%   注: 本版色标为「独立 axes 色带」(见 makeColorbarStrip), 不链接数据 axes,
%       因此 print -dtiff 时不会重布局数据 axes, 固定绘图框得以保持。
cb = getappdata(ax, 'panelColorbar');
if ~isempty(cb) && isvalid(cb)
    if isa(cb, 'matlab.graphics.axis.Axes')
        cbX = b(1) + b(3) + 0.015;
        cbW = 0.022;
        cb.Position = [cbX, b(2), cbW, b(4)];
    end
end
drawnow;
end

function finishPanel(fig, ax, outDir, figSrcDir, nm, drawCm, physCm, dpi, editCm, saveFigFile)
drawnow;
% --- 0) 固定布局: 套用统一绘图框(保证所有面板绘图区大小一致, 标签位置固定) ---
finalizeLayout(ax);
% --- 1) 按论文规格导出 TIFF (放大渲染 -> 面积平均缩到 692px -> 600DPI 标记) ---
tifPath = fullfile(outDir, [nm '.tif']);
export_panel_tiff(fig, tifPath, physCm, dpi);
% --- 2) 保存等比放大的 .fig 编辑版 ---
if saveFigFile
    if ~exist(figSrcDir, 'dir'), mkdir(figSrcDir); end
    scaleF = editCm / physCm;
    hTxt = findall(fig, '-property', 'FontSize');
    fs0 = arrayfun(@(h) get(h, 'FontSize'), hTxt);
    pos0 = get(fig, 'Position');
    set(hTxt, {'FontSize'}, num2cell(fs0 * scaleF));
    set(fig, 'Units', 'centimeters', 'Position', [pos0(1) pos0(2) editCm editCm]);
    savefig(fig, fullfile(figSrcDir, [nm '.fig']));
    set(hTxt, {'FontSize'}, num2cell(fs0));
    set(fig, 'Position', pos0);
end
close(fig);
% --- 3) 导出自检: 报告实际像素与分辨率 ---
try
    info = imfinfo(tifPath);
    fprintf('  %s.tif -> %d x %d px, %d DPI\n', nm, info.Width, info.Height, ...
        round(info.XResolution));
catch
    fprintf('  %s.tif -> 已保存(自检信息读取失败)\n', nm);
end
end

%% ==================== 面板绘制函数 ====================
function fillPanel1(ax, x1g, x2g, zGrid, lb, ub, fn, best_xy, zbest, fs, benchLab)
% 大数 z 值归一化, 指数并入 zlabel(避免 z 轴指数标注与标题重叠)
zl = 'f';
mx = max(zGrid(:));
if isfinite(mx) && mx > 0
    expo = floor(log10(mx));
    if abs(expo) >= 3
        zGrid = zGrid / (10 ^ expo);
        if ~isnan(zbest), zbest = zbest / (10 ^ expo); end
        zl = sprintf('f (\\times10^{%d})', expo);
    end
end
surf(ax, x1g, x2g, zGrid, 'EdgeColor', 'none', 'FaceAlpha', 0.95);
hold(ax, 'on');
contour3(ax, x1g, x2g, zGrid, 25, 'k', 'LineWidth', 1.6);
shading(ax, 'interp');
grid(ax, 'on');
box(ax, 'on');
xlabel(ax, 'x_1');
ylabel(ax, 'x_2');
zlabel(ax, zl);
title(ax, sprintf('%s-F%d', benchLab, fn));
view(ax, 45, 40);
if ~isempty(best_xy) && ~isnan(zbest)
    plot3(ax, best_xy(1), best_xy(2), zbest, 'rp', ...
        'MarkerSize', 28, 'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'k');
end
xlim(ax, [lb(1), ub(1)]);
ylim(ax, [lb(2), ub(2)]);
limitTicks(ax, 4);
applyFont(ax, fs);
end

function fillPanel2(ax, x, y, algName, fs)
[yPlot, ylab] = compactScale(y, 'Best score');   % 指数归一化(防自动×10^N与标题重叠)
plot(ax, x, yPlot, 'LineWidth', 4.0, 'Color', [0.20 0.45 0.80]);
grid(ax, 'on');
box(ax, 'on');
xlabel(ax, 'Iteration');
ylabel(ax, ylab);
title(ax, 'Convergence');
legend(ax, algName, 'Location', 'northeast', 'FontSize', fs);
xlim(ax, [1, max(x)]);
limitTicks(ax, 4);
applyFont(ax, fs);
end

function fillPanel3(ax, trajIter, trajDist, trajectoryOK, fs)
grid(ax, 'on');
box(ax, 'on');
if trajectoryOK
    [yPlot, ylab] = compactScale(trajDist, 'Distance');   % 指数归一化(防大数值刻度溢出)
    plot(ax, trajIter, yPlot, 'LineWidth', 4.0, 'Color', [0.20 0.45 0.80]);
    hold(ax, 'on');
    plot(ax, trajIter(1), yPlot(1), 'bs', 'MarkerSize', 16, 'MarkerFaceColor', 'b');
    plot(ax, trajIter(end), yPlot(end), 'rp', 'MarkerSize', 28, 'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'k');
    ylabel(ax, ylab);
    % 不加图例: 'Distance/Start/Best' 三项图例宽度超过小图绘图区,
    % 语义由起点(蓝方块)与最优点(红星)标记直观表达, 图注中说明
    xlim(ax, [1, max(trajIter)]);
    limitTicks(ax, 4);
else
    ylabel(ax, 'Distance');
    text(ax, 0.5, 0.5, 'Trajectory data not available', ...
        'Units', 'normalized', 'HorizontalAlignment', 'center', ...
        'FontSize', fs, 'Color', 'r');
end
% 标题和 x 轴标签放在 plot 之后(确保 MATLAB 正确计算标签位置)
xlabel(ax, 'Iteration');
title(ax, 'Trajectory');
applyFont(ax, fs);
end

function fillPanel4(ax, x, y, dim, algName, fs) %#ok<INUSD>
[yPlot, ylab] = compactScale(y, 'Fitness');   % 指数归一化(防自动×10^N与标题重叠)
plot(ax, x, yPlot, 'LineWidth', 4.0, 'Color', [0.20 0.45 0.80]);
grid(ax, 'on');
box(ax, 'on');
xlabel(ax, 'Iteration');
ylabel(ax, ylab);
title(ax, 'Avg. fitness');
legend(ax, algName, 'Location', 'northeast', 'FontSize', fs);
xlim(ax, [1, max(x)]);
limitTicks(ax, 4);
applyFont(ax, fs);
end

function fillPanel5(ax, x1g, x2g, zGrid, lb, ub, allXY, allIter, historyOK, best_xy, fs)
contour(ax, x1g, x2g, zGrid, 30, 'LineWidth', 1.6);
hold(ax, 'on');
grid(ax, 'on');
box(ax, 'on');
xlabel(ax, 'x_1');
ylabel(ax, 'x_2');
title(ax, 'Search history');
xlim(ax, [lb(1), ub(1)]);
ylim(ax, [lb(2), ub(2)]);
if historyOK && ~isempty(allXY)
    scatter(ax, allXY(:,1), allXY(:,2), 24, allIter, 'filled', ...
        'MarkerFaceAlpha', 0.55, 'MarkerEdgeColor', 'none');
    colormap(ax, parula);
    % 独立色标(自建小 axes 色带, 不链接数据 axes, 彻底避免 print 重布局挤压绘图区)
    itMin = double(min(allIter(:)));
    itMax = double(max(allIter(:)));
    cb = makeColorbarStrip(ax.Parent, fs, itMin, itMax);
    setappdata(ax, 'panelColorbar', cb);   % cb 为独立 axes handle, 由 finalizeLayout 定位
    if ~isempty(best_xy)
        plot(ax, best_xy(1), best_xy(2), 'rp', ...
            'MarkerSize', 28, 'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'k');
    end
else
    text(ax, 0.5, 0.5, 'Search history data not available', ...
        'Units', 'normalized', 'HorizontalAlignment', 'center', ...
        'FontSize', fs, 'Color', 'r');
end
limitTicks(ax, 4);
% 域内 1/4、1/2、3/4 分位刻度(取整): 端点刻度标签(如 -100/3334)会溢出画布
try
    xl = get(ax, 'XLim'); yl = get(ax, 'YLim');
    set(ax, 'XTick', round(xl(1) + [0.25 0.5 0.75] * diff(xl)));
    set(ax, 'YTick', round(yl(1) + [0.25 0.5 0.75] * diff(yl)));
catch
end
applyFont(ax, fs);
end

function applyFont(ax, fs)
ax.FontSize = fs;
ax.FontName = 'Times New Roman';
ax.Title.FontSize = fs;
ax.XLabel.FontSize = fs;
ax.YLabel.FontSize = fs;
if ~isempty(ax.ZLabel), ax.ZLabel.FontSize = fs; end
end

function cb = makeColorbarStrip(fig, fs, itMin, itMax)
% 独立色标: 仅含一段 parula 渐变色带的极窄 axes, 与数据 axes 无任何链接,
% 因此 print/export 时不会触发数据 axes 的重布局(固定绘图框得以保持)。
%   不设 ylabel(避免与等高线/散点重叠), 含义由图注说明。
grad = reshape(parula(256), 256, 1, 3);          % 256x1x3, 行序 = 色阶(由低到高)
cb = axes('Parent', fig, 'Units', 'normalized');
image(cb, grad);
cb.YDir = 'normal';                              % 第 1 行(最低色)置于底部
cb.XTick = [];
cb.YLim = [0.5 256.5];
cb.YTick = [0.5 256.5];
cb.YTickLabel = {num2str(round(itMax)), num2str(round(itMin))};  % 顶=最大迭代, 底=最小
cb.TickLength = [0 0];
cb.YColor = [0 0 0];
cb.XColor = [0 0 0];
cb.Box = 'on';
cb.LineWidth = 2.0;
cb.FontSize = fs;
end

%% ==================== 工具函数 ====================
function v = getOpt(opts, name, default)
if isfield(opts, name) && ~isempty(opts.(name))
    v = opts.(name);
else
    v = default;
end
end

function [yScaled, yLabel] = compactScale(y, baseLabel)
% 小图上大数值刻度标签会过宽, 把 10 的幂次提取到轴标签, 刻度仅保留尾数
y = double(y(:));
fin = isfinite(y);
if ~any(fin)
    yScaled = y; yLabel = baseLabel; return;
end
mx = max(abs(y(fin)));
if mx > 0
    expo = floor(log10(mx));
else
    expo = 0;
end
if abs(expo) >= 3
    yScaled = y / (10 ^ expo);
    yLabel = sprintf('%s (\\times10^{%d})', baseLabel, expo);
else
    yScaled = y;
    yLabel = baseLabel;
end
end

function limitTicks(ax, ymax_n)
% x 轴只用 [起点, 中点] 两个刻度: 端点刻度标签(如 3334)会超出画布右缘
% y 轴限制刻度数量, 防止小图上刻度标签重叠
try
    xl = get(ax, 'XLim');
    if isfinite(xl(1)) && isfinite(xl(2)) && xl(2) > xl(1)
        set(ax, 'XTick', unique(round([xl(1), (xl(1) + xl(2)) / 2])));
    end
catch
end
try
    yt = get(ax, 'YTick');
    if numel(yt) > ymax_n
        step = ceil(numel(yt) / ymax_n);
        set(ax, 'YTick', yt(1:step:end));
    end
catch
end
end

function limitColorbarTicks(cb, nmax)
try
    tk = cb.Ticks;
    if numel(tk) > nmax
        step = ceil(numel(tk) / nmax);
        cb.Ticks = tk(1:step:end);
    end
catch
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
