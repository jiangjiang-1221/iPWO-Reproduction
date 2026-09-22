%% reproduce_figures_from_data.m
%  regenerate TIFF five-panel figure and sub-panels using only reproduction data under data/repro,
%  no CEC2017 mex objective function needed; guarantees 'data alone reproduces figures'.
%
%  usage: add this file's directory (code/) to MATLAB path, then run this script directly.

clear; clc; close all;

codeDir = fileparts(mfilename('fullpath'));
rootDir = fullfile(codeDir, '..');
reproDir= fullfile(rootDir, 'data', 'repro');
figDir  = fullfile(rootDir, 'figures', 'from_repro_data');

if ~exist(reproDir, 'dir'), error('missing reproduction data dir: %s', reproDir); end
if ~exist(figDir, 'dir'), mkdir(figDir); end

files = dir(fullfile(reproDir, 'CEC2017_F*_iPWO_ReproData.mat'));
if isempty(files)
    error('no reproduction data file found: %s', reproDir);
end

for k = 1:numel(files)
    S = load(fullfile(reproDir, files(k).name));
    d = S.repro;

    land = struct('x1g', double(d.x1g), 'x2g', double(d.x2g), ...
        'zGrid', double(d.zGrid), 'base_point', d.base_point, 'zbest', d.zbest);
    best_run = struct('score', d.best_score, 'pos', d.best_pos, ...
        'curve', d.best_curve, 'history', [], 'time', NaN);

    opts.dpi = d.figSpecs.dpi;
    opts.fontSize = d.figSpecs.fontSize;
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
    % reproduction data already exists, do not rewrite; point to source dir to avoid redundant copies
    opts.reproDataDir = reproDir;
    opts.landscapeCacheDir = fullfile(rootDir, 'data', 'landscape_cache');

    fprintf('\n========== reproduce from data F%d (Dim=%d) ==========\n', d.Function_name, d.dim);
    iPWO_build_figures(d.Function_name, d.dim, d.lb(:)', d.ub(:)', [], ...
        best_run, d.avg_best_curve, d.avg_fit_curve, d.Lcurve, figDir, opts);
end

fprintf('\n all done: %s\n', figDir);

% unify sizes
fprintf('\n--- unify image sizes ---\n');
unifyTiffSizes(figDir);
fprintf(' size unification done\n');
