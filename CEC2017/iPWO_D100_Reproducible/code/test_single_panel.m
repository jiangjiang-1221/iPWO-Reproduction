%% test_single_panel.m  单函数试跑: 校验版面规格是否精确落地
clear; clc; close all;

codeDir = fileparts(mfilename('fullpath'));
rootDir = fullfile(codeDir, '..');
rawDir  = fullfile(rootDir, 'data', 'raw');
cacheDir= fullfile(rootDir, 'data', 'landscape_cache');
reproDir= fullfile(rootDir, 'data', 'repro');
outDir  = fullfile(rootDir, 'figures', '_test_out');
if ~exist(outDir, 'dir'), mkdir(outDir); end

testF = 1;
matFile = fullfile(rawDir, sprintf('CEC2017_F%d_Dim10_iPWO_Results.mat', testF));
S = load(matFile);
r = S.results;
[lb, ub, dim, fobj] = Get_Functions_cec2017(testF, 10);

opts.dpi = 600;
opts.fontSize = 6;
opts.panelCm = 2.928;
opts.editCm = 8;
opts.saveFig = true;
opts.alg_name = 'iPWO';
opts.prefix = 'CEC2017';
opts.benchLabel = 'CEC2017';
opts.landscapeCacheDir = cacheDir;
opts.reproDataDir = reproDir;

fprintf('试跑 F%d (Dim=%d)\n', testF, dim);
iPWO_build_figures(testF, dim, lb, ub, fobj, ...
    r.best_run, r.avg_best_curve, r.avg_fit_curve, r.Max_iter, outDir, opts);

fprintf('\n--- 导出结果自检 ---\n');
d = dir(fullfile(outDir, '*.tif'));
for i = 1:numel(d)
    info = imfinfo(fullfile(outDir, d(i).name));
    fprintf('%-40s %4d x %4d px | X=%d Y=%d DPI | %.2f KB\n', ...
        d(i).name, info.Width, info.Height, ...
        round(info.XResolution), round(info.YResolution), info.FileSize/1024);
end

fs = dir(fullfile(outDir, 'fig', '*.fig'));
fprintf('\n.fig 源文件: %d 个\n', numel(fs));
