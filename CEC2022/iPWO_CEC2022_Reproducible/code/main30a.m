clc;
clear;
close all;

%% ==================== parameter setup ====================
nPop = 30;            % population size
dims = [10, 20];      % CEC2022 official test dimensions
run_max = 30;         % number of repeated runs
alg_name = 'iPWO';
funcs = 1:12;         % CEC2022 has 12 functions total

% results directory
results_folder = 'CEC2022_tu';
if ~exist(results_folder, 'dir')
    mkdir(results_folder);
end

for di = 1:numel(dims)
    dim = dims(di);

    % CEC2022 standard budget (same as CEC2017: MaxFEs = 10000 * D)
    MaxFEs = 10000 * dim;
    Max_iter = ceil(MaxFEs / nPop);
    Lcurve = Max_iter;

    for fi = 1:numel(funcs)
        Function_name = funcs(fi);

        % load benchmark function
        try
            [lb, ub, dim, fobj] = Get_Functions_cec2022(Function_name, dim);
            fprintf('Loaded benchmark function F%d, dim=%d\n', Function_name, dim);
        catch ME
            error('Failed to load benchmark function: %s', ME.message);
        end

%% ==================== data preallocation ====================
        Lcurve = Max_iter;
        sum_best_curve = zeros(Lcurve, 1);
        sum_avg_fit_curve = zeros(Lcurve, 1);
        success_runs = 0;
        sum_time = 0;
        best_all = nan(run_max, 1);   % final best value of each of the 30 runs (for median/mean/std/Wilcoxon)

        best_run.score = inf;
        best_run.pos = [];
        best_run.curve = [];
        best_run.history = [];
        best_run.time = inf;

%% ==================== main loop: multiple runs ====================
        h = waitbar(0, 'Running iPWO...');
        for run = 1:run_max
            fprintf('\n============== Run %d / %d ==============\n', run, run_max);
            waitbar(run / run_max, h, sprintf('Progress: %d / %d', run, run_max));

            try
                t_start = tic;

                best_score = [];
                best_pos = [];
                curve = [];
                history = [];

                % call only the version with history
                [best_score, best_pos, curve, history] = iPWO_history(nPop, MaxFEs, lb, ub, dim, fobj);

                elapsed = toc(t_start);

                % ----------- safety check: best_score -----------
                if isempty(best_score) || ~isscalar(best_score) || ~isfinite(best_score)
                    warning('iPWO run %d returned invalid best_score, using large value', run);
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

                % ----------- record best run -----------
                if best_score < best_run.score
                    best_run.score = best_score;
                    best_run.pos = best_pos;
                    best_run.curve = curve;
                    best_run.history = history;
                    best_run.time = elapsed;
                end
                best_all(run) = best_score;

                fprintf('  iPWO: Best = %.6e | Time = %.4fs\n', best_score, elapsed);

            catch ME
                warning('iPWO run %d failed: %s', run, ME.message);
            end
        end
        close(h);

        if success_runs == 0
            error('All runs failed; check the iPWO / CEC2022 function interface.');
        end

%% ==================== average curves ====================
        avg_best_curve = sum_best_curve / success_runs;
        avg_fit_curve = sum_avg_fit_curve / success_runs;
        avg_time = sum_time / success_runs;

        fprintf('\n=== iPWO statistics (CEC2022 F%d, Dim=%d) ===\n', Function_name, dim);
        fprintf('Successful runs: %d / %d\n', success_runs, run_max);
        fprintf('Average runtime: %.6f s\n', avg_time);
        fprintf('Best run best objective value: %.6e\n', best_run.score);

%% ==================== generate TIFF five-panel figure + reproduction data (330 DPI / 18 pt / unified crop) ====================
        figOpts.dpi = 330;
        figOpts.fontSize = 18;
        figOpts.alg_name = alg_name;
        figOpts.prefix = 'CEC2022';
        figOpts.benchLabel = 'CEC2022';
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
        results.best_all = best_all;
        results.avg_time = avg_time;
        results.avg_best_curve = avg_best_curve;
        results.avg_fit_curve = avg_fit_curve;
        results.best_run = best_run;

        matFile = fullfile(results_folder, sprintf('CEC2022_F%d_Dim%d_iPWO_Results.mat', Function_name, dim));
        save(matFile, 'results');
        fprintf('Results saved to: %s\n', matFile);

        fprintf('\nAll figures saved to folder: %s\n', results_folder);
        close all;
    end
end

% unify crop size of five-panel figure and sub-panels (pad white border, keep 330 DPI)
if exist('unifyTiffSizes', 'file')
    fprintf('\n--- unifying figure sizes ---\n');
    unifyTiffSizes(results_folder);
end

%% ==================== local functions ====================

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
