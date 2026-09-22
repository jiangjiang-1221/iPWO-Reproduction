%% make_iPWO_figures.m
%  regenerate from saved CEC2017 iPWO raw results (Results.mat)
%  single-panel TIFF figures (2.928cm square, 600 DPI, exported physical font 6pt),
%  and generate figure-reproduction data (repro_data) and landscape cache (landscape_cache).
%  auto-detect benchmark (CEC2017/CEC2022), function id and dimension from result files.
%
%  ===== layout spec =====
%    A4 (21.0x29.7cm), top/bottom margin 2.54cm, left/right margin 3.18cm
%    => text width 14.64cm, 5 panels per row => each 2.928cm square
%    => 600 DPI => 692x692 px, exported physical font 6pt
%    => no five-panel figure; each panel also saves .fig source to figures/fig
%
%  usage: add this file's directory (code/) to MATLAB path, then run this script directly.
%  deps: iPWO_build_figures.m, Get_Functions_cec2017.m,
%        cec17_func.mexw64 and Results.mat under data/raw.

clear; clc; close all;

codeDir = fileparts(mfilename('fullpath'));
rootDir = fullfile(codeDir, '..');
rawDir  = fullfile(rootDir, 'data', 'raw');
figDir  = fullfile(rootDir, 'figures');
cacheDir= fullfile(rootDir, 'data', 'landscape_cache');
reproDir= fullfile(rootDir, 'data', 'repro');

if ~exist(rawDir, 'dir'),  error('missing data directory: %s', rawDir);  end
if ~exist(figDir, 'dir'),  mkdir(figDir);  end
if ~exist(cacheDir, 'dir'), mkdir(cacheDir); end
if ~exist(reproDir, 'dir'), mkdir(reproDir); end

%% --- clean legacy artifacts: five-panel figure and old-spec sub-panels (keep only single panels this run) ---
oldCombined = dir(fullfile(figDir, 'CEC*_5Panels.tif'));
for q = 1:numel(oldCombined)
    delete(fullfile(figDir, oldCombined(q).name));
end
if numel(oldCombined) > 0
    fprintf('deleted old five-panel TIFF: %d\n', numel(oldCombined));
end

files = dir(fullfile(rawDir, 'CEC*_F*_iPWO_Results.mat'));
if isempty(files)
    error('no CEC*_F*_iPWO_Results.mat found: %s', rawDir);
end

for k = 1:numel(files)
    tk = regexp(files(k).name, '^(CEC\d+)_F(\d+)_Dim(\d+)_iPWO_Results\.mat$', 'tokens', 'once');
    if isempty(tk)
        warning('cannot parse file name, skip: %s', files(k).name);
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

    % publication spec: 2.928cm square / 600 DPI / exported physical font 6pt
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

    fprintf('\n========== generate F%d (Dim=%d) figures ==========\n', f, dimF);
    iPWO_build_figures(f, dim, lb, ub, fobj, ...
        r.best_run, r.avg_best_curve, r.avg_fit_curve, r.Max_iter, figDir, opts);
end

fprintf('\n all done: single-panel TIFF -> %s\n', figDir);
fprintf('   .fig sources -> %s\n', fullfile(figDir, 'fig'));
fprintf('   reproduction data -> %s\n', reproDir);
fprintf('   spec: 2.928cm square | 600 DPI | export font 6pt | 5 per row\n');
