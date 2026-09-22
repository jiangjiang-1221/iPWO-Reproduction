function redraw_bar_mean()
% redraw_bar_mean - redraw fig4_bar_mean.tif: 7-algorithm Mean Z bar chart (with error bars)
% original used matplotlib default DejaVu Sans font; this script redraws to paper standard:
% Times New Roman / 28pt / 11.5x8in / 330 DPI (consistent with the other 8 MATLAB figures).
% data source: data/delivery_results.mat (meanv / stdv);
% color scheme identical to fig5_boxplot boxColors (iPWO red + cool-color gradient).

    U = 'D:\File\GPTTest\uav_delivery\uav_delivery_TIFF_MATLAB';
    addpath(U); cd(U);
    set(groot,'defaultTextInterpreter','none');
    set(groot,'defaultAxesFontName',   'Times New Roman');
    set(groot,'defaultTextFontName',   'Times New Roman');
    set(groot,'defaultLegendFontName', 'Times New Roman');
    set(groot,'defaultColorbarFontName','Times New Roman');
    FS = 28;

    D = load(fullfile(U, 'data', 'delivery_results.mat'));
    algos = D.algos; mu = D.meanv; sd = D.stdv;
    nAlg = numel(algos);

    % color scheme: same as fig5_boxplot (iPWO red + cool-color gradient)
    redCol = [0.90 0.15 0.20];
    coolPalette = [
        0.15  0.75  0.70   % PWO  teal
        0.10  0.62  0.82   % GWO  cyan
        0.18  0.48  0.80   % PSO  azure
        0.28  0.38  0.76   % DE   royal blue
        0.40  0.30  0.70   % MGO  indigo
        0.00  0.72  0.55]; % SFOA emerald
    cols = [redCol; coolPalette];

    fig = figure('Color','w','Position',[150 150 1150 800]);
    set(fig,'PaperUnits','inches','PaperSize',[11.5 8],'PaperPosition',[0 0 11.5 8],'PaperPositionMode','manual');
    ax = axes('Parent',fig); hold(ax,'on');

    b = bar(ax, 1:nAlg, mu, 0.65, 'FaceColor', 'flat');
    b.CData = cols;
    errorbar(ax, 1:nAlg, mu, sd, 'LineStyle', 'none', 'Color', 'k', 'LineWidth', 1.6);

    set(ax,'XTick',1:nAlg,'XTickLabel',algos,'FontSize',FS,'LineWidth',1.4, ...
           'TickLabelInterpreter','none');
    ylabel(ax,'Mean constrained cost Z','FontSize',FS);
    xlabel(ax,'Algorithm','FontSize',FS);
    title(ax,'Mean Z of Each Algorithm over 51 Runs','FontSize',FS,'FontWeight','bold');
    grid(ax,'on');

    % inline export (margin retraction + 330 DPI, same logic as uav_print)
    axs = findall(fig, 'type', 'axes');
    m = 0.012;
    for a = 1:numel(axs)
        ax2 = axs(a);
        for pass = 1:3
            op = ax2.OuterPosition; p = ax2.Position; changed = false;
            if op(2) < m, s = m-op(2); p(2)=p(2)+s; p(4)=p(4)-s; changed=true; end
            if op(2)+op(4) > 1-m, s = op(2)+op(4)-(1-m); p(4)=p(4)-s; changed=true; end
            if op(1) < m, s = m-op(1); p(1)=p(1)+s; p(3)=p(3)-s; changed=true; end
            if op(1)+op(3) > 1-m, s = op(1)+op(3)-(1-m); p(3)=p(3)-s; changed=true; end
            if ~changed, break; end
            ax2.Position = p; drawnow;
        end
    end
    drawnow;
    print(fig, fullfile(U,'figs','fig4_bar_mean.tif'), '-dtiffn', '-r330');
    close(fig);
    fprintf('fig4_bar_mean redrawn with Times New Roman\n');
end
