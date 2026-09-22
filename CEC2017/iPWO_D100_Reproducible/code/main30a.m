clc;
clear;
close all;

%% ==================== parameter setup ====================
nPop = 30;            % population size
dim = 100;            % dimension
run_max = 30;         % number of repeated runs
alg_name = 'iPWO';
funcs = [1, 3:30];    % 29 functions (skip F2)

% results save folder
results_folder = 'CEC2017_tu';
if ~exist(results_folder, 'dir')
    mkdir(results_folder);
end

for fi = 1:numel(funcs)
    Function_name = funcs(fi);

    % CEC2017 standard budget
    MaxFEs = 10000 * dim;
    Max_iter = ceil(MaxFEs / nPop);
    Lcurve = Max_iter;

    % get benchmark function
    try
        [lb, ub, dim, fobj] = Get_Functions_cec2017(Function_name, dim);
        fprintf(' loaded benchmark function F%d, dim=%d\n', Function_name, dim);
    catch ME
        error(' cannot load benchmark function: %s', ME.message);
    end

%% ==================== data preallocation ====================
Lcurve = Max_iter;
sum_best_curve = zeros(Lcurve, 1);
sum_avg_fit_curve = zeros(Lcurve, 1);
success_runs = 0;
sum_time = 0;

best_run.score = inf;
best_run.pos = [];
best_run.curve = [];
best_run.history = [];
best_run.time = inf;

%% ==================== main loop: multiple runs ====================
h = waitbar(0, 'Running iPWO...');
for run = 1:run_max
    fprintf('\n============== Run %d / %d ==============\n', run, run_max);
    waitbar(run / run_max, h, sprintf('progress: %d / %d', run, run_max));

    try
        t_start = tic;

        best_score = [];
        best_pos = [];
        curve = [];
        history = [];

        % only call the version with history
        [best_score, best_pos, curve, history] = iPWO_history(nPop, MaxFEs, lb, ub, dim, fobj);

        elapsed = toc(t_start);

        % ----------- safety check: best_score -----------
        if isempty(best_score) || ~isscalar(best_score) || ~isfinite(best_score)
            warning('iPWO run %d returned invalid best_score, using large value instead', run);
            best_score = 1e10;
        end

        % ----------- safety check: curve -----------
        curve = curve(:);
        if isempty(curve)
            curve = best_score * ones(Lcurve, 1);
        end
        if length(curve) < Lcurve
            curve = [curve; repmat(curve(end), Lcurve - length(curve), 1)];
        elseif length(curve) > Lcurve
            curve = curve(1:Lcurve);
        end

        % ----------- extract average fitness curve -----------
        avg_fit_curve_single = extractAverageFitness(history, curve, Lcurve);

        % ----------- accumulate -----------
        sum_best_curve = sum_best_curve + curve;
        sum_avg_fit_curve = sum_avg_fit_curve + avg_fit_curve_single;
        success_runs = success_runs + 1;
        sum_time = sum_time + elapsed;

        % ----------- record best single run -----------
        if best_score < best_run.score
            best_run.score = best_score;
            best_run.pos = best_pos;
            best_run.curve = curve;
            best_run.history = history;
            best_run.time = elapsed;
        end

        fprintf('   iPWO: Best = %.6e | Time = %.4fs\n', best_score, elapsed);

    catch ME
        warning(' iPWO failed on run %d: %s', run, ME.message);
    end
end
close(h);

if success_runs == 0
    error('all runs failed, check the iPWO / CEC2017 function interface.');
end

%% ==================== average curves ====================
avg_best_curve = sum_best_curve / success_runs;
avg_fit_curve = sum_avg_fit_curve / success_runs;
avg_time = sum_time / success_runs;

fprintf('\n=== iPWO statistics (CEC2017 F%d, Dim=%d) ===\n', Function_name, dim);
fprintf('successful runs: %d / %d\n', success_runs, run_max);
fprintf('average runtime: %.6f s\n', avg_time);
fprintf('best single run best objective: %.6e\n', best_run.score);

%% ==================== generate TIFF five-panel + reproduction data (330DPI / 18pt / unified crop) ====================
figOpts.dpi = 330;
figOpts.fontSize = 18;
figOpts.alg_name = alg_name;
figOpts.landscapeCacheDir = fullfile(results_folder, 'landscape_cache');
figOpts.reproDataDir = fullfile(results_folder, 'repro_data');
iPWO_build_figures(Function_name, dim, lb, ub, fobj, best_run, ...
    avg_best_curve, avg_fit_curve, Lcurve, results_folder, figOpts);

%% ==================== save numeric results ====================
results.alg_name = alg_name;
results.Function_name = Function_name;
results.dim = dim;
results.nPop = nPop;
results.Max_iter = Max_iter;
results.MaxFEs = MaxFEs;
results.run_max = run_max;
results.success_runs = success_runs;
results.avg_time = avg_time;
results.avg_best_curve = avg_best_curve;
results.avg_fit_curve = avg_fit_curve;
results.best_run = best_run;

matFile = fullfile(results_folder, sprintf('CEC2017_F%d_Dim%d_iPWO_Results.mat', Function_name, dim));
save(matFile, 'results');
fprintf(' results saved to: %s\n', matFile);

fprintf('\n all figures saved to folder: %s\n', results_folder);
    close all;
end

% unify crop size of five-panel figure and sub-panels (pad white border, keep 330 DPI)
if exist('unifyTiffSizes', 'file')
    fprintf('\n--- unify image sizes ---\n');
    unifyTiffSizes(results_folder);
end

%% ==================== local functions ====================

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

function avg_fit_curve = extractAverageFitness(history, curve, Lcurve)
    avg_fit_curve = curve(:);

    if numel(avg_fit_curve) < Lcurve
        avg_fit_curve = [avg_fit_curve; repmat(avg_fit_curve(end), Lcurve - numel(avg_fit_curve), 1)];
    elseif numel(avg_fit_curve) > Lcurve
        avg_fit_curve = avg_fit_curve(1:Lcurve);
    end

    if isempty(history) || ~isstruct(history) || ~isfield(history, 'popFit') || isempty(history.popFit)
        return;
    end

    try
        popFit = history.popFit;

        if iscell(popFit)
            T = numel(popFit);
            tmp = nan(T,1);
            for t = 1:T
                ft = popFit{t};
                if isempty(ft)
                    tmp(t) = NaN;
                else
                    tmp(t) = mean(ft(:), 'omitnan');
                end
            end
            avg_fit_curve = fixCurveLength(tmp, Lcurve);

        elseif isnumeric(popFit)
            sz = size(popFit);

            if numel(sz) == 2 && sz(2) >= 2
                tmp = mean(popFit, 1, 'omitnan')';
                avg_fit_curve = fixCurveLength(tmp, Lcurve);

            elseif numel(sz) == 3 && sz(3) >= 2
                T = sz(3);
                tmp = nan(T,1);
                for t = 1:T
                    ft = popFit(:,:,t);
                    tmp(t) = mean(ft(:), 'omitnan');
                end
                avg_fit_curve = fixCurveLength(tmp, Lcurve);
            end
        end
    catch
    end
end

function out = fixCurveLength(in, Lcurve)
    in = in(:);
    if isempty(in)
        out = nan(Lcurve,1);
        return;
    end
    if numel(in) < Lcurve
        out = [in; repmat(in(end), Lcurve - numel(in), 1)];
    elseif numel(in) > Lcurve
        out = in(1:Lcurve);
    else
        out = in;
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

function saveCurrentFigure(figHandle, filePath)
    drawnow;
    if ~isgraphics(figHandle, 'figure')
        warning('invalid figure handle, cannot save: %s', filePath);
        return;
    end
    try
        exportgraphics(figHandle, filePath, 'Resolution', 300);
    catch
        saveas(figHandle, filePath);
    end
end

function saveCurrentAxes(axHandle, filePath)
    drawnow;
    if ~isgraphics(axHandle, 'axes')
        warning('invalid axes handle, cannot save: %s', filePath);
        return;
    end

    % prefer saving axes directly, avoid copyobj copying invalid handles
    try
        exportgraphics(axHandle, filePath, 'Resolution', 300);
        return;
    catch
    end

    % fallback: copy graphics to a new figure
    try
        figTemp = figure('Visible', 'off', 'Color', 'w');
        axNew = axes('Parent', figTemp); %#ok<LAXES>
        copyobj(allchild(axHandle), axNew);

        set(axNew, 'XLim', axHandle.XLim, 'YLim', axHandle.YLim, ...
            'XScale', axHandle.XScale, 'YScale', axHandle.YScale, ...
            'Box', axHandle.Box, 'XGrid', axHandle.XGrid, 'YGrid', axHandle.YGrid);

        xlabel(axNew, axHandle.XLabel.String);
        ylabel(axNew, axHandle.YLabel.String);
        title(axNew, axHandle.Title.String);

        if ~isempty(axHandle.Children)
            legend(axNew, 'show');
        end

        try
            exportgraphics(figTemp, filePath, 'Resolution', 300);
        catch
            saveas(figTemp, filePath);
        end
        close(figTemp);
    catch ME
        warning('failed to save sub-panel: %s');
    end
end
