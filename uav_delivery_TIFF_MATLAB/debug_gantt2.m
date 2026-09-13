matpath = 'D:/File/GPTTest/uav_delivery/uav_delivery_TIFF_MATLAB/data/delivery_results.mat';
load(matpath);
FS = 18;
uav_colors = lines(6);
figsdir = 'D:/File/GPTTest/uav_delivery/uav_delivery_TIFF_MATLAB/figs';

fig = figure('Color','w','Position',[150 150 1150 800]);
ax = axes('Parent',fig); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
maxT = 1;
for u = 1:env.Nu
    seq = best_diag.R.cust_seq{u};
    arr = best_diag.arr{u};
    if isempty(seq), continue; end
    fprintf('UAV-%d: seq len=%d, arr len=%d\n', u, numel(seq), numel(arr));
    yy = (env.Nu - u);
    for k = 1:numel(seq)
        j = seq(k);
        e = env.tw(j,1); l = env.tw(j,2);
        a = arr(k);
        fprintf('  k=%d j=%d e=%g l=%g a=%g width=%g\n', k, j, e, l, a, (l-e));
        rectangle(ax,'Position',[e, yy-0.35, (l-e), 0.7], ...
            'FaceColor',[0.86 0.91 0.96],'EdgeColor','none');
        rectangle(ax,'Position',[a, yy-0.30, env.TS, 0.60], ...
            'FaceColor',uav_colors(u,:),'EdgeColor',[0.15 0.15 0.15],'LineWidth',1);
        maxT = max(maxT, a + env.TS);
    end
end
fprintf('maxT=%g\n', maxT);
xlabel(ax,'Time  t (s)','FontSize', FS);
ylabel(ax,'UAV index','FontSize', FS);
yt = (env.Nu-1):-1:0;
set(ax,'YTick',yt,'YTickLabel',arrayfun(@(x)sprintf('UAV-%d',x+1),yt,'UniformOutput',false));
try
    xlim(ax,[0 max(maxT,1)*1.05]);
    fprintf('xlim OK\n');
catch ME
    fprintf('XLIM ERROR: %s\n', ME.message);
end
title(ax,'Time-Window Feasibility Gantt (best IPWO solution)','FontSize', FS,'FontWeight','bold');
set(ax,'FontSize', FS,'LineWidth',1.4,'TickLabelInterpreter','none');
try
    print(fig,fullfile(figsdir,'fig9_gantt.tif'),'-dtiffn','-r330');
    fprintf('print OK\n');
catch ME
    fprintf('PRINT ERROR: %s\n', ME.message);
end
close(fig);
