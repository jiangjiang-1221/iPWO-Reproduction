clc;
clear;
close all;

%% ==================== 参数设置 ====================
nPop = 30;            % 种群数
dims = [10, 20];      % CEC2022 官方测试维度
run_max = 30;         % 重复运行次数
alg_name = 'iPWO';
funcs = 1:12;         % CEC2022 共 12 个函数

% 结果保存文件夹
results_folder = 'CEC2022_tu';
if ~exist(results_folder, 'dir')
    mkdir(results_folder);
end

for di = 1:numel(dims)
    dim = dims(di);

    % CEC2022 标准预算 (与 CEC2017 一致: MaxFEs = 10000 * D)
    MaxFEs = 10000 * dim;
    Max_iter = ceil(MaxFEs / nPop);
    Lcurve = Max_iter;

    for fi = 1:numel(funcs)
        Function_name = funcs(fi);

        % 获取测试函数
        try
            [lb, ub, dim, fobj] = Get_Functions_cec2022(Function_name, dim);
            fprintf('✅ 成功加载测试函数 F%d, 维度=%d\n', Function_name, dim);
        catch ME
            error('❌ 无法加载测试函数: %s', ME.message);
        end

%% ==================== 数据预分配 ====================
        Lcurve = Max_iter;
        sum_best_curve = zeros(Lcurve, 1);
        sum_avg_fit_curve = zeros(Lcurve, 1);
        success_runs = 0;
        sum_time = 0;
        best_all = nan(run_max, 1);   % 30 次运行各自的最终最优值(供 Median/Mean/Std/Wilcoxon)

        best_run.score = inf;
        best_run.pos = [];
        best_run.curve = [];
        best_run.history = [];
        best_run.time = inf;

%% ==================== 主循环：多次运行 ====================
        h = waitbar(0, '开始运行 iPWO...');
        for run = 1:run_max
            fprintf('\n============== Run %d / %d ==============\n', run, run_max);
            waitbar(run / run_max, h, sprintf('运行进度: %d / %d', run, run_max));

            try
                t_start = tic;

                best_score = [];
                best_pos = [];
                curve = [];
                history = [];

                % 只调用带 history 的版本
                [best_score, best_pos, curve, history] = iPWO_history(nPop, MaxFEs, lb, ub, dim, fobj);

                elapsed = toc(t_start);

                % ----------- 安全检查：best_score -----------
                if isempty(best_score) || ~isscalar(best_score) || ~isfinite(best_score)
                    warning('iPWO 第 %d 次运行返回无效 best_score，使用大值代替', run);
                    best_score = 1e10;
                end

                % ----------- 安全检查：curve -----------
                curve = curve(:);
                if isempty(curve)
                    curve = best_score * ones(Lcurve, 1);
                end
                if length(curve) < Lcurve
                    curve = [curve; repmat(curve(end), Lcurve - length(curve), 1)];
                elseif length(curve) > Lcurve
                    curve = curve(1:Lcurve);
                end

                % ----------- 提取 average fitness 曲线 -----------
                avg_fit_curve_single = extractAverageFitness(history, curve, Lcurve);

                % ----------- 累加 -----------
                sum_best_curve = sum_best_curve + curve;
                sum_avg_fit_curve = sum_avg_fit_curve + avg_fit_curve_single;
                success_runs = success_runs + 1;
                sum_time = sum_time + elapsed;

                % ----------- 记录最好一次运行 -----------
                if best_score < best_run.score
                    best_run.score = best_score;
                    best_run.pos = best_pos;
                    best_run.curve = curve;
                    best_run.history = history;
                    best_run.time = elapsed;
                end
                best_all(run) = best_score;

                fprintf('  ✅ iPWO: Best = %.6e | Time = %.4fs\n', best_score, elapsed);

            catch ME
                warning('❌ iPWO 在第 %d 次运行失败: %s', run, ME.message);
            end
        end
        close(h);

        if success_runs == 0
            error('所有运行都失败了，请检查 iPWO / CEC2022 函数接口是否正确。');
        end

%% ==================== 平均曲线 ====================
        avg_best_curve = sum_best_curve / success_runs;
        avg_fit_curve = sum_avg_fit_curve / success_runs;
        avg_time = sum_time / success_runs;

        fprintf('\n=== iPWO 统计结果 (CEC2022 F%d, Dim=%d) ===\n', Function_name, dim);
        fprintf('成功运行次数: %d / %d\n', success_runs, run_max);
        fprintf('平均运行时间: %.6f s\n', avg_time);
        fprintf('最好一次运行最优目标值: %.6e\n', best_run.score);

%% ==================== 生成 TIFF 五联图 + 复现数据(330DPI / 18pt / 统一切边) ====================
        figOpts.dpi = 330;
        figOpts.fontSize = 18;
        figOpts.alg_name = alg_name;
        figOpts.prefix = 'CEC2022';
        figOpts.benchLabel = 'CEC2022';
        figOpts.landscapeCacheDir = fullfile(results_folder, 'landscape_cache');
        figOpts.reproDataDir = fullfile(results_folder, 'repro_data');
        iPWO_build_figures(Function_name, dim, lb, ub, fobj, best_run, ...
            avg_best_curve, avg_fit_curve, Lcurve, results_folder, figOpts);

%% ==================== 保存数值结果 ====================
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
        fprintf('💾 结果已保存到: %s\n', matFile);

        fprintf('\n✅ 所有图片已保存到文件夹: %s\n', results_folder);
        close all;
    end
end

% 统一五联图与子图的裁剪尺寸(白边补齐, 保持 330 DPI)
if exist('unifyTiffSizes', 'file')
    fprintf('\n--- 统一图片尺寸 ---\n');
    unifyTiffSizes(results_folder);
end

%% ==================== 局部函数 ====================

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
