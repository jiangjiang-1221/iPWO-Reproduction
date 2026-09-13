% summarize_iPWO_results.m
% 汇总 iPWO 测试结果(兼容 CEC2017/CEC2022, 自动识别基准/函数/维度),
% 输出每个维度一份汇总 CSV: Best / Median / Mean / Std / 成功次数 / 平均耗时。
clear; clc;

outDir = fullfile(pwd, 'CEC2022_tu');
files = dir(fullfile(outDir, 'CEC*_F*_iPWO_Results.mat'));
if isempty(files)
    error('未找到结果文件: %s', outDir);
end

items = struct('prefix', {}, 'func', {}, 'dim', {});
for k = 1:numel(files)
    tk = regexp(files(k).name, '^(CEC\d+)_F(\d+)_Dim(\d+)_iPWO_Results\.mat$', 'tokens', 'once');
    if ~isempty(tk)
        items(end+1) = struct('prefix', tk{1}, 'func', str2double(tk{2}), 'dim', str2double(tk{3})); %#ok<AGROW>
    end
end
if isempty(items)
    error('文件名格式无法解析');
end

prefix = items(1).prefix;
dims = unique([items.dim]);

for di = 1:numel(dims)
    d = dims(di);
    sel = items([items.dim] == d);

    fprintf('\n===== %s Dim=%d 汇总 =====\n', prefix, d);
    fprintf('%-5s %-16s %-16s %-16s %-16s %-10s %-12s\n', ...
        'Func', 'Best', 'Median', 'Mean', 'Std', 'Success', 'AvgTime(s)');

    rows = struct('func', {}, 'best', {}, 'median', {}, 'mean', {}, 'std', {}, 'success', {}, 'avg_time', {});
    for k = 1:numel(sel)
        f = sel(k).func;
        matFile = fullfile(outDir, sprintf('%s_F%d_Dim%d_iPWO_Results.mat', prefix, f, d));
        if ~isfile(matFile), continue; end
        S = load(matFile);
        r = S.results;

        best   = r.best_run.score;
        succ   = r.success_runs;
        atime  = r.avg_time;
        if isfield(r, 'best_all') && numel(r.best_all) >= 2 && all(isfinite(r.best_all(:)))
            ba = r.best_all(:);
            medV = median(ba);
            meanV = mean(ba);
            stdV = std(ba);
        else
            % 兼容旧数据: 以 30 次平均曲线终值近似(仅速览)
            medV = r.avg_best_curve(end);
            meanV = r.avg_best_curve(end);
            stdV = NaN;
        end

        rows(end+1) = struct('func', f, 'best', best, 'median', medV, ...
            'mean', meanV, 'std', stdV, 'success', succ, 'avg_time', atime); %#ok<AGROW>
        if isnan(stdV)
            fprintf('F%-4d %-16.6e %-16.6e %-16.6e %-16s %-10d %-12.3f\n', ...
                f, best, medV, meanV, 'N/A', succ, atime);
        else
            fprintf('F%-4d %-16.6e %-16.6e %-16.6e %-16.6e %-10d %-12.3f\n', ...
                f, best, medV, meanV, stdV, succ, atime);
        end
    end

    csvFile = fullfile(outDir, sprintf('iPWO_%s_Dim%d_Summary.csv', prefix, d));
    fid = fopen(csvFile, 'w');
    fprintf(fid, 'Func,Best,Median,Mean,Std,SuccessRuns,AvgTime(s)\n');
    for k = 1:numel(rows)
        if isnan(rows(k).std)
            fprintf(fid, 'F%d,%.6e,%.6e,%.6e,%s,%d,%.3f\n', rows(k).func, ...
                rows(k).best, rows(k).median, rows(k).mean, 'N/A', rows(k).success, rows(k).avg_time);
        else
            fprintf(fid, 'F%d,%.6e,%.6e,%.6e,%.6e,%d,%.3f\n', rows(k).func, ...
                rows(k).best, rows(k).median, rows(k).mean, rows(k).std, rows(k).success, rows(k).avg_time);
        end
    end
    fclose(fid);
    fprintf('已保存: %s\n', csvFile);
end
