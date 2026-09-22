function run_uav_delivery(redraw)
% RUN_UAV_DELIVERY  multi-UAV multi-package delivery joint optimization -- full experiment pipeline
%
% usage:
%   run_uav_delivery           full pipeline (optimization + figures)
%   run_uav_delivery(true)     redraw-only mode: load from data/delivery_results.mat
%                              existing results, skip optimization and regenerate all figures
%                              (used after font/size changes, ~1-2 min)
%
% features:
%   1) define delivery scenario (single depot / 6 UAVs each with own pad / 30 customers / capacity / obstacle avoidance / safety distance / time windows VRPTW)
%   2) run 7 algorithms (iPWO / PWO / GWO / PSO / DE / MGO / SFOA) x R independent runs
%   3) statistical analysis (Best/Median/Mean/Std/AvgRank/Wilcoxon p-value)
%   4) generate 8 paper figures (uniform 1150x800 canvas / 300 DPI / large font / UAV solid models)
%   5) export raw data (MAT / CSV / JSON for Python preview reuse)
%
% usage (MATLAB command line):
%   cd('D:/File/GPTTest/uav_delivery'); run_uav_delivery;
%   or in terminal:  matlab -batch "cd('D:/File/GPTTest/uav_delivery'); run_uav_delivery;"

%% ==================== path setup ====================
script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir), script_dir = pwd; end
cd(script_dir); addpath(script_dir);
% (self-contained: all dependencies copied into this folder)
% (self-contained)

% use plain-text interpreter to avoid $ / \ etc. tex-syntax errors
set(groot,'defaultTextInterpreter','none');
% paper-standard font: Times New Roman (applies globally to all new figures)
set(groot,'defaultAxesFontName',   'Times New Roman');
set(groot,'defaultTextFontName',   'Times New Roman');
set(groot,'defaultLegendFontName', 'Times New Roman');
set(groot,'defaultColorbarFontName','Times New Roman');
set(groot,'defaultAxesFontSize',   16);
set(groot,'defaultTextFontSize',   16);

%% ==================== parameters ====================
runs    = 51;         % number of independent runs (unified to 51 per request)
pop     = 30;          % population size
Lcurve  = 1000;        % convergence-curve sample count
MaxFEs  = 8000;        % per-run function-evaluation budget (convergence/runtime trade-off)
algos   = {'iPWO','PWO','GWO','PSO','DE','MGO','SFOA'};
nAlg    = numel(algos);
FS      = 28;          % global font size: 28pt at 11.5x8in (visually same as 22pt at 9in)

% unified color scheme (consistent with figure_descriptions.md)
algo_colors = [1.00 0.20 0.27;   % iPWO   red (bold)
               0.12 0.47 0.71;   % PWO    blue
               0.17 0.63 0.17;   % GWO    green
               0.58 0.40 0.74;   % PSO    purple
               0.00 0.00 0.00;   % DE     black
               0.55 0.34 0.29;   % MGO    brown
               0.89 0.47 0.19];  % SFOA   orange

uav_colors = [0.122 0.467 0.706;   % UAV-1  blue
              1.000 0.498 0.055;   % UAV-2  orange
              0.173 0.627 0.173;   % UAV-3  green
              0.839 0.153 0.157;   % UAV-4  red
              0.580 0.400 0.750;   % UAV-5  purple
              0.200 0.600 0.700];  % UAV-6  cyan

%% ==================== output directories ====================
outdir  = fullfile(script_dir,'data');
figsdir = fullfile(script_dir,'figs');
if ~exist(outdir,'dir'), mkdir(outdir); end
if ~exist(figsdir,'dir'), mkdir(figsdir); end

% run log (for post-mortem after background runs)
diary(fullfile(outdir,'run_log.txt')); diary on;

%% ==================== scenario construction ====================
env = uav_delivery_env(6, 6);       % engineering instance: 6 UAVs / d_min=6 (30 customers set by env.Nc)
D = env.D;
global G_ZRUN;                 % record best-so-far constraint cost Z across evaluations (for mean convergence plot)
fobj = @(x) fobj_z(x, env);   % wrapper: optimizer still minimizes f while writing the Z trajectory into G_ZRUN

fprintf('\n========== UAV Delivery Joint Optimization ==========\n');
fprintf('Scenario: Nu=%d, Nc=%d, Q=%.1fkg, V=%.1fm/s, d_min=%dm, TW=on (hw=%.0fs, w=%.1f)\n',...
        env.Nu, env.Nc, env.Q, env.V, env.dmin, (env.tw(1,2)-env.tw(1,1))/2, env.tw_w);
fprintf('Pads: %s\n', mat2str(env.pads(:,:),3));
fprintf('Dim D=%d, Pop=%d, MaxFEs=%d, Runs=%d\n\n', D, pop, MaxFEs, runs);

%% ==================== redraw-only mode check ====================
redraw_mode = (nargin >= 1) && ~isempty(redraw) && redraw;
if redraw_mode
    fprintf('\n[REDRAW] loading saved results from data/delivery_results.mat ...\n');
    D = load(fullfile(outdir,'delivery_results.mat'));
    S = D.S; Cmean = D.Cmean;
    best = D.best; med = D.med; meanv = D.meanv; stdv = D.stdv;
    avgRank = D.avgRank; pv = D.pv; algos = D.algos; runs = D.runs;
    % best_diag must be rebuilt from the best solution vector (diag is the 3rd output of uav_delivery_cost,
    % deterministic, identical to the original run; the old mat stored best_diag by mistake as a Z scalar)
    [~, ~, best_diag] = uav_delivery_cost(D.best_diag_X, env);
    ckpt = fullfile(outdir,'checkpoint.mat');
    t0 = tic;   % for elapsed statistics at the end of redraw
end

if ~redraw_mode
%% ==================== main run loop ====================
t0 = tic;
S = zeros(runs, nAlg);
Zall = cell(runs, nAlg);          % store each run's Z trajectory (best-so-far constraint cost Z = makespan+lateness)
BestX = cell(runs, nAlg);

% ---- resume from checkpoint: if interrupted last time, continue from the highest completed run (seed determinism guarantees identical results) ----
ckpt = fullfile(outdir,'checkpoint.mat');
if exist(ckpt,'file')
    load(ckpt, 'S','Zall','BestX','r_done');
    start_r = min(r_done + 1, runs);
    fprintf('RESUME: completed %d/%d runs, continuing from run %d\n', r_done, runs, start_r);
else
    start_r = 1;
end

for r = start_r:runs
    seed = 9000000 + r*1000;
    for a = 1:nAlg
        rng(seed);
        G_ZRUN = [];                 % reset this (run,algo)'s Z trajectory
        try
            switch algos{a}
                case 'iPWO'
                    [sc,sx,cg] = iPWO(pop,MaxFEs,env.lb,env.ub,D,fobj);
                case 'PWO'
                    [sc,sx,cg] = PWO_vec(pop,MaxFEs,env.lb,env.ub,D,fobj);
                case 'GWO'
                    [sc,sx,cg] = GWO(pop,MaxFEs,env.lb,env.ub,D,fobj);
                case 'PSO'
                    [sc,sx,cg] = PSO(pop,MaxFEs,env.lb,env.ub,D,fobj);
                case 'DE'
                    [sc,sx,cg] = DE(pop,MaxFEs,env.lb,env.ub,D,fobj);
                case 'MGO'
                    [sc,sx,cg] = MGO(pop,MaxFEs,env.lb,env.ub,D,fobj);
                case 'SFOA'
                    [sc,sx,cg] = SFOA(pop,MaxFEs,env.lb,env.ub,D,fobj);
            end
        catch ME
            fprintf('  [WARN] %s run %d failed: %s\n', algos{a}, r, ME.message);
            sc = Inf; sx = env.lb; cg = Inf;
        end
        % report constraint cost Z = makespan + lateness penalty (true optimization objective once time windows are active)
        if isinf(sc)
            S(r,a) = Inf;
        else
            [~, ~, d_best] = uav_delivery_cost(sx, env);
            S(r,a) = d_best.makespan + d_best.pen_tw;
        end
        BestX{r,a} = sx;
        % record this run's Z trajectory (best-so-far constraint cost), resampled to uniform length Lcurve
        G_ZRUN = G_ZRUN(:);
        if isempty(G_ZRUN) || all(isnan(G_ZRUN)) || isinf(sc)
            Zall{r,a} = nan(Lcurve,1);
        else
            Zall{r,a} = interp1((1:numel(G_ZRUN))', G_ZRUN, ...
                                linspace(1,numel(G_ZRUN),Lcurve)','linear','extrap');
        end
        % align the final value to the final-solution Z (same basis as Table 3), so the convergence plot's final value equals each algorithm's Mean and the ranking matches the table
        if isfinite(S(r,a)) && ~isnan(Zall{r,a}(end))
            Zall{r,a}(end) = S(r,a);
        end
    end
    fprintf('  run %2d / %d done  (best makespan so far = %.2f)\n', r, runs, min(S(r,:)));
    r_done = r;   % record the last completed run, for resume
    save(ckpt, 'S','Zall','BestX','r_done','env','algos','runs','pop','MaxFEs','start_r');
end

fprintf('Optimization done: %.1f s\n', toc(t0));

%% ==================== mean convergence curve (same metric Z as Table 3) ====================
Cmean = zeros(Lcurve, nAlg);
for a = 1:nAlg
    Zm = cat(2, Zall{:,a});                 % Lcurve x runs
    Cmean(:,a) = mean(Zm, 2, 'omitnan');    % mean across 51 runs
end

%% ==================== statistical analysis ====================
best  = min(S,[],1);
med   = median(S,1);
meanv = mean(S,1);
stdv  = std(S,0,1);
pv    = nan(1,nAlg);
for a=2:nAlg
    try, pv(a) = ranksum(S(:,1), S(:,a)); catch, pv(a) = NaN; end
end

ranks = zeros(runs,nAlg);
for r=1:runs
    [~,ord] = sort(S(r,:));
    ranks(r,ord) = 1:nAlg;
end
avgRank = mean(ranks,1);

fprintf('\n%-8s %-12s %-12s %-12s %-12s %-10s %-10s\n',...
    'Alg','Best','Median','Mean','Std','AvgRank','p_vs_iPWO');
for a=1:nAlg
    fprintf('%-8s %-12.4g %-12.4g %-12.4g %-12.4g %-10.3f %-10s\n',...
        algos{a},best(a),med(a),meanv(a),stdv(a),avgRank(a),pvstr(pv(a)));
end

%% ==================== find best solution (for spatial plot) ====================
[~,bi] = min(S(:,1));             % the iPWO run with the best result
best_diag_X = BestX{bi,1};
[~, ~, best_diag] = uav_delivery_cost(best_diag_X, env);

%% ==================== save data ====================
save(fullfile(outdir,'delivery_results.mat'),...
    'env','S','Cmean','Zall','algos','runs','pop','MaxFEs','best_diag','best_diag_X',...
    'best','med','meanv','stdv','avgRank','pv');

T = table(algo_colors(:,1), algo_colors(:,2), algo_colors(:,3), ...
          algos(:), best(:), med(:), meanv(:), stdv(:), avgRank(:), pv(:), ...
          'VariableNames', {'R','G','B','Algorithm','Best','Median','Mean','Std','AvgRank','p_vs_iPWO'});
writetable(T, fullfile(outdir,'comparison_table.csv'));
end   % ~redraw_mode

%% ==================== generate all figures (per-figure try-catch) ====================
fprintf('\nGenerating figures...\n');

fig_safe(@() fd_scene(env, best_diag.R, figsdir, uav_colors), 'fig1_scene');
fig_safe(@() fd_paths(env, best_diag, figsdir, uav_colors), 'fig2_paths');
fig_safe(@() fd_load(env, best_diag, figsdir, uav_colors), 'fig3_load');
fig_safe(@() save_conv_fig(Cmean, algos, algo_colors, Lcurve, figsdir, 'fig4_convergence.tif'), 'fig4_conv');
fig_safe(@() save_box_fig(S, algos, figsdir, 'fig5_boxplot.tif'), 'fig5_box');
fig_safe(@() fd_conflict(env, best_diag, figsdir, uav_colors), 'fig6_conflict');
fig_safe(@() fd_table(algos, best, med, meanv, stdv, avgRank, pv, figsdir), 'fig7_table');
fig_safe(@() fd_sensitivity(env, figsdir), 'fig8_sensitivity');
fig_safe(@() fd_gantt(env, best_diag, figsdir, uav_colors), 'fig9_gantt');

fprintf('All figures saved to: %s\n', figsdir);
fprintf('Data saved to:      %s\n', outdir);
if exist(ckpt,'file'), delete(ckpt); end   % clear resume checkpoint

%% ==================== export JSON (for strict Python preview reuse) ====================
try
    export_scene_json();
catch ME
    fprintf('  [WARN] export_scene_json failed: %s\n', ME.message);
end

fprintf('Total elapsed: %.1f s\n', toc(t0));
diary off;

%% ==================== subfunctions ====================

function uav_print(fig, fname, varargin)
% unified pre-export processing: if axis labels/title/colorbar overflow the fixed 11.5x8 canvas
% under the large font, detect the overflow via OuterPosition and retract the axes inward (leave
% untouched if no overflow), then print with the original parameters. All figure prints go through this.
    axs = findall(fig, 'type', 'axes');
    m = 0.012;                                 % required margin (normalized)
    for a = 1:numel(axs)
        ax = axs(a);
        for pass = 1:3
            op = ax.OuterPosition;
            p  = ax.Position;
            changed = false;
            if op(2) < m                     % bottom (x ticks/xlabel)
                s = m - op(2); p(2) = p(2) + s; p(4) = p(4) - s; changed = true;
            end
            if op(2) + op(4) > 1 - m         % top (title)
                s = op(2) + op(4) - (1 - m); p(4) = p(4) - s; changed = true;
            end
            if op(1) < m                     % left (y ticks/ylabel)
                s = m - op(1); p(1) = p(1) + s; p(3) = p(3) - s; changed = true;
            end
            if op(1) + op(3) > 1 - m         % right (colorbar/right edge)
                s = op(1) + op(3) - (1 - m); p(3) = p(3) - s; changed = true;
            end
            if ~changed, break; end
            ax.Position = p;
            drawnow;
        end
    end
    drawnow;
    % ---- font audit: enumerate every object with a FontName property, record non-TNR ones ----
    try
        global UAV_FONT_AUDIT
        hs = findall(fig);
        for ii = 1:numel(hs)
            try
                fn = hs(ii).FontName;
                if ~strcmpi(fn, 'Times New Roman')
                    tp = 'unknown';
                    try, tp = hs(ii).Type; catch, end
                    tg = '';
                    try, tg = hs(ii).Tag; catch, end
                    UAV_FONT_AUDIT{end+1,1} = sprintf('%s | type=%s tag=%s', fname, tp, tg); %#ok<AGROW>
                end
            catch
                % objects without a FontName property (lines/surfaces/patches etc.) are skipped
            end
        end
    catch
    end
    print(fig, fname, varargin{:});
end


function fig_safe(fn, name)
    try
        fn();
        fprintf('  [OK] %s\n', name);
    catch ME
        fprintf('  [FAIL] %s : %s\n', name, ME.message);
    end
end

function s = pvstr(p)
    if isnan(p), s = '-';
    elseif p < 1e-3, s = '<1e-3';
    else s = sprintf('%.3g', p); end
end

%% =====================================================================
%%                        local functions: figure generators
%% =====================================================================

function fd_scene(env, R, figsdir, cols)
% 3D delivery scenario plot (shows only the problem instance, no routes)
    fig = figure('Color','w','Position',[150 150 1150 800]);
    set(fig,'PaperUnits','inches','PaperSize',[11.5 8],'PaperPosition',[0 0 11.5 8],'PaperPositionMode','manual');
    ax = axes('Parent',fig); view(ax,3); hold(ax,'on'); grid(ax,'on'); box(ax,'on');

    draw_obs(ax,env);
    draw_wh(ax,env.depot);
    for u=1:env.Nu
        draw_pad(ax, env.pads(u,:), cols(u,:));
        draw_uav(ax, env.cruise_pts(u,:), cols(u,:), 3.2);
        % per request: scene plot does not draw delivery routes / climb lines
    end

    % precompute label offsets: push along the "away from nearest neighbor" direction to avoid dense customer-label overlap
    cof = zeros(env.Nc,2);
    for j=1:env.Nc
        cj = env.customers(j,1:2);
        push = [0 0];
        for k=1:env.Nc
            if k==j, continue; end
            d = norm(cj - env.customers(k,1:2));
            if d < 13                        % only push near neighbors
                dir = (cj - env.customers(k,1:2)) / max(d,1e-6);
                push = push + dir * (13 - d);
            end
        end
        nl = norm(push);
        if nl > 1e-6, push = push / nl * min(nl, 11); end   % clamp
        cof(j,:) = push;
    end

    % customer spheres: colored by assignment, no per-point text labels (avoids 30-label overlap becoming unreadable)
    for j=1:env.Nc
        r = 0.8 + 1.4*(env.weights(j)-0.5)/(3.0-0.5);
        c = cols(R.assign(j),:);
        draw_sph(ax,env.customers(j,:),r,c,0.95);
    end
    % launch-pad numbers (radially extruded to avoid 6 labels overlapping at center;
    % P1/P4/P6 are occluded by depot text/cube at the current view, so they are raised separately to offset)
    zlab = 10*ones(1,env.Nu); zlab(1)=20; zlab(4)=15; zlab(6)=6;  % P6 low to avoid occlusion by the top-right legend
    for u=1:env.Nu
        dirv = env.pads(u,1:2) - env.depot(1:2);
        dirv = dirv / max(norm(dirv), 1e-6);
        text(ax, env.pads(u,1)+dirv(1)*10, env.pads(u,2)+dirv(2)*10, zlab(u), ...
            sprintf('P%d',u), 'FontSize', 12, 'Color', cols(u,:), ...
            'HorizontalAlignment','center','FontWeight','bold');
    end
    % depot text
    text(ax, env.depot(1), env.depot(2), 15, 'Warehouse', ...
        'FontSize', 12, 'Color', [0.1 0.1 0.1], 'HorizontalAlignment','center', ...
        'FontWeight','bold', 'BackgroundColor',[1 1 1 0.7]);

    style_3d(ax);
    ttl = title(ax,sprintf('3D Delivery Scenario (Nu=%d UAVs, Nc=%d customers, Q=%.0f kg)',...
        env.Nu, env.Nc, env.Q),'FontSize', FS,'FontWeight','bold');
    ttl.Units = 'normalized';
    ttl.Position = [0.62, 1.0, 0];   % after the legend occupies the right of the axes, move the title center to the canvas middle
    legend_ax(ax,cols);

    % per request: remove the bottom-right top-down inset, so the 3D axes are not occluded;
    % assignment is conveyed by customer color coding + the top-right legend.

    uav_print(fig,fullfile(figsdir,'fig1_scene.tif'),'-dtiffn','-r330');
    close(fig);
end


function fd_paths(env, diag, figsdir, cols)
% best task assignment and path-planning plot (with UAV solid model and drop points)
    fig = figure('Color','w','Position',[150 150 1150 800]);
    set(fig,'PaperUnits','inches','PaperSize',[11.5 8],'PaperPosition',[0 0 11.5 8],'PaperPositionMode','manual');
    ax = axes('Parent',fig); view(ax,3); hold(ax,'on'); grid(ax,'on'); box(ax,'on');

    draw_obs(ax,env); draw_wh(ax,env.depot);
    for u=1:env.Nu
        draw_pad(ax, env.pads(u,:), cols(u,:));
        draw_uav(ax, env.cruise_pts(u,:), cols(u,:), 3.2);
        plot3(ax,[env.pads(u,1) env.cruise_pts(u,1)],[env.pads(u,2) env.cruise_pts(u,2)],...
              [env.pads(u,3) env.cruise_pts(u,3)],'-','Color',cols(u,:),'LineWidth',1.3,...
              'HandleVisibility','off');
    end

    for u=1:env.Nu
        nd = diag.R.routes{u};
        plot3(ax,nd(:,1),nd(:,2),nd(:,3),'-','Color',cols(u,:),'LineWidth',2.6,...
            'DisplayName',sprintf('UAV-%d (quadcopter)',u));
    end
    for j=1:env.Nc
        % ground delivery drop points (color proportional to owning UAV)
        scatter3(ax,env.customers(j,1),env.customers(j,2),env.customers(j,3),60,...
            'filled','MarkerFaceColor',cols(diag.R.assign(j),:),'MarkerEdgeColor','k',...
            'HandleVisibility','off');
        % thin dashed line from the cruise-hover point downward: hover at cruise altitude to deliver the package
        plot3(ax,[env.customers(j,1) env.customers(j,1)],[env.customers(j,2) env.customers(j,2)],...
              [env.customers(j,3) env.CRUISE],':','Color',[0.30 0.30 0.30],'LineWidth',1.0,...
              'HandleVisibility','off');
    end
    style_3d(ax);
    title(ax,sprintf('Optimal Task Assignment and 3D Paths\n(IPWO, Makespan=%.1fs)',...
        diag.makespan),'FontSize', FS,'FontWeight','bold');
    legend(ax,'show','Location','northwest','FontSize', FS);
    uav_print(fig,fullfile(figsdir,'fig2_paths.tif'),'-dtiffn','-r330');
    close(fig);
end


function fd_load(env, diag, figsdir, cols)
% per-UAV load-variation curve (verifies the capacity constraint)
    fig = figure('Color','w','Position',[150 150 1150 800]);
    set(fig,'PaperUnits','inches','PaperSize',[11.5 8],'PaperPosition',[0 0 11.5 8],'PaperPositionMode','manual');
    ax = axes('Parent',fig); hold(ax,'on'); grid(ax,'on');

    for u=1:env.Nu
        nodes = diag.R.routes{u};
        seq   = diag.R.cust_seq{u};
        seg   = diff(nodes,1,1);
        slen  = sqrt(sum(seg.^2,2));

        t = 0; load = diag.load0(u);
        t_arr = 0; l_arr = load;
        ci = 0;   % delivered-customer counter
        for i=1:size(nodes,1)-1
            t = t + slen(i)/env.V;
            t_arr(end+1) = t;                                   %#ok<AGROW>
            node = nodes(i+1,:);
            % decide whether we reached the "cruise-hover delivery point above a customer": z~CRUISE and xy matches a customer
            isCust = false;
            for jj=1:env.Nc
                if abs(node(3)-env.CRUISE)<0.6 && norm(node(1:2)-env.customers(jj,1:2))<0.6
                    isCust = true; break;
                end
            end
            if isCust
                ci = ci + 1;
                if ci <= numel(seq)
                    t = t + env.TS;                             % add service time
                    load = load - env.weights(seq(ci));         % subtract this package's weight
                end
            end
            l_arr(end+1) = load;                               %#ok<AGROW>
        end

        stairs(ax,t_arr,l_arr,'LineWidth',2.6,'Color',cols(u,:),...
            'DisplayName',sprintf('UAV-%d (init %.1f kg)',u,l_arr(1)));
        plot(ax,t_arr,l_arr,'o','Color',cols(u,:),'MarkerSize',5,'HandleVisibility','off');
    end
    plot(ax, xlim(ax), [env.Q env.Q], '--', 'Color', [0.84 0.15 0.15], 'LineWidth', 2.0, ...
        'DisplayName', sprintf('Capacity limit Q=%.0f kg', env.Q));
    xlabel(ax,'Time  t (s)','FontSize', FS); ylabel(ax,'Remaining load  W_i(t) (kg)','FontSize', FS);
    title(ax,'Load Variation per UAV (capacity constraint satisfied)',...
        'FontSize', FS,'FontWeight','bold');
    ylim(ax,[0 env.Q+2]); legend(ax,'show','Location','northeast','FontSize', FS);
    set(ax,'FontSize', FS,'LineWidth',1.4);
    uav_print(fig,fullfile(figsdir,'fig3_load.tif'),'-dtiffn','-r330');
    close(fig);
end


function fd_conflict(env, diag, figsdir, cols)
% airspace conflict-detection snapshot
    fig = figure('Color','w','Position',[150 150 1150 800]);
    set(fig,'PaperUnits','inches','PaperSize',[11.5 8],'PaperPosition',[0 0 11.5 8],'PaperPositionMode','manual');
    ax = axes('Parent',fig); view(ax,3); hold(ax,'on'); grid(ax,'on'); box(ax,'on');

    draw_obs(ax,env); draw_wh(ax,env.depot);
    for u=1:env.Nu, draw_pad(ax, env.pads(u,:), cols(u,:)); end

    K = 120; f_snap = 0.5;
    Pt = cell(env.Nu,1);
    for u=1:env.Nu, Pt{u} = resample_route(diag.R.routes{u}, K); end
    idx = round(K*f_snap);
    pos_u = zeros(env.Nu,3);
    for u=1:env.Nu, pos_u(u,:) = Pt{u}(idx,:); end

    viol = 0;
    for u=1:env.Nu
        draw_sph(ax,pos_u(u,:),env.dmin,cols(u,:),0.12);
        draw_uav(ax, pos_u(u,:), cols(u,:), 3.2);
    end
    for i=1:env.Nu
        for j=(i+1):env.Nu
            d = norm(pos_u(i,:)-pos_u(j,:));
            safe = d >= env.dmin;
            viol = viol + (~safe);
            if safe, colc = '#2ca02c'; sym = '>=';
            else,     colc = '#d62728'; sym = '<'; end
            plot3(ax,[pos_u(i,1),pos_u(j,1)],[pos_u(i,2),pos_u(j,2)],[pos_u(i,3),pos_u(j,3)],...
                '-','Color',colc,'LineWidth',1.8);
            mid = (pos_u(i,:)+pos_u(j,:))/2;
            % push labels along the "away from scene center" direction, with different distances per pair to avoid overlap
            vout = mid(1:2) - [50 50];
            if norm(vout) < 1e-6, vout = [-1 1]; end
            vout = vout / norm(vout);
            push = 7 + 4*((i-1)+(j-i-1));
            off_x = vout(1) * push;
            off_y = vout(2) * push;
            tag = sprintf('%.1f m %s %d m', d, sym, env.dmin);
            ht = text(ax, mid(1)+off_x, mid(2)+off_y, mid(3)+5.0, tag, ...
                'FontSize', FS, 'Color', colc, 'HorizontalAlignment', 'center', ...
                'EdgeColor', 'w', 'LineWidth', 3);
        end
    end
    style_3d(ax);
    title(ax,sprintf('Airspace Conflict Check (snapshot t=T/2, %d violating pair)',viol),...
        'FontSize', FS,'FontWeight','bold');
    h1 = plot(nan,nan,'o','MarkerFaceColor','#2ca02c','MarkerEdgeColor','k'); h1.HandleVisibility='off';
    h2 = plot(nan,nan,'o','MarkerFaceColor','#d62728','MarkerEdgeColor','k'); h2.HandleVisibility='off';
    legend(ax,[h1,h2],{'safe pair','violating pair'},'Location','nw','FontSize', FS);
    uav_print(fig,fullfile(figsdir,'fig6_conflict.tif'),'-dtiffn','-r330');
    close(fig);
end


function fd_table(algos,best,med,meanv,stdv,avgRank,pv,figsdir)
% comparison table (rendered as an image, hand-drawn for reliability)
    nA = numel(algos); nR = 6;
    rownames = {'Best','Median','Mean','Std','AvgRank','p vs iPWO'};
    data = [best; med; meanv; stdv; avgRank; pv];
    fmt  = {'%.4g','%.4g','%.4g','%.4g','%.3f','%s'};

    fig = figure('Color','w','Position',[150 150 1150 800]);
    set(fig,'PaperUnits','inches','PaperSize',[11.5 8],'PaperPosition',[0 0 11.5 8],'PaperPositionMode','manual');
    ax = axes('Parent',fig,'Position',[0 0 1 1]); axis(ax,'off');
    xlim(ax,[0 1]); ylim(ax,[0 1]);

    left=0.12; right=0.99; top=0.86; bottom=0.06;
    cw = (right-left)/nA; rh = (top-bottom)/(nR+1);  % +1 header row

    for rr=1:(nR+1)
        yb = top - rr*rh;
        for a=1:nA
            x = left + (a-1)*cw;
            if rr==1
                face = [0.90 0.90 0.95];                 % header
                if a==1, face = [1 0.85 0.85]; end        % highlight iPWO column
            else
                face = [1 1 1];
                if a==1, face = [1 0.92 0.92]; end
            end
            rectangle(ax,'Position',[x yb cw rh],'EdgeColor',[0.6 0.6 0.6],'FaceColor',face,'LineWidth',1.2);
        end
    end
    for a=1:nA
        xc = left + (a-0.5)*cw;
        text(ax,xc, top-0.5*rh, algos{a},'FontSize', FS,'FontWeight','bold',...
            'HorizontalAlignment','center','VerticalAlignment','middle');
    end
    for rr=1:nR
        yb = top - (rr+1)*rh;
        text(ax, left-0.02, yb+0.5*rh, rownames{rr},'FontSize', FS,...
            'HorizontalAlignment','right','VerticalAlignment','middle');
        for a=1:nA
            xc = left + (a-0.5)*cw;
            if rr==6, str = pvstr(data(rr,a)); else str = sprintf(fmt{rr}, data(rr,a)); end
            text(ax,xc, yb+0.5*rh, str,'FontSize', FS,...
                'HorizontalAlignment','center','VerticalAlignment','middle');
        end
    end
    text(ax,0.5,0.965,'Algorithm Performance Comparison Table',...
        'FontSize', FS,'FontWeight','bold','HorizontalAlignment','center');
    uav_print(fig,fullfile(figsdir,'fig7_comparison_table.tif'),'-dtiffn','-r330');
    close(fig);
end


function fd_sensitivity(env, figsdir)
% sensitivity analysis (#UAV and d_min variation vs Makespan) -- actually run iPWO
    NU = 5; PB = 20; MF = 2000;          % run NU times per config, take mean +/- std
    nuavs = [3,4,5,6];
    dmins = [2,4,6,8];

    mu = zeros(size(nuavs)); su = zeros(size(nuavs));
    for ti=1:numel(nuavs)
        e2 = uav_delivery_env(nuavs(ti), env.dmin);
        vals = zeros(NU,1);
        for rr=1:NU
            rng(2000+rr);
            [sc,sx] = iPWO(PB,MF,e2.lb,e2.ub,e2.D,@(X)uav_delivery_cost(X,e2));
            [~, ~, dd] = uav_delivery_cost(sx, e2);
            vals(rr) = dd.makespan;
        end
        mu(ti) = mean(vals); su(ti) = std(vals);
    end

    md = zeros(size(dmins)); sd = zeros(size(dmins));
    for ti=1:numel(dmins)
        e2 = uav_delivery_env(env.Nu, dmins(ti));
        vals = zeros(NU,1);
        for rr=1:NU
            rng(3000+rr);
            [sc,sx] = iPWO(PB,MF,e2.lb,e2.ub,e2.D,@(X)uav_delivery_cost(X,e2));
            [~, ~, dd] = uav_delivery_cost(sx, e2);
            vals(rr) = dd.makespan;
        end
        md(ti) = mean(vals); sd(ti) = std(vals);
    end

    fig = figure('Color','w','Position',[150 150 1150 800]);
    set(fig,'PaperUnits','inches','PaperSize',[11.5 8],'PaperPosition',[0 0 11.5 8],'PaperPositionMode','manual');
    subplot(1,2,1); hold on; grid on;
    errorbar(nuavs,mu,su,'-o','LineWidth',2.0,'MarkerSize',9,'MarkerFaceColor','b');
    xlabel('# UAVs (Nu)','FontSize', FS); ylabel('Makespan (s)','FontSize', FS);
    title(sprintf('(a) Makespan vs # UAVs\nd_min = %d m',env.dmin),'FontSize', FS);
    set(gca,'FontSize', FS,'LineWidth',1.4,'TickLabelInterpreter','none');
    set(gca,'Position',[0.13 0.09 0.36 0.66]);   % top whitespace for sgtitle, avoid overlap

    subplot(1,2,2); hold on; grid on;
    errorbar(dmins,md,sd,'-s','LineWidth',2.0,'MarkerSize',9,'MarkerFaceColor','r');
    xlabel('Safety distance d_min (m)','FontSize', FS); ylabel('Makespan (s)','FontSize', FS);
    title(sprintf('(b) Makespan vs d_min\nNu = %d',env.Nu),'FontSize', FS);
    set(gca,'FontSize', FS,'LineWidth',1.4,'TickLabelInterpreter','none');
    set(gca,'Position',[0.57 0.09 0.36 0.66]);   % top whitespace for sgtitle, avoid overlap

    sgtitle('Sensitivity Analysis (IPWO best over 5 runs)','FontSize', FS*0.8,'FontWeight','bold');
    uav_print(fig,fullfile(figsdir,'fig8_sensitivity.tif'),'-dtiffn','-r330');
    close(fig);
end


function fd_gantt(env, diag, figsdir, cols)
% time-window feasibility Gantt: each UAV's customer service interval vs its own time window
    fig = figure('Color','w','Position',[150 150 1150 800]);
    set(fig,'PaperUnits','inches','PaperSize',[11.5 8],'PaperPosition',[0 0 11.5 8],'PaperPositionMode','manual');
    ax = axes('Parent',fig); hold(ax,'on'); grid(ax,'on'); box(ax,'on');

    maxT = 1;
    for u = 1:env.Nu
        seq = diag.R.cust_seq{u};
        arr = diag.arr{u};
        if isempty(seq), continue; end
        yy = (env.Nu - u);                 % row: UAV-1 on top
        for k = 1:numel(seq)
            j = seq(k);
            e = env.tw(j,1); l = env.tw(j,2);
            a = arr(k);
            % time-window background
            rectangle(ax,'Position',[e, yy-0.35, (l-e), 0.7],...
                'FaceColor',[0.86 0.91 0.96],'EdgeColor','none');
            % service bar [a, a+TS]
            rectangle(ax,'Position',[a, yy-0.30, env.TS, 0.60],...
                'FaceColor',cols(u,:),'EdgeColor',[0.15 0.15 0.15],'LineWidth',1);
            maxT = max(maxT, a + env.TS);
        end
    end
    xlabel(ax,'Time  t (s)','FontSize', FS);
    ylabel(ax,'UAV index','FontSize', FS);
    yt = 0:(env.Nu-1);                     % must be increasing (R2024a disallows non-monotonic ticks)
    set(ax,'YTick',yt,'YTickLabel',arrayfun(@(x)sprintf('UAV-%d',env.Nu-x),yt,'UniformOutput',false));
    xlim(ax,[0 max(maxT,1)*1.05]);
    title(ax,'Time-Window Feasibility Gantt (best IPWO solution)',...
        'FontSize', FS,'FontWeight','bold');
    set(ax,'FontSize', FS,'LineWidth',1.4,'TickLabelInterpreter','none');
    uav_print(fig,fullfile(figsdir,'fig9_gantt.tif'),'-dtiffn','-r330');
    close(fig);
end


function save_conv_fig(C, algos, colors, Lcurve, figsdir, fname)
% mean convergence curve: mean across 51 runs (same metric Z = makespan + time-window lateness as Table 3)
    fig = figure('Color','w','Position',[150 150 1150 800]);
    set(fig,'PaperUnits','inches','PaperSize',[11.5 8],'PaperPosition',[0 0 11.5 8],'PaperPositionMode','manual');
    ax = axes('Parent',fig); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    for a=1:size(C,2)
        y = C(:,a); y(y<=0) = eps;
        lw = 1.8; if a==1, lw = 3.2; end
        semilogx(ax,1:Lcurve,y,'-','LineWidth',lw,'Color',colors(a,:),'DisplayName',algos{a});
    end
    xlabel(ax,'Iteration','FontSize', FS);
    ylabel(ax,'Mean constrained cost Z','FontSize', FS);
    legend(ax,'show','Location','northeast','FontSize', FS);
    title(ax,'Mean Convergence Curves (51 runs, lower is better)','FontSize', FS,'FontWeight','bold');
    text(ax, 0.02, 0.97, {'Metric Z = makespan + lateness (same as Table 3).'; 'Curves = mean of best-Z found over 51 runs.'}, ...
        'Units','normalized','FontSize', FS,'Color',[0.3 0.3 0.3], ...
        'VerticalAlign','top','EdgeColor','w','LineWidth',2);
    set(ax,'FontSize', FS,'LineWidth',1.4,'TickLabelInterpreter','none');
    uav_print(fig,fullfile(figsdir,fname),'-dtiffn','-r330');
    close(fig);
end


function save_box_fig(S, algos, figsdir, fname)
% boxplot (gradient colors + iPWO bold red, large-font legend)
    fig = figure('Color','w','Position',[150 150 1150 800]);
    set(fig,'PaperUnits','inches','PaperSize',[11.5 8],'PaperPosition',[0 0 11.5 8],'PaperPositionMode','manual');
    ax = axes('Parent',fig); hold(ax,'on');

    nAlg = numel(algos);
    redCol = [0.90 0.15 0.20];
    boxColors = zeros(nAlg,3);
    boxColors(1,:) = redCol;
    % cool-color gradient (iPWO already red); SFOA uses emerald to avoid confusion with red; no red component overall
    coolPalette = [
        0.15  0.75  0.70   % 2: PWO   teal
        0.10  0.62  0.82   % 3: GWO   cyan
        0.18  0.48  0.80   % 4: PSO   azure
        0.28  0.38  0.76   % 5: DE    royal blue
        0.40  0.30  0.70   % 6: MGO   indigo
        0.00  0.72  0.55   % 7: SFOA  emerald green (clearly non-red)
    ];
    for i = 2:nAlg
        if i-1 <= size(coolPalette,1)
            boxColors(i,:) = coolPalette(i-1,:);
        else
            t = (i-2)/max(nAlg-2,1);
            boxColors(i,:) = coolPalette(end,:) * (1-t) + [0.5 0.1 0.3] * t;
        end
    end

    boxplot(ax, S, 'Labels', algos, 'Widths', 0.6, ...
            'Colors', boxColors, 'Symbol', 'o', 'OutlierSize', 6, 'Whisker', 1.5);

    boxLines = findobj(ax, 'Tag', 'Box');
    meds     = findobj(ax, 'Tag', 'Median');

    % key fix: boxplot Box child order is right-to-left (last column -> first column)
    % must determine each box's column (algorithm) via the x-center of its XData
    nBox = min(nAlg, numel(boxLines));
    box_xcenter = zeros(nBox, 1);
    for i = 1:nBox
        xd = boxLines(i).XData;
        box_xcenter(i) = (min(xd) + max(xd)) / 2;
    end
    [~, sort_idx] = sort(box_xcenter);   % sort_idx(i)=original index -> rank i (left to right)
    color_map = zeros(nBox, 3);
    for i = 1:nBox
        color_map(sort_idx(i), :) = boxColors(i, :);
    end

    Ng = 12;
    for i = 1:nBox
        xd = boxLines(i).XData; yd = boxLines(i).YData;
        xL = min(xd); xR = max(xd); q1 = min(yd); q3 = max(yd);
        ly1 = log(q1); ly3 = log(q3);
        c_use = color_map(i, :);               % this box's correct color
        for g = 0:Ng-1
            ya = exp(ly1 + (ly3-ly1)*g/Ng);
            yb = exp(ly1 + (ly3-ly1)*(g+1)/Ng);
            shade = 1.0 - 0.40*(g/(Ng-1));
            ph = patch(ax, [xL xR xR xL], [ya ya yb yb], c_use*shade, ...
                       'FaceAlpha', 0.9, 'EdgeColor', 'none');
            uistack(ph, 'bottom');
        end
        if sort_idx(i) == 1   % first column (leftmost) = iPWO -> bold red edge
            set(boxLines(i), 'Color', [0.55 0.05 0.08], 'LineWidth', 2.6);
        else
            set(boxLines(i), 'Color', c_use*0.5, 'LineWidth', 1.5);
        end
        uistack(boxLines(i), 'top');
    end
    for i = 1:min(nAlg, numel(meds))
        set(meds(i), 'Color', [0.08 0.08 0.08], 'LineWidth', 2.2);
    end
    wl = [findobj(ax,'Tag','Upper Whisker'); findobj(ax,'Tag','Lower Whisker'); ...
          findobj(ax,'Tag','Upper Adjacent Value'); findobj(ax,'Tag','Lower Adjacent Value')];
    for k = 1:numel(wl), set(wl(k), 'Color', [0.30 0.30 0.30], 'LineWidth', 1.4); end

    set(ax,'YScale','log'); grid(ax,'on');
    ylabel(ax,'Makespan  Z  (s)','FontSize', FS);
    xlabel(ax,'Algorithm','FontSize', FS);
    title(ax,'Makespan Distribution over Runs (log scale)',...
        'FontSize', FS,'FontWeight','bold');
    set(ax,'FontSize', FS,'LineWidth',1.4,'TickLabelInterpreter','none');

    % per request: remove the top-left legend (red iPWO / blue baseline group note).
    % color meaning is now explained in the caption; no legend block above the plot area.

    uav_print(fig, fullfile(figsdir, fname), '-dtiffn', '-r330');
    close(fig);
end


%% ==================== 3D plotting helpers ====================

function style_3d(ax)
    xlabel(ax,'x (m)','FontSize', FS); ylabel(ax,'y (m)','FontSize', FS); zlabel(ax,'z (m)','FontSize', FS);
    xlim(ax,[0 100]); ylim(ax,[0 100]); zlim(ax,[0 60]);
    ax.DataAspectRatio = [1 1 0.6];
    view(ax,-60,25);
    set(ax,'FontSize', FS,'LineWidth',1.4);
end


function draw_obs(ax,env)
    for o=1:size(env.cyl,1)
        c = env.cyl(o,:);
        [Xc,Yc,Zc] = cylinder(c(3),40); Zc = Zc*c(4);
        surf(ax,Xc+c(1),Yc+c(2),Zc,'FaceColor',[0.5 0.5 0.5],'FaceAlpha',0.35,...
            'EdgeColor','none','HandleVisibility','off');
    end
    for o=1:size(env.sph,1)
        c = env.sph(o,:);
        [Xs,Ys,Zs] = sphere(20);
        surf(ax,Xs*c(4)+c(1),Ys*c(4)+c(2),Zs*c(4)+c(3),...
            'FaceColor',[0.5 0.5 0.5],'FaceAlpha',0.35,...
            'EdgeColor','none','HandleVisibility','off');
    end
end


function draw_wh(ax,d)
% depot: semi-transparent cube
    x0 = d(1)-5; y0 = d(2)-5; w = 10; h = 12;
    verts = [x0 y0 0; x0+w y0 0; x0 y0+w 0; x0+w y0+w 0;
             x0 y0 h; x0+w y0 h; x0 y0+w h; x0+w y0+w h];
    faces = [1 2 4 3; 5 6 8 7; 1 2 6 5; 3 4 8 7; 1 3 7 5; 2 4 8 6];
    patch('Vertices',verts,'Faces',faces,'FaceColor',[0.42 0.36 0.80],...
        'FaceAlpha',0.9,'EdgeColor','w','LineWidth',1,'HandleVisibility','off');
end


function draw_pad(ax,p,col)
% launch pad: small ground platform (matching UAV colors)
    s = 3.5;
    verts = [p(1)-s p(2)-s 0; p(1)+s p(2)-s 0; p(1)+s p(2)+s 0; p(1)-s p(2)+s 0; ...
             p(1)-s p(2)-s 0.5; p(1)+s p(2)-s 0.5; p(1)+s p(2)+s 0.5; p(1)-s p(2)+s 0.5];
    faces = [1 2 4 3; 5 6 8 7; 1 2 6 5; 3 4 8 7; 1 3 7 5; 2 4 8 6];
    patch('Vertices',verts,'Faces',faces,'FaceColor',col,'FaceAlpha',0.9,...
        'EdgeColor','k','LineWidth',1.2,'HandleVisibility','off');
end


function draw_uav(ax, p, col, s)
% simplified quadcopter UAV solid model (top-down silhouette, placed horizontally at position p)
%   p: 3x1 body-center coordinates; col: color; s: arm length (m)
    arm   = s;          % arm length
    rotor = s*0.55;     % rotor radius
    dirs  = [1 1; 1 -1; -1 1; -1 -1]/sqrt(2);
    tips  = p(1:2)' + arm*dirs';                 % 4 arm endpoints (2x4)
    % body center
    scatter3(ax, p(1), p(2), p(3), 160, 'filled', 'MarkerFaceColor', col, ...
        'MarkerEdgeColor', 'k', 'LineWidth', 1.4, 'HandleVisibility', 'off');
    for k=1:4
        % arm
        plot3(ax, [p(1) tips(1,k)], [p(2) tips(2,k)], [p(3) p(3)], '-', ...
            'Color', col, 'LineWidth', 2.6, 'HandleVisibility', 'off');
        % rotor ring
        t = linspace(0,2*pi,26);
        rx = tips(1,k) + rotor*cos(t);
        ry = tips(2,k) + rotor*sin(t);
        rz = p(3)*ones(size(t));
        plot3(ax, rx, ry, rz, '-', 'Color', col, 'LineWidth', 1.8, 'HandleVisibility', 'off');
        % rotor hub
        scatter3(ax, tips(1,k), tips(2,k), p(3), 50, 'filled', 'MarkerFaceColor', col, ...
            'MarkerEdgeColor', 'k', 'HandleVisibility', 'off');
    end
end


function draw_sph(ax,c,r,col,alpha)
    [xs,ys,zs] = sphere(24);
    surf(ax,xs*r+c(1),ys*r+c(2),zs*r+c(3),...
        'FaceColor',col,'FaceAlpha',alpha,'EdgeColor','none');
end


function legend_ax(ax,cols)
% legend placed outside-right of the 3D axes (does not occlude the model), markers enlarged to 300 for visibility
    h0 = scatter3(ax,nan,nan,nan,300,'s','filled',...
        'MarkerFaceColor',[0.42 0.36 0.80],'MarkerEdgeColor','w');
    h0.DisplayName = 'Warehouse';
    hh = gobjects(1,0);
    for u=1:size(cols,1)
        hu = scatter3(ax,nan,nan,nan,300,'o','filled',...
            'MarkerFaceColor',cols(u,:),'MarkerEdgeColor','k');
        hu.DisplayName = sprintf('UAV-%d',u);
        hh(end+1) = hu; %#ok<AGROW>
    end
    ho = scatter3(ax,nan,nan,nan,300,'o','filled',...
        'MarkerFaceColor',[0.5 0.5 0.5],'MarkerEdgeColor','k');
    ho.DisplayName = 'Obstacle';
    hcu = scatter3(ax,nan,nan,nan,300,'o','filled',...
        'MarkerFaceColor','w','MarkerEdgeColor','k','LineWidth',1.2);
    hcu.DisplayName = 'Customer';
    hp = scatter3(ax,nan,nan,nan,300,'s','filled',...
        'MarkerFaceColor',[0.6 0.6 0.6],'MarkerEdgeColor','k');
    hp.DisplayName = 'Launch pad';
    legend(ax,[h0,hh,ho,hcu,hp],'Location','eastoutside','FontSize', FS);
end


function Pt = resample_route(nodes, K)
% resample trajectory to K points by equal arc length (guard against degenerate/duplicate nodes)
    if size(nodes,1) < 2
        Pt = repmat(nodes(1,:), K, 1); return;
    end
    keep = [true; any(diff(nodes,1,1) ~= 0, 2)];
    nodes = nodes(keep,:);
    if size(nodes,1) < 2
        Pt = repmat(nodes(1,:), K, 1); return;
    end
    seg = diff(nodes,1,1);
    sl = sqrt(sum(seg.^2,2));
    cum = [0; cumsum(sl)];
    ts = linspace(0, cum(end), K)';
    Pt = [interp1(cum, nodes(:,1), ts), ...
          interp1(cum, nodes(:,2), ts), ...
          interp1(cum, nodes(:,3), ts)];
end
end

% ---------- Z-trace wrapper for convergence plot ----------
% the optimizer minimizes the penalized objective f through this handle; meanwhile each evaluation's
% best-so-far constraint cost Z is written into the global G_ZRUN (mean convergence plot; same metric as Table 3).
function y = fobj_z(x, env)
    global G_ZRUN
    [y, Z] = uav_delivery_cost(x, env);
    zmin = min(Z);
    if isempty(G_ZRUN)
        G_ZRUN = zmin;
    else
        G_ZRUN(end+1) = min(G_ZRUN(end), zmin);
    end
end
