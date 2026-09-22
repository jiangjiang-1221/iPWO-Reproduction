function generate_figures()
% =====================================================================
%  generate_figures.m
%  Reproduce CEC2017 Boxplot and Convergence figures as TIFF.
%  Dimension-aware: reads the "Dim<d>" tag from the file names, so this
%  same script works for CEC2017Dim10, CEC2017Dim30, CEC2017Dim50, ...
%
%   - Global font size          : 18 pt
%   - Output resolution          : 330 DPI, TIFF
%   - Convergence plot           : NO inset (zoom) subplot
%   - Convergence x-axis         : starts at 0, ends at the last iteration
%                                  (data-driven: 0 .. nfe-1)
%   - Convergence lines          : thickened (LineWidth 2.0)
%   - Y-axis notation            : unified scientific (e) notation
%                                  (no mix of 10^x / e / plain numbers)
%   - Boxplot
%       * Title shows the CEC2017 function -> "CEC2017 F<id>, Dim=<d>"
%       * Y-axis uses scientific (e) notation (same style as convergence)
%       * X tick labels are NOT clipped (margins set)
%       * Hand-drawn GRADIENT boxes (identical to main30New.m style):
%         vertical colour gradient from col_top to col_bottom via
%         surface('FaceColor','texturemap') + interpolated CData.
%
%  Note on data: SFOA's first convergence point used to be a stale 0
%  (old SFOA.m bug). The *_Avg_Convergence.xlsx in ./data already have
%  that first point replaced by the second point (curve(1)=curve(2)),
%  so the convergence curves start at the correct value.
%
%  USAGE
%   1) Keep this script in the project folder.
%   2) Put the *_Best_Values.xlsx and *_Avg_Convergence.xlsx pairs inside
%      the 'data' subfolder (one pair per CEC2017 function, F1/F3..F30).
%   3) Run:  generate_figures
%   The .tif figures are written to the 'figures' subfolder.
%
%  REQUIREMENTS: MATLAB R2020a or newer (uses exportgraphics).
% =====================================================================

clc; clear;

% Force Times New Roman as the default font family for all text
set(0, 'DefaultAxesFontName',   'Times New Roman');
set(0, 'DefaultTextFontName',   'Times New Roman');
set(0, 'DefaultLegendFontName', 'Times New Roman');


FONT_SIZE = 22;
DPI       = 330;

% 9 algorithms (column order MUST match the .xlsx files)
ALGOS = {'iPWO','PWO','SFOA','DRA','MGO','LCA','DE','PSO','GWO'};
num_alg = numel(ALGOS);

% Palette - identical to main30New.m (lines 270-281)
palette = [ ...
    1.00 0.00 0.00; ...   % iPWO  - bright red
    0.00 0.45 0.74; ...   % PWO   - blue
    0.13 0.55 0.13; ...   % SFOA  - green
    0.55 0.00 0.80; ...   % DRA   - purple
    0.92 0.55 0.10; ...   % MGO   - orange
    0.00 0.62 0.62; ...   % LCA   - teal
    0.95 0.78 0.00; ...   % DE    - gold
    0.30 0.75 0.93; ...   % PSO   - light blue
    0.50 0.50 0.50];      % GWO   - gray

MARKERS = {'*','o','^','d','s','v','+','x','p'};

% ---- folders (script-relative) ----
script_dir = fileparts(mfilename('fullpath'));
data_dir   = fullfile(script_dir, 'data');
out_dir    = fullfile(script_dir, 'figures');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end

% ---- discover functions from the Best_Values files (dimension-aware) ----
xlsx_files = dir(fullfile(data_dir, '*_Best_Values.xlsx'));
if isempty(xlsx_files)
    error('No *_Best_Values.xlsx found in the data/ folder.');
end
func_ids = zeros(numel(xlsx_files), 1);
dims     = zeros(numel(xlsx_files), 1);
for k = 1:numel(xlsx_files)
    tk = regexp(xlsx_files(k).name, 'F(\d+)_Dim(\d+)', 'tokens');
    func_ids(k) = str2double(tk{1}{1});
    dims(k)     = str2double(tk{1}{2});
end
func_ids = sort(func_ids);
dim = mode(dims);                       % the dimension (e.g. 10 / 30 / 50)
if any(dims ~= dim)
    warning('Mixed dimensions found in data folder; using mode = %d.', dim);
end

fprintf('Generating figures for %d functions (Dim=%d, 18 pt font, %d DPI, gradient boxes)...\n', ...
        numel(func_ids), dim, DPI);

for fi = 1:numel(func_ids)
    fid = func_ids(fi);

    % ===================== BOXPLOT (hand-drawn gradient) =====================
    bw = fullfile(data_dir, sprintf('CEC2017_F%d_Dim%d_Best_Values.xlsx', fid, dim));
    data = readmatrix(bw, 'NumHeaderLines', 1);   % 51 x 9

    figure('Color', 'w', 'Units', 'inches', 'Position', [0 0 9 6]);
    ax = axes;
    hold(ax, 'on');
    grid(ax, 'off');

    boxWidth = 0.6;
    xCenters = 1:num_alg;

    for pos = 1:num_alg
        col_top     = palette(pos, :);
        col_bottom = col_top + (1 - col_top) * 0.85;
        col_bottom = min(max(col_bottom, 0), 1);

        vals = data(:, pos);
        vals = vals(~isnan(vals));
        if isempty(vals)
            q1 = 0; q2 = 0; q3 = 0;
            lowerWhisk = 0; upperWhisk = 0;
        else
            q1 = prctile(vals, 25);
            q2 = prctile(vals, 50);
            q3 = prctile(vals, 75);
            iqr_val = q3 - q1;
            lowerWhisk = max(min(vals), q1 - 1.5 * iqr_val);
            upperWhisk = min(max(vals), q3 + 1.5 * iqr_val);
        end

        x0 = xCenters(pos);

        % --- gradient-filled box body (main30New.m surface/texturemap) ---
        if q3 > q1
            ny = 200; nx = 2;
            ys = linspace(q1, q3, ny);
            xs = linspace(x0 - boxWidth/2, x0 + boxWidth/2, nx);
            [Xg, Yg] = meshgrid(xs, ys);
            C = zeros(ny, nx, 3);
            for k = 1:3
                C(:, :, k) = repmat(linspace(col_top(k), col_bottom(k), ny)', 1, nx);
            end
            surface('XData', Xg, 'YData', Yg, 'ZData', zeros(size(Xg)), ...
                    'CData', C, 'FaceColor', 'texturemap', ...
                    'EdgeColor', 'none', 'Parent', ax);
        else
            rect_x = [x0-boxWidth/2, x0+boxWidth/2, x0+boxWidth/2, x0-boxWidth/2];
            rect_y = [q1-eps, q1+eps, q1+eps, q1-eps];
            patch(ax, rect_x, rect_y, col_top, 'EdgeColor', 'none');
        end

        % --- box outline ---
        plot(ax, [x0-boxWidth/2, x0+boxWidth/2, x0+boxWidth/2, x0-boxWidth/2, x0-boxWidth/2], ...
             [q1, q1, q3, q3, q1], '-', 'Color', col_top, 'LineWidth', 1.3);

        % --- median line (thicker) ---
        plot(ax, [x0-boxWidth/2, x0+boxWidth/2], [q2, q2], '-', ...
             'Color', col_top, 'LineWidth', 2.4);

        % --- whiskers ---
        plot(ax, [x0, x0], [lowerWhisk, q1], '-', 'Color', col_top, 'LineWidth', 1.1);
        plot(ax, [x0, x0], [q3, upperWhisk], '-', 'Color', col_top, 'LineWidth', 1.1);

        % --- caps ---
        capW = boxWidth * 0.25;
        plot(ax, [x0-capW/2, x0+capW/2], [lowerWhisk, lowerWhisk], '-', ...
             'Color', col_top, 'LineWidth', 1.1);
        plot(ax, [x0-capW/2, x0+capW/2], [upperWhisk, upperWhisk], '-', ...
             'Color', col_top, 'LineWidth', 1.1);
    end

    % --- axes formatting ---
    xlim(ax, [0.5, num_alg + 0.5]);
    set(ax, 'XTick', xCenters, 'XTickLabel', ALGOS, ...
           'FontSize', FONT_SIZE, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
    title(ax, sprintf('CEC2017 F%d, Dim=%d', fid, dim), ...
          'FontSize', FONT_SIZE, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
    ylabel(ax, 'Best value (per run)', 'FontSize', FONT_SIZE, 'FontName', 'Times New Roman');
    % y-axis unified e-notation (no mix of 10^x / e / plain numbers)
    tks = ax.YTick;
    ax.YTickLabel = cellfun(@fmt_e, num2cell(tks), 'UniformOutput', false);
    ax.Position = [0.13 0.14 0.84 0.76];     % margins so labels not clipped
    grid(ax, 'on'); ax.YGrid = 'on'; ax.GridLineStyle = '--';

    out_b = fullfile(out_dir, sprintf('CEC2017_F%d_Dim%d_Boxplot_BestValues.tif', fid, dim));
    exportgraphics(gcf, out_b, 'Resolution', DPI, 'ContentType', 'image');
    close;

    % ============== CONVERGENCE (no inset, x starts at 0) ==============
    cw = fullfile(data_dir, sprintf('CEC2017_F%d_Dim%d_Avg_Convergence.xlsx', fid, dim));
    cdata = readmatrix(cw, 'NumHeaderLines', 1);   % n x 9
    nfe = size(cdata, 1);
    fe  = (0:nfe-1).';                    % iteration 0 .. nfe-1 (0-based)

    figure('Units', 'inches', 'Position', [0 0 9.5 6]);
    hold on;
    for a = 1:num_alg
        semilogy(fe, cdata(:, a), ...
                 'Color', palette(a, :), ...
                 'Marker', MARKERS{a}, ...
                 'MarkerIndices', 1:round(nfe/20):nfe, ...
                 'MarkerSize', 6, 'LineWidth', 2.0);
    end
    hold off;
    ax = gca;
    ax.Position = [0.14 0.14 0.80 0.76];     % explicit margins so larger labels are not clipped
    ax.YScale = 'log';                    % FORCE log y-axis (semilogy under 'hold on' may not apply it)
    % data-driven y-limits (powers of ten) so curves spread across the axis
    % instead of being crushed to the bottom of a 0..2e10 linear range
    % Adaptive y-limits: fit tightly to actual data so curves spread
    % across the full axis and stay distinguishable (no overlap).
    % Adaptive y-limits computed in LOG space: tight fit to this function's
    % actual data so the curves fill the full axis height and stay
    % distinguishable (robust for any data span: 1 decade or 10 decades).
    allv = cdata(cdata > 0);
    if isempty(allv), allv = cdata(:); end
    lmin = log10(min(allv));
    lmax = log10(max(allv));
    lpad = 0.05 * (lmax - lmin);
    ylo = 10^(lmin - lpad);
    yhi = 10^(lmax + lpad);
    ylim(ax, [ylo, yhi]);
    ax.FontSize = FONT_SIZE; ax.FontName = 'Times New Roman';;
    xlabel(ax, 'Iteration', 'FontSize', FONT_SIZE, 'FontName', 'Times New Roman');
    ylabel(ax, 'Best Score', 'FontSize', FONT_SIZE, 'FontName', 'Times New Roman');
    title(ax, sprintf('CEC2017 F%d, Dim=%d', fid, dim), ...
          'FontSize', FONT_SIZE, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
    legend(ALGOS, 'Location', 'northeast', 'FontSize', FONT_SIZE - 2, 'FontName', 'Times New Roman');
    xlim(ax, [0 nfe-1]);                  % x-axis: 0 -> last iteration (data-driven)
    ax.MinorGridLineStyle = ':';           % log-axis minor grid
    % y-axis unified e-notation (no mix of 10^x / e / plain numbers)
    tks = ax.YTick;
    ax.YTickLabel = cellfun(@fmt_e, num2cell(tks), 'UniformOutput', false);
    grid(ax, 'on'); ax.YGrid = 'on'; ax.GridLineStyle = '--';

    out_c = fullfile(out_dir, sprintf('CEC2017_F%d_Dim%d_Convergence.tif', fid, dim));
    exportgraphics(gcf, out_c, 'Resolution', DPI, 'ContentType', 'image');
    close;

    fprintf('  F%d done\n', fid);
end

fprintf('All %d figures (Dim=%d) written to: %s\n', numel(func_ids), dim, out_dir);

% =====================================================================
%  fmt_e  : format a number as compact scientific (e) notation
%           e.g.  1000 -> '1e3',  2.4e10 -> '2.4e10',  1500 -> '1.5e3'
%           Used so boxplot & convergence axes share ONE notation style.
% =====================================================================
end

function s = fmt_e(x)
    if x == 0
        s = '0';
        return;
    end
    p = floor(log10(abs(x)));
    m = x / 10^p;
    if abs(m - round(m)) < 1e-6
        s = sprintf('%de%d', round(m), p);
    else
        s = sprintf('%.1fe%d', m, p);
    end
end
