% independently redraw fig9_gantt (fix YTick non-monotonic error, no full re-run needed)
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
    yy = (env.Nu - u);                 % UAV-1 on top
    for k = 1:numel(seq)
        j = seq(k);
        e = env.tw(j,1); l = env.tw(j,2);
        a = arr(k);
        rectangle(ax,'Position',[e, yy-0.35, (l-e), 0.7], ...
            'FaceColor',[0.86 0.91 0.96],'EdgeColor','none');
        rectangle(ax,'Position',[a, yy-0.30, env.TS, 0.60], ...
            'FaceColor',uav_colors(u,:),'EdgeColor',[0.15 0.15 0.15],'LineWidth',1);
        maxT = max(maxT, a + env.TS);
    end
end
xlabel(ax,'Time  t (s)','FontSize', FS);
ylabel(ax,'UAV index','FontSize', FS);
yt = 0:(env.Nu-1);                      % must be increasing
set(ax,'YTick',yt,'YTickLabel',arrayfun(@(x)sprintf('UAV-%d',env.Nu-x),yt,'UniformOutput',false));
xlim(ax,[0 max(maxT,1)*1.05]);
title(ax,'Time-Window Feasibility Gantt (best IPWO solution)', ...
    'FontSize', FS,'FontWeight','bold');
set(ax,'FontSize', FS,'LineWidth',1.4,'TickLabelInterpreter','none');
print(fig,fullfile(figsdir,'fig9_gantt.tif'),'-dtiffn','-r330');
close(fig);
fprintf('[OK] fig9_gantt.tif  maxT=%.2f\n', maxT);
