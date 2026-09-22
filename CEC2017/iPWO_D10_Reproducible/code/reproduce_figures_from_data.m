%% reproduce_figures_from_data.m
%  regenerate individual panel TIFFs from reproduction data under data/repro only,
%  no dependency on CEC2017 mex objective function; "data reproduces figures".
%
%  ===== layout spec =====
%    A4 (21.0x29.7 cm), top/bottom margin 2.54 cm, left/right margin 3.18 cm
%    => text width 14.64 cm, 5 panels per row => each 2.928 cm square
%    => 600 DPI => 692x692 px, exported physical font size 9 pt
%    => no five-panel figure; each panel also saved as .fig source
%
%  note: old figSpecs (330 DPI / 18 pt) in reproduction data overridden by new spec below,
%        consistent with current publication spec of this folder.
%
%  usage: add this file's directory (code/) to the MATLAB path, then run this script.

clear; clc; close all;

codeDir = fileparts(mfilename('fullpath'));
rootDir = fullfile(codeDir, '..');
reproDir= fullfile(rootDir, 'data', 'repro');
figDir  = fullfile(rootDir, 'figures', 'from_repro_data');

if ~exist(reproDir, 'dir'), error('Missing reproduction data directory: %s', reproDir); end
if ~exist(figDir, 'dir'), mkdir(figDir); end

files = dir(fullfile(reproDir, 'CEC2017_F*_iPWO_ReproData.mat'));
if isempty(files)
    error('No reproduction data file found: %s', reproDir);
end

for k = 1:numel(files)
    S = load(fullfile(reproDir, files(k).name));
    d = S.repro;

    land = struct('x1g', double(d.x1g), 'x2g', double(d.x2g), ...
        'zGrid', double(d.zGrid), 'base_point', d.base_point, 'zbest', d.zbest);
    best_run = struct('score', d.best_score, 'pos', d.best_pos, ...
        'curve', d.best_curve, 'history', [], 'time', NaN);

    % paper publication spec (overrides old spec in reproduction data)
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
    % reproduction data already exists; not rewritten; point to source dir to avoid redundant copies
    opts.reproDataDir = reproDir;
    opts.landscapeCacheDir = fullfile(rootDir, 'data', 'landscape_cache');

    fprintf('\n========== reproducing F%d (Dim=%d) from data ==========\n', d.Function_name, d.dim);
    iPWO_build_figures(d.Function_name, d.dim, d.lb(:)', d.ub(:)', [], ...
        best_run, d.avg_best_curve, d.avg_fit_curve, d.Lcurve, figDir, opts);
end

fprintf('\nDone -> %s\n', figDir);
fprintf('   spec: 2.928 cm square | 600 DPI | exported font size 9 pt | 5 per row\n');
