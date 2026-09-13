%% make_iPWO_figures.m
%  从已保存的 CEC2017 iPWO 原始结果(Results.mat)重新生成
%  TIFF 五联图与子图 (330 DPI, 18pt, 统一切边, 中间图例右下角),
%  并生成图片复现所需数据(repro_data)与地形缓存(landscape_cache)。
%  自动识别结果文件中的基准(CEC2017/CEC2022)、函数编号与维度。
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

    opts.dpi = 330;
    opts.fontSize = 18;
    opts.alg_name = 'iPWO';
    opts.prefix = prefix;
    opts.benchLabel = prefix;
    opts.landscapeCacheDir = cacheDir;
    opts.reproDataDir = reproDir;

    fprintf('\n========== 生成 F%d (Dim=%d) 图片 ==========\n', f, dimF);
    iPWO_build_figures(f, dim, lb, ub, fobj, ...
        r.best_run, r.avg_best_curve, r.avg_fit_curve, r.Max_iter, figDir, opts);
end

fprintf('\n✅ 全部完成: 五联图/子图 -> %s\n', figDir);
fprintf('   复现数据 -> %s\n', reproDir);

% 统一五联图与子图的裁剪尺寸(白边补齐, 保持 330 DPI)
fprintf('\n--- 统一图片尺寸 ---\n');
unifyTiffSizes(figDir);
fprintf('✅ 尺寸统一完成\n');
