function ch6_print(fig, fname, keepOpen)
% ch6_print - unified TIFF export: 330 DPI, font 27 pt (same visual size as
% 22 pt on a 9-inch figure), Times New Roman, figure size 11 x 7.5 inch.
% used to export all reproducible figures for Chapter 6 ablation/mechanism verification.
%
% ch6_print(fig, fname)          export and close window
% ch6_print(fig, fname, true)    export but keep window (for font audit/inspection)
FS = 27;
set(fig, 'Color', 'w', ...
    'PaperUnits', 'inches', ...
    'PaperSize', [11 7.5], ...
    'PaperPosition', [0 0 11 7.5], ...
    'PaperPositionMode', 'manual', ...
    'DefaultAxesFontSize', FS, ...
    'DefaultTextFontSize', FS);
set(findall(fig, 'type', 'text'), 'FontSize', FS);
set(findall(fig, 'type', 'axes'), 'FontSize', FS, 'LineWidth', 1.1);
% Times New Roman for every text object (axes ticks, labels, titles,
% legends, colorbars) - Chapter6 figures follow the thesis font standard.
set(findall(fig, 'type', 'text'),     'FontName', 'Times New Roman');
set(findall(fig, 'type', 'axes'),     'FontName', 'Times New Roman');
set(findall(fig, 'type', 'legend'),   'FontName', 'Times New Roman');
set(findall(fig, 'type', 'colorbar'), 'FontName', 'Times New Roman');
% Nudge axes inward ONLY when tick labels / titles / colorbars would spill
% outside the fixed 11x7.5 paper at large font sizes (no-op otherwise).
axs = findall(fig, 'type', 'axes');
m = 0.015;                                 % required margin (normalized)
for a = 1:numel(axs)
    ax = axs(a);
    for pass = 1:3
        op = ax.OuterPosition;
        p  = ax.Position;
        changed = false;
        if op(2) < m                     % bottom (x tick labels / xlabel)
            s = m - op(2); p(2) = p(2) + s; p(4) = p(4) - s; changed = true;
        end
        if op(2) + op(4) > 1 - m         % top (title)
            s = op(2) + op(4) - (1 - m); p(4) = p(4) - s; changed = true;
        end
        if op(1) < m                     % left (y tick labels / ylabel)
            s = m - op(1); p(1) = p(1) + s; p(3) = p(3) - s; changed = true;
        end
        if op(1) + op(3) > 1 - m         % right (colorbar)
            s = op(1) + op(3) - (1 - m); p(3) = p(3) - s; changed = true;
        end
        if ~changed, break; end
        ax.Position = p;
        drawnow;
    end
end
drawnow;
print(fig, fname, '-dtiffn', '-r330');
if nargin < 3 || ~keepOpen
    close(fig);
end
end
