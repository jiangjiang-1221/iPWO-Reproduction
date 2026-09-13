%% make_iPWO_figures.m
%  从已保存的 CEC2017 iPWO 原始结果(Results.mat)重新生成
%  单独面板 TIFF 图片 (2.928cm 见方, 600 DPI, 导出物理字号 6pt),
%  并生成图片复现所需数据(repro_data)与地形缓存(landscape_cache)。
%  自动识别结果文件中的基准(CEC2017/CEC2022)、函数编号与维度。
%
%  ===== 版面规格 =====
%    A4(21.0x29.7cm), 上下边距 2.54cm, 左右边距 3.18cm
%    => 正文宽度 14.64cm, 一行放 5 张 => 每张 2.928cm 见方
%    => 600 DPI => 692x692 px, 导出物理字号 6pt
%    => 不再生成五联图; 每个面板另存 .fig 源文件到 figures/fig
%
%  运行方式: 将本文件所在目录(code/)加入 MATLAB 路径后直接运行本脚本。
%  依赖: 同级目录下的 iPWO_build_figures.m、Get_Functions_cec2017.m、
%        cec17_func.mexw64 以及 data/raw 下的 Results.mat。

clear; clc; close all;

codeDir = fileparts(mfilename('fullpath'));
rootDir = fullfile(codeDir, '..');
rawDir  = fullfile(rootDir, 'data', 'raw');
figDir  = fullfile(rootDir, 'figures');
cacheDir= fullfile(rootDir, 'data', 'landscape_cache');
reproDir= fullfile(rootDir, 'data', 'repro');

if ~exist(rawDir, 'dir'),  error('缺少数据目录: %s', rawDir);  end
if ~exist(figDir, 'dir'),  mkdir(figDir);  end
if ~exist(cacheDir, 'dir'), mkdir(cacheDir); end
if ~exist(reproDir, 'dir'), mkdir(reproDir); end

%% --- 清理历史产物: 五联图与旧规格子图(本次只保留单独面板) ---
oldCombined = dir(fullfile(figDir, 'CEC*_5Panels.tif'));
for q = 1:numel(oldCombined)
    delete(fullfile(figDir, oldCombined(q).name));
end
if numel(oldCombined) > 0
    fprintf('已删除旧五联图 TIFF: %d 个\n', numel(oldCombined));
end

files = dir(fullfile(rawDir, 'CEC*_F*_iPWO_Results.mat'));
if isempty(files)
    error('未找到任何 CEC*_F*_iPWO_Results.mat: %s', rawDir);
end

for k = 1:numel(files)
    tk = regexp(files(k).name, '^(CEC\d+)_F(\d+)_Dim(\d+)_iPWO_Results\.mat$', 'tokens', 'once');
    if isempty(tk)
        warning('无法解析文件名, 跳过: %s', files(k).name);
        continue;
    end
    prefix = tk{1};
    f = str2double(tk{2});
    dimF = str2double(tk{3});
    matFile = fullfile(rawDir, files(k).name);

    S = load(matFile);
    r = S.results;

    % 获取函数边界与句柄(按基准选择接口; 需要对应 mex 与 input_data)
    if contains(prefix, '2022')
        [lb, ub, dim, fobj] = Get_Functions_cec2022(f, dimF);
    else
        [lb, ub, dim, fobj] = Get_Functions_cec2017(f, dimF);
    end

    % 论文出版规格: 2.928cm 见方 / 600 DPI / 导出物理字号 6pt
    opts.dpi = 600;
    opts.fontSize = 6;
    opts.panelCm = 2.928;
    opts.editCm = 8;
    opts.saveFig = true;
    opts.alg_name = 'iPWO';
    opts.prefix = prefix;
    opts.benchLabel = prefix;
    opts.landscapeCacheDir = cacheDir;
    opts.reproDataDir = reproDir;

    fprintf('\n========== 生成 F%d (Dim=%d) 图片 ==========\n', f, dimF);
    iPWO_build_figures(f, dim, lb, ub, fobj, ...
        r.best_run, r.avg_best_curve, r.avg_fit_curve, r.Max_iter, figDir, opts);
end

fprintf('\n✅ 全部完成: 单独面板 TIFF -> %s\n', figDir);
fprintf('   .fig 源文件 -> %s\n', fullfile(figDir, 'fig'));
fprintf('   复现数据 -> %s\n', reproDir);
fprintf('   规格: 2.928cm 见方 | 600 DPI | 导出字号 6pt | 一行可放 5 张\n');
