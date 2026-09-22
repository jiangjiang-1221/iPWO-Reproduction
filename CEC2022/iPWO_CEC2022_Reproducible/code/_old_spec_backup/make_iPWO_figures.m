%% make_iPWO_figures.m
%  regenerate from saved CEC2017 iPWO raw results (Results.mat)
%  TIFF five-panel figure and sub-panels (330 DPI, 18 pt, unified crop, middle legend bottom-right),
%  and generate data needed to reproduce figures (repro_data) and terrain cache (landscape_cache).
%  auto-detect benchmark (CEC2017/CEC2022), function index and dimension from result files.
%
%  usage: add this file's directory (code/) to the MATLAB path, then run this script.
%  depends on: iPWO_build_figures.m, Get_Functions_cec2017.m,
%        cec17_func.mexw64 and Results.mat under data/raw.

clear; clc; close all;

codeDir = fileparts(mfilename('fullpath'));
rootDir = fullfile(codeDir, '..');
rawDir  = fullfile(rootDir, 'data', 'raw');
figDir  = fullfile(rootDir, 'figures');
cacheDir= fullfile(rootDir, 'data', 'landscape_cache');
reproDir= fullfile(rootDir, 'data', 'repro');

if ~exist(rawDir, 'dir'),  error('Missing data directory: %s', rawDir);  end
if ~exist(figDir, 'dir'),  mkdir(figDir);  end
if ~exist(cacheDir, 'dir'), mkdir(cacheDir); end
if ~exist(reproDir, 'dir'), mkdir(reproDir); end

files = dir(fullfile(rawDir, 'CEC*_F*_iPWO_Results.mat'));
if isempty(files)
    error('No CEC*_F*_iPWO_Results.mat found: %s', rawDir);
end

for k = 1:numel(files)
    tk = regexp(files(k).name, '^(CEC\d+)_F(\d+)_Dim(\d+)_iPWO_Results\.mat$', 'tokens', 'once');
    if isempty(tk)
        warning('Cannot parse file name, skipping: %s', files(k).name);
        continue;
    end
    prefix = tk{1};
    f = str2double(tk{2});
    dimF = str2double(tk{3});
    matFile = fullfile(rawDir, files(k).name);

    S = load(matFile);
    r = S.results;

    % get function bounds and handle (pick interface by benchmark; needs matching mex and input_data)
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

    fprintf('\n========== generating F%d (Dim=%d) figures ==========\n', f, dimF);
    iPWO_build_figures(f, dim, lb, ub, fobj, ...
        r.best_run, r.avg_best_curve, r.avg_fit_curve, r.Max_iter, figDir, opts);
end

fprintf('\nDone: five-panel figure/sub-panels -> %s\n', figDir);
fprintf('   reproduction data -> %s\n', reproDir);

% unify crop size of five-panel figure and sub-panels (pad white border, keep 330 DPI)
fprintf('\n--- unifying figure sizes ---\n');
unifyTiffSizes(figDir);
fprintf('Size unification done\n');
