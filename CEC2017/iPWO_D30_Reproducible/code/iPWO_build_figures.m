function iPWO_build_figures(Function_name, dim, lb, ub, fobj, best_run, avg_best_curve, avg_fit_curve, Lcurve, outDir, opts)
% iPWO_BUILD_FIGURES  generate CEC2017 iPWO individual panel figures (paper publication spec)
%
%  ===== layout spec (derived from A4 page) =====
%    A4 = 21.0 x 29.7 cm, top/bottom margin 2.54 cm, left/right margin 3.18 cm
%    => usable text width = 21.0 - 2*3.18 = 14.64 cm
%    => exactly 5 panels per row => each side = 14.64 / 5 = 2.928 cm (square)
%    => TIFF, 600 DPI  => 2.928/2.54*600 = 692 x 692 px
%    => exported physical font size 6 pt (much smaller than body 10.5 pt, larger plotting area)
%
%  ===== drawing method =====
%    WYSIWYG: canvas is 2.928 cm, font is 6 pt, print -r600 outputs at 1:1.
%    axes use OuterPosition=[0 0 1 1] for auto layout; MATLAB automatically reserves
%    space for title/axis labels/ticks, ensuring labels are not clipped.
%
%  ===== output =====
%    - no five-panel figure; output 5 individual panels only:
%        1_3D_Landscape / 2_Objective_Space / 3_Trajectory
%        4_Average_Fitness / 5_Search_History
%    - each panel also saved as .fig source to <outDir>/fig for later editing:
%      .fig is an equally scaled edit version (default 8 cm canvas, font scaled up),
%      visual ratio identical to exported figure; after editing use export_figs_to_tiff.m
%      to re-export at paper spec with one call.
%    - all data needed to reproduce figures saved to reproDir
%
%  inputs:
%    Function_name : CEC2017 function index
%    dim           : dimension
%    lb, ub        : bounds
%    fobj          : objective function handle; pass [] if cached landscape or opts.landscape given
%    best_run      : best single run result (score/pos/curve/history/time)
%    avg_best_curve, avg_fit_curve : average curves over multiple runs
%    Lcurve        : curve length
%    outDir        : output directory (panel TIFFs)
%    opts          : optional parameters
%        .dpi              default 600
%        .fontSize         default 6   (exported physical font size pt)
%        .panelCm          default 2.928 (exported physical side length cm)
%        .editCm           default 8   (.fig edit canvas side length cm)
%        .saveFig          default true (save .fig source)
%        .alg_name          default 'iPWO'
%        .landscapeCacheDir terrain cache dir, default outDir/landscape_cache
%        .reproDataDir      reproduction data dir, default outDir/repro_data
%        .landscape         precomputed terrain struct (x1g,x2g,zGrid,base_point,zbest)
%        .trajIter/.trajDist/.trajectoryOK  pre-extracted trajectory (for pure-data reproduction)
%        .searchXY/.searchIter/.historyOK   pre-extracted search history (for pure-data reproduction)
%        .prefix            file name prefix, default 'CEC2017' (pass 'CEC2022' for CEC2022)
%        .benchLabel        benchmark name in figure, default 'CEC2017' (pass 'CEC2022' for CEC2022)
%        .gridN             terrain grid count, default 120

if nargin < 11, opts = struct(); end

%% ==================== 0. layout spec ====================
K        = 4;                                  % render scale factor (small canvas unstable; scaled back after drawing at large canvas)
dpi      = getOpt(opts, 'dpi', 600);
fs       = getOpt(opts, 'fontSize', 6) * K;    % drawing font size (physical 6 pt after export scaling back)
tgtCm    = getOpt(opts, 'panelCm', 2.928) * K; % drawing canvas side (2.928 cm after export scaling back)
editCm   = getOpt(opts, 'editCm', 8);          % .fig edit canvas side (cm)
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

% ---------- global default fonts ----------
set(0, 'DefaultAxesFontSize',     fs);
set(0, 'DefaultTextFontSize',     fs);
set(0, 'DefaultLegendFontSize',   fs);
set(0, 'DefaultColorbarFontSize', fs);
% use Times New Roman as the unified font family (common serif for paper publication)
set(0, 'DefaultAxesFontName',     'Times New Roman');
set(0, 'DefaultTextFontName',     'Times New Roman');
set(0, 'DefaultLegendFontName',   'Times New Roman');
set(0, 'DefaultColorbarFontName', 'Times New Roman');

%% ==================== 1. terrain slice (prefer cache/precompute) ====================
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

%% ==================== 2. trajectory and search history ====================
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

%% ==================== 3. five individual panels ====================
% layout strategy: axes fill canvas when drawing; before export finalizeLayout uses
% MATLAB-measured TightInset (actual space for title/axis labels/ticks) to shrink precisely,
% reserving exactly the space labels need, ensuring no clipping and maximal plotting area.
LAYOUT_MARGIN = 0.008;   % safety margin outside TightInset (normalized, shrink to enlarge plotting area)

% Panel 1: 3D terrain (fixed layout: projection axis labels extend far, reserve space around; fixed box consistent across functions)
fig = newPanelFig(tgtCm);
ax1 = newAxes(fig, [0.33 0.22 0.42 0.58]);   % 3D fixed box (left 0.33 width 0.42: 3D projection extends left/right, needs more margin to avoid clipping)
fillPanel1(ax1, x1g, x2g, zGrid, lb, ub, Function_name, best_xy, zbest, fs, benchLab);
finishPanel(fig, ax1, outDir, figSrcDir, sprintf('F%d_Dim%d_1_3D_Landscape', Function_name, dim), ...
    tgtCm, tgtCm / K, dpi, editCm, saveFigFile);

% Panel 2: objective space (convergence curve)
fig = newPanelFig(tgtCm);
ax2 = newAxes(fig);
fillPanel2(ax2, 1:Lcurve, avg_best_curve, algName, fs);
finishPanel(fig, ax2, outDir, figSrcDir, sprintf('F%d_Dim%d_2_Objective_Space', Function_name, dim), ...
    tgtCm, tgtCm / K, dpi, editCm, saveFigFile);

% Panel 3: trajectory
fig = newPanelFig(tgtCm);
ax3 = newAxes(fig);
fillPanel3(ax3, trajIter, trajDist, trajectoryOK, fs);
finishPanel(fig, ax3, outDir, figSrcDir, sprintf('F%d_Dim%d_3_Trajectory', Function_name, dim), ...
    tgtCm, tgtCm / K, dpi, editCm, saveFigFile);

% Panel 4: average fitness
fig = newPanelFig(tgtCm);
ax4 = newAxes(fig);
fillPanel4(ax4, 1:Lcurve, avg_fit_curve, dim, algName, fs);
finishPanel(fig, ax4, outDir, figSrcDir, sprintf('F%d_Dim%d_4_Average_Fitness', Function_name, dim), ...
    tgtCm, tgtCm / K, dpi, editCm, saveFigFile);

% Panel 5: search history
fig = newPanelFig(tgtCm);
ax5 = newAxes(fig);
fillPanel5(ax5, x1g, x2g, zGrid, lb, ub, allXY, allIter, historyOK, best_xy, fs);
finishPanel(fig, ax5, outDir, figSrcDir, sprintf('F%d_Dim%d_5_Search_History', Function_name, dim), ...
    tgtCm, tgtCm / K, dpi, editCm, saveFigFile);

%% ==================== 4. save figure reproduction data ====================
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
repro.figSpecs.fontSize   = fs;           % exported physical font size
repro.figSpecs.panelCm    = tgtCm;        % exported physical side length
repro.figSpecs.editCm     = editCm;       % .fig edit canvas side length
repro.figSpecs.format     = 'tiff';
repro.figSpecs.panelLayout= 'single';     % single panel only (no five-panel figure)
repro.prefix = prefix;
repro.benchLabel = benchLab;
reproFile = fullfile(reproDir, sprintf('%s_F%d_Dim%d_iPWO_ReproData.mat', prefix, Function_name, dim));
save(reproFile, 'repro');
fprintf('  Reproduction data saved: %s\n', reproFile);
end

%% ==================== panel canvas and export ====================
function fig = newPanelFig(tgtCm)
% WYSIWYG canvas: logical size = exported physical size, font size is physical pt
fig = figure('Units', 'centimeters', 'Position', [3 3 tgtCm tgtCm], ...
    'Color', 'w', 'InvertHardcopy', 'off', 'PaperPositionMode', 'manual');
end

function ax = newAxes(fig, fixedPos)
% 2D panel: after return, finalizeLayout applies a unified fixed box (all 2D panels share plotting area size, fixed label positions)
% 3D panel: pass fixedPos for a dedicated fixed box (projection axis labels need larger margin, but still fixed, consistent across functions)
if nargin >= 2 && ~isempty(fixedPos)
    ax = axes('Parent', fig);
    ax.Position = fixedPos;
    setappdata(ax, 'fixedBox', fixedPos);
else
    ax = axes('Parent', fig);
    ax.OuterPosition = [0 0 1 1];
    setappdata(ax, 'fixedBox', [0.28 0.26 0.51 0.54]);   % 2D unified box (normalized): left 0.28 (fits y tick labels + ylabel) bottom 0.26 width 0.51 height 0.54
end
end

function finalizeLayout(ax)
% fixed layout: directly apply unified plotting box (normalized); no per-figure TightInset adaptive shrink
%   => all images share plotting area size, x/y axis label positions fixed (easier multi-panel alignment in paper)
%   axis tick values may still differ across functions; no need to unify
b = getappdata(ax, 'fixedBox');
if isempty(b)
    b = [0.16 0.15 0.69 0.70];   % default 2D unified box
end
ax.Position = b;
% explicitly disable tick label rotation (some render paths rotate labels, causing overflow)
try
    ax.XAxis.TickLabelRotation = 0;
    ax.YAxis.TickLabelRotation = 0;
catch
end
drawnow;
% colorbar (if any): fixed in margin right of plotting box, does not squeeze/alter it (keeps plotting area consistent with other panels)
%   note: this version's colorbar is a "standalone axes color strip" (see makeColorbarStrip), not linked to data axes,
%       so print -dtiff will not relayout data axes; the fixed plotting box is preserved.
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
% --- 0) fixed layout: apply unified plotting box (all panels share plotting area size, fixed label positions) ---
finalizeLayout(ax);
% --- 1) export TIFF at paper spec (render large -> average area down to 692 px -> 600 DPI tag) ---
tifPath = fullfile(outDir, [nm '.tif']);
export_panel_tiff(fig, tifPath, physCm, dpi);
% --- 2) save equally scaled .fig edit version ---
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
% --- 3) export self-check: report actual pixels and resolution ---
try
    info = imfinfo(tifPath);
    fprintf('  %s.tif -> %d x %d px, %d DPI\n', nm, info.Width, info.Height, ...
        round(info.XResolution));
catch
    fprintf('  %s.tif -> saved (self-check info read failed)\n', nm);
end
end

%% ==================== panel drawing functions ====================
function fillPanel1(ax, x1g, x2g, zGrid, lb, ub, fn, best_xy, zbest, fs, benchLab)
% normalize large z values; fold exponent into zlabel (avoid z-axis exponent overlapping title)
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
[yPlot, ylab] = compactScale(y, 'Best score');   % exponent normalization (prevent auto x10^N overlap with title)
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
    [yPlot, ylab] = compactScale(trajDist, 'Distance');   % exponent normalization (prevent large-value ticks overflow)
    plot(ax, trajIter, yPlot, 'LineWidth', 4.0, 'Color', [0.20 0.45 0.80]);
    hold(ax, 'on');
    plot(ax, trajIter(1), yPlot(1), 'bs', 'MarkerSize', 16, 'MarkerFaceColor', 'b');
    plot(ax, trajIter(end), yPlot(end), 'rp', 'MarkerSize', 28, 'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'k');
    ylabel(ax, ylab);
    % no legend: 'Distance/Start/Best' three-item legend wider than small panel plotting area,
    % meaning shown by start (blue square) and best (red star) markers; explained in figure note
    xlim(ax, [1, max(trajIter)]);
    limitTicks(ax, 4);
else
    ylabel(ax, 'Distance');
    text(ax, 0.5, 0.5, 'Trajectory data not available', ...
        'Units', 'normalized', 'HorizontalAlignment', 'center', ...
        'FontSize', fs, 'Color', 'r');
end
% title and x-axis label placed after plot (ensure MATLAB computes label positions correctly)
xlabel(ax, 'Iteration');
title(ax, 'Trajectory');
applyFont(ax, fs);
end

function fillPanel4(ax, x, y, dim, algName, fs) %#ok<INUSD>
[yPlot, ylab] = compactScale(y, 'Fitness');   % exponent normalization (prevent auto x10^N overlap with title)
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
    % standalone colorbar (self-built small axes strip, not linked to data axes, fully avoids print relayout squeezing plotting area)
    itMin = double(min(allIter(:)));
    itMax = double(max(allIter(:)));
    cb = makeColorbarStrip(ax.Parent, fs, itMin, itMax);
    setappdata(ax, 'panelColorbar', cb);   % cb is a standalone axes handle, positioned by finalizeLayout
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
% in-domain 1/4, 1/2, 3/4 quantile ticks (rounded): endpoint tick labels (e.g. -100/3334) overflow canvas
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
% standalone colorbar: a very narrow axes holding one parula gradient strip, with no link to data axes,
% so print/export will not trigger data axes relayout (fixed plotting box preserved).
%   no ylabel (avoid overlap with contour/scatter); meaning explained in figure note.
grad = reshape(parula(256), 256, 1, 3);          % 256x1x3, row order = color scale (low to high)
cb = axes('Parent', fig, 'Units', 'normalized');
image(cb, grad);
cb.YDir = 'normal';                              % row 1 (lowest color) placed at bottom
cb.XTick = [];
cb.YLim = [0.5 256.5];
cb.YTick = [0.5 256.5];
% user request: remove max iteration number (e.g. 10000) / min iteration number label at colorbar corner,
% keep only the strip itself (the number overflows and covers x-axis ticks on a small canvas).
cb.YTickLabel = {'', ''};
cb.TickLength = [0 0];
cb.YColor = [0 0 0];
cb.XColor = [0 0 0];
cb.Box = 'on';
cb.LineWidth = 2.0;
cb.FontSize = fs;
end

%% ==================== utility functions ====================
function v = getOpt(opts, name, default)
if isfield(opts, name) && ~isempty(opts.(name))
    v = opts.(name);
else
    v = default;
end
end

function [yScaled, yLabel] = compactScale(y, baseLabel)
% on small figures large-value tick labels are too wide; lift powers of 10 into axis label, keep only mantissa on ticks
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
% x-axis uses only [start, mid] two ticks: endpoint tick labels (e.g. 3334) exceed canvas right edge
% y-axis limit tick count to prevent tick label overlap on small figures
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
