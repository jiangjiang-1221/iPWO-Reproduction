%% reproduce_figures_from_data.m
%  仅使用 data/repro 下的复现数据重新生成单独面板 TIFF,
%  不依赖 CEC2017 mex 目标函数, 保证"数据即可复现图片"。
%
%  ===== 版面规格 =====
%    A4(21.0x29.7cm), 上下边距 2.54cm, 左右边距 3.18cm
%    => 正文宽度 14.64cm, 一行放 5 张 => 每张 2.928cm 见方
%    => 600 DPI => 692x692 px, 导出物理字号 9pt
%    => 不再生成五联图; 每个面板另存 .fig 源文件
%
%  注意: 复现数据中的旧 figSpecs(330 DPI / 18pt) 已被下方新规格覆盖,
%        与本文件夹当前的出版规格保持一致。
%
%  运行方式: 将本文件所在目录(code/)加入 MATLAB 路径后直接运行本脚本。

clear; clc; close all;

codeDir = fileparts(mfilename('fullpath'));
rootDir = fullfile(codeDir, '..');
reproDir= fullfile(rootDir, 'data', 'repro');
figDir  = fullfile(rootDir, 'figures', 'from_repro_data');

if ~exist(reproDir, 'dir'), error('缺少复现数据目录: %s', reproDir); end
if ~exist(figDir, 'dir'), mkdir(figDir); end

files = dir(fullfile(reproDir, 'CEC2017_F*_iPWO_ReproData.mat'));
if isempty(files)
    error('未找到任何复现数据文件: %s', reproDir);
end

for k = 1:numel(files)
    S = load(fullfile(reproDir, files(k).name));
    d = S.repro;

    land = struct('x1g', double(d.x1g), 'x2g', double(d.x2g), ...
        'zGrid', double(d.zGrid), 'base_point', d.base_point, 'zbest', d.zbest);
    best_run = struct('score', d.best_score, 'pos', d.best_pos, ...
        'curve', d.best_curve, 'history', [], 'time', NaN);

    % 论文出版规格(覆盖复现数据中的旧规格)
    opts.dpi = 600;
    opts.fontSize = 9;
    opts.panelCm = 2.928;
    opts.editCm = 8;
    opts.saveFig = true;
    opts.alg_name = d.alg_name;
    opts.prefix = d.prefix;
    opts.benchLabel = d.benchLabel;
    opts.landscape = land;
    opts.trajIter = d.trajIter;
    opts.trajDist = d.trajDist;
    opts.trajectoryOK = d.trajectoryOK;
    opts.searchXY = double(d.searchXY);
    opts.searchIter = double(d.searchIter);
    opts.historyOK = d.historyOK;
    % 复现数据已存在, 不再重复写出; 指向源目录防止生成冗余副本
    opts.reproDataDir = reproDir;
    opts.landscapeCacheDir = fullfile(rootDir, 'data', 'landscape_cache');

    fprintf('\n========== 由数据复现 F%d (Dim=%d) ==========\n', d.Function_name, d.dim);
    iPWO_build_figures(d.Function_name, d.dim, d.lb(:)', d.ub(:)', [], ...
        best_run, d.avg_best_curve, d.avg_fit_curve, d.Lcurve, figDir, opts);
end

fprintf('\n✅ 全部完成 -> %s\n', figDir);
fprintf('   规格: 2.928cm 见方 | 600 DPI | 导出字号 9pt | 一行可放 5 张\n');
