%% export_figs_to_tiff.m
%  Re-export .fig sources under figures/fig to TIFF in bulk, per paper spec.
%
%  Use: open .fig in MATLAB, edit content (color/linestyle/label/data), save,
%       then run this script to re-export at a unified spec in one step, no need to rerun the optimization.
%
%  ===== layout spec =====
%    A4 (21.0x29.7cm), top/bottom margin 2.54cm, left/right margin 3.18cm
%    => text width 14.64cm, 5 panels per row => each 2.928cm square
%    => 600 DPI => 692x692 px, exported physical font size 9pt
%
%  Note: .fig stores proportionally enlarged editing version (editCm canvas, font scaled up),
%        on export this script auto restores to panelCm + 9pt proportionally, WYSIWYG.

clear; clc; close all;

%% ===== output spec (keep consistent with iPWO_build_figures.m) =====
SPEC.panelCm = 2.928;   % exported physical side length (cm) = A4 text width 14.64cm / 5
SPEC.editCm  = 8;       % .fig editing canvas side length (cm)
SPEC.dpi     = 600;     % export resolution

codeDir = fileparts(mfilename('fullpath'));
rootDir = fullfile(codeDir, '..');
figSrcDir = fullfile(rootDir, 'figures', 'fig');
outDir    = fullfile(rootDir, 'figures');

if ~exist(figSrcDir, 'dir'), error('missing .fig directory: %s', figSrcDir); end
if ~exist(outDir, 'dir'),    mkdir(outDir); end

files = dir(fullfile(figSrcDir, '*.fig'));
if isempty(files)
    error('no .fig file found: %s', figSrcDir);
end

scaleF = SPEC.editCm / SPEC.panelCm;   % editing-version magnification relative to export version
fprintf('total %d .fig, export at %.3fcm square / %d DPI to TIFF\n\n', ...
    numel(files), SPEC.panelCm, SPEC.dpi);

for k = 1:numel(files)
    [~, nm, ~] = fileparts(files(k).name);
    try
        fig = openfig(fullfile(figSrcDir, files(k).name), 'invisible');
    catch ME
        warning('open failed, skip %s: %s', files(k).name, ME.message);
        continue;
    end

    % --- proportional restore: font size / canvas size ---
    hTxt = findall(fig, '-property', 'FontSize');
    fs0 = arrayfun(@(h) get(h, 'FontSize'), hTxt);
    set(hTxt, {'FontSize'}, num2cell(fs0 / scaleF));

    tifPath = fullfile(outDir, [nm '.tif']);
    fig.Units = 'centimeters';
    fig.Position = [3 3 SPEC.panelCm SPEC.panelCm];
    fig.PaperUnits = 'centimeters';
    fig.PaperSize = [SPEC.panelCm SPEC.panelCm];
    fig.PaperPosition = [0 0 SPEC.panelCm SPEC.panelCm];
    fig.PaperPositionMode = 'manual';
    print(fig, tifPath, '-dtiff', sprintf('-r%d', SPEC.dpi));
    close(fig);

    try
        info = imfinfo(tifPath);
        fprintf('[%3d/%3d] %s -> %d x %d px, %d DPI\n', k, numel(files), nm, ...
            info.Width, info.Height, round(info.XResolution));
    catch
        fprintf('[%3d/%3d] %s -> exported\n', k, numel(files), nm);
    end
end

fprintf('\n export done -> %s\n', outDir);
