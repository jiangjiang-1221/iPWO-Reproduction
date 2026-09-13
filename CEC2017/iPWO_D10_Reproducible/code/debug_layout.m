%% debug_layout.m  调试: dump 布局数值, 定位溢出元素
clear; clc; close all;

tgtCm = 2.928; fs = 9;
set(0, 'DefaultAxesFontSize', fs);
set(0, 'DefaultTextFontSize', fs);
set(0, 'DefaultLegendFontSize', fs);
set(0, 'DefaultColorbarFontSize', fs);

fig = figure('Units', 'centimeters', 'Position', [3 3 tgtCm tgtCm], ...
    'Color', 'w', 'InvertHardcopy', 'off', 'PaperPositionMode', 'manual');
ax = axes('Parent', fig);
ax.OuterPosition = [0 0 1 1];

x = 1:100; y = exp(-x/30);
plot(ax, x, y, 'LineWidth', 1.0);
grid(ax, 'on'); box(ax, 'on');
xlabel(ax, 'Iteration');
ylabel(ax, 'Fitness value (Dim=10)');
title(ax, 'Avg. fitness');
lgd = legend(ax, 'iPWO', 'Location', 'northeast');
set(ax, 'XTick', [1, 50]);

drawnow;
ti = ax.TightInset;
fprintf('TightInset = [%.3f %.3f %.3f %.3f]\n', ti);
ax.Position = [ti(1)-0.015, ti(2)-0.015, 1-ti(1)-ti(3)+0.03, 1-ti(2)-ti(4)+0.03];
drawnow;
fprintf('ax.Position = [%.3f %.3f %.3f %.3f]  右缘=%.3f 上缘=%.3f\n', ...
    ax.Position, ax.Position(1)+ax.Position(3), ax.Position(2)+ax.Position(4));

% 每个文字对象的范围(归一化于 figure)
txts = findall(fig, 'Type', 'text');
for i = 1:numel(txts)
    if isempty(txts(i).String), continue; end
    fprintf('text %-24s Extent(fig) = [%s]\n', ...
        strrep(txts(i).String(1:min(22,end)), newline, ' '), ...
        sprintf('%.3f ', txts(i).Extent));
end
fprintf('legend Position(fig) = [%s]  Units=%s\n', sprintf('%.3f ', lgd.Position), lgd.Units);

% 导出并查看
fig.PaperUnits = 'centimeters';
fig.PaperSize = [tgtCm tgtCm];
fig.PaperPosition = [0 0 tgtCm tgtCm];
print(fig, 'D:/File/GPTTest/CEC2017_Experiment/iPWO_Reproducible/CEC2017/iPWO_D10_Reproducible/figures/_test_out/_debug_p4.tif', '-dtiff', '-r600');
close(fig);
fprintf('调试图已导出\n');
