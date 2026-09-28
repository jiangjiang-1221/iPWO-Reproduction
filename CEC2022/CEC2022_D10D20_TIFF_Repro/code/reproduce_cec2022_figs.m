function reproduce_cec2022_figs()
% =====================================================================
%  reproduce_cec2022_figs.m
%  Reproduce CEC2022 (Dim = 10 / 20) Boxplot and Convergence figures
%  with the SAME style as CEC2017Dim10_TIFF_MATLAB/generate_figures.m:
%
%   - Global font   : Times New Roman (default for axes/text/legend)
%   - Font size     : 22 pt everywhere (legend 20 pt)
%   - Output        : 330 DPI TIFF via exportgraphics
%   - Canvas        : boxplot 9 x 6 in, convergence 9.5 x 6 in
%   - Boxplot       : hand-drawn GRADIENT boxes (surface texturemap),
%                     palette identical to main30New.m, margins set so
%                     x tick labels are NOT clipped
%   - Convergence   : log y-axis with ADAPTIVE y-limits computed in LOG
%                     space (tight fit per function so the 9 curves fill
%                     the axis and stay distinguishable), unified e-notation
%                     y tick labels, x starts at 0 (data-driven)
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

% Palette - identical to main30New.m / CEC2017Dim10_TIFF_MATLAB
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

codeDir = fileparts(mfilename('fullpath'));
dataDir = fullfile(codeDir, '..', 'data');
figDir  = fullfile(codeDir, '..', 'figures');
if ~exist(figDir, 'dir'), mkdir(figDir); end

dims  = [10 20];
funcs = 1:12;

fprintf('Generating CEC2022 D10/D20 figures (TNR, %d pt, %d DPI, gradient boxes, adaptive log axis)...\n', FONT_SIZE, DPI);

for di = 1:numel(dims)
    dim = dims(di);
    for f = funcs
        bw = fullfile(dataDir, sprintf('CEC2022_F%d_Dim%d_Best_Values.xlsx', f, dim));
        cw = fullfile(dataDir, sprintf('CEC2022_F%d_Dim%d_Avg_Convergence.xlsx', f, dim));
        if ~isfile(bw) || ~isfile(cw)
            warning('Skip F%d Dim=%d: data file missing', f, dim);
            continue;
        end

        % =================== BOXPLOT (hand-drawn gradient) ===================
        data = readmatrix(bw, 'NumHeaderLines', 1);   % runs x 9

        figure('Color', 'w', 'Units', 'inches', 'Position', [0 0 9 6]);
        ax = axes;
        hold(ax, 'on');
        grid(ax, 'off');

        boxWidth = 0.6;
        xCenters = 1:num_alg;

        for pp = 1:num_alg
            col_top    = palette(pp, :);
            col_bottom = col_top + (1 - col_top) * 0.85;
            col_bottom = min(max(col_bottom, 0), 1);

            vals = data(:, pp);
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

            x0 = xCenters(pp);

            % gradient-filled box body (surface/texturemap)
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

            % box outline
            plot(ax, [x0-boxWidth/2, x0+boxWidth/2, x0+boxWidth/2, x0-boxWidth/2, x0-boxWidth/2], ...
                 [q1, q1, q3, q3, q1], '-', 'Color', col_top, 'LineWidth', 1.3);

            % median line (thicker)
            plot(ax, [x0-boxWidth/2, x0+boxWidth/2], [q2, q2], '-', ...
                 'Color', col_top, 'LineWidth', 2.4);

            % whiskers
            plot(ax, [x0, x0], [lowerWhisk, q1], '-', 'Color', col_top, 'LineWidth', 1.1);
            plot(ax, [x0, x0], [q3, upperWhisk], '-', 'Color', col_top, 'LineWidth', 1.1);

            % caps
            capW = boxWidth * 0.25;
            plot(ax, [x0-capW/2, x0+capW/2], [lowerWhisk, lowerWhisk], '-', ...
                 'Color', col_top, 'LineWidth', 1.1);
            plot(ax, [x0-capW/2, x0+capW/2], [upperWhisk, upperWhisk], '-', ...
                 'Color', col_top, 'LineWidth', 1.1);
        end

        % axes formatting
        xlim(ax, [0.5, num_alg + 0.5]);
        set(ax, 'XTick', xCenters, 'XTickLabel', ALGOS, ...
               'FontSize', FONT_SIZE, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
        title(ax, sprintf('CEC2022 F%d, Dim=%d', f, dim), ...
              'FontSize', FONT_SIZE, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
        ylabel(ax, 'Best value (per run)', 'FontSize', FONT_SIZE, 'FontName', 'Times New Roman');
        % y-axis unified e-notation
        tks = ax.YTick;
        ax.YTickLabel = cellfun(@fmt_e, num2cell(tks), 'UniformOutput', false);
        ax.Position = [0.13 0.14 0.84 0.76];     % margins so labels not clipped
        grid(ax, 'on'); ax.YGrid = 'on'; ax.GridLineStyle = '--';

        out_b = fullfile(figDir, sprintf('CEC2022_F%d_Dim%d_Boxplot_BestValues.tif', f, dim));
        exportgraphics(gcf, out_b, 'Resolution', DPI, 'ContentType', 'image');
        close;

        % ========== CONVERGENCE (log axis + adaptive limits) ==========
        cdata = readmatrix(cw, 'NumHeaderLines', 1);   % n x 9
        nfe = size(cdata, 1);
        fe  = (0:nfe-1).';                    % iteration 0 .. nfe-1 (0-based)

        figure('Units', 'inches', 'Position', [0 0 9.5 6]);
        hold on;
        for a = 1:num_alg
            y = cdata(:, a);
            y(y <= 0) = NaN;                  % guard: log axis needs positives
            semilogy(fe, y, ...
                     'Color', palette(a, :), ...
                     'Marker', MARKERS{a}, ...
                     'MarkerIndices', 1:round(nfe/20):nfe, ...
                     'MarkerSize', 6, 'LineWidth', 2.0);
        end
        hold off;
        ax = gca;
        ax.Position = [0.14 0.14 0.80 0.76];  % explicit margins, no clipping
        ax.YScale = 'log';                    % force log (semilogy under hold may not)
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
        ax.FontSize = FONT_SIZE; ax.FontName = 'Times New Roman';
        xlabel(ax, 'Iteration', 'FontSize', FONT_SIZE, 'FontName', 'Times New Roman');
        ylabel(ax, 'Best Score', 'FontSize', FONT_SIZE, 'FontName', 'Times New Roman');
        title(ax, sprintf('CEC2022 F%d, Dim=%d', f, dim), ...
              'FontSize', FONT_SIZE, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
        legend(ALGOS, 'Location', 'northeast', 'FontSize', FONT_SIZE - 2, 'FontName', 'Times New Roman');
        xlim(ax, [0 nfe-1]);                  % x-axis: 0 -> last iteration
        ax.MinorGridLineStyle = ':';          % log-axis minor grid
        % y-axis unified e-notation
        tks = ax.YTick;
        ax.YTickLabel = cellfun(@fmt_e, num2cell(tks), 'UniformOutput', false);
        grid(ax, 'on'); ax.YGrid = 'on'; ax.GridLineStyle = '--';

        out_c = fullfile(figDir, sprintf('CEC2022_F%d_Dim%d_Convergence.tif', f, dim));
        exportgraphics(gcf, out_c, 'Resolution', DPI, 'ContentType', 'image');
        close;

        fprintf('  F%d Dim=%d done\n', f, dim);
    end
end

fprintf('All figures written to: %s\n', figDir);
end   % reproduce_cec2022_figs


% =====================================================================
%  fmt_e : format a number as compact scientific (e) notation
%          e.g.  1000 -> '1e3',  2.4e10 -> '2.4e10',  1500 -> '1.5e3'
%          Used so boxplot & convergence axes share ONE notation style.
% =====================================================================
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
