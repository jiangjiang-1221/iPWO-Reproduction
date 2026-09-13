%% export_figs_to_tiff.m
%  把 figures/fig 下的 .fig 源文件按论文规格批量重新导出为 TIFF。
%
%  用途: 在 MATLAB 中打开 .fig 修改内容(配色/线型/标签/数据)并保存后,
%        运行本脚本即可一键按统一规格重新出图, 无需重跑优化实验。
%
%  ===== 版面规格 =====
%    A4(21.0x29.7cm), 上下边距 2.54cm, 左右边距 3.18cm
%    => 正文宽度 14.64cm, 一行放 5 张 => 每张 2.928cm 见方
%    => 600 DPI => 692x692 px, 导出物理字号 9pt
%
%  说明: .fig 保存的是等比放大的编辑版(editCm 画布, 字号同步放大),
%        导出时本脚本自动等比还原为 panelCm + 9pt, 所见即所得。

clear; clc; close all;

%% ===== 输出规格(与 iPWO_build_figures.m 保持一致) =====
SPEC.panelCm = 2.928;   % 导出物理边长(cm) = A4正文宽 14.64cm / 5
SPEC.editCm  = 8;       % .fig 编辑画布边长(cm)
SPEC.dpi     = 600;     % 导出分辨率

codeDir = fileparts(mfilename('fullpath'));
rootDir = fullfile(codeDir, '..');
figSrcDir = fullfile(rootDir, 'figures', 'fig');
outDir    = fullfile(rootDir, 'figures');

if ~exist(figSrcDir, 'dir'), error('缺少 .fig 目录: %s', figSrcDir); end
if ~exist(outDir, 'dir'),    mkdir(outDir); end

files = dir(fullfile(figSrcDir, '*.fig'));
if isempty(files)
    error('未找到任何 .fig 文件: %s', figSrcDir);
end

scaleF = SPEC.editCm / SPEC.panelCm;   % 编辑版相对导出版的放大倍数
fprintf('共 %d 个 .fig, 按 %.3fcm 见方 / %d DPI 导出 TIFF\n\n', ...
    numel(files), SPEC.panelCm, SPEC.dpi);

for k = 1:numel(files)
    [~, nm, ~] = fileparts(files(k).name);
    try
        fig = openfig(fullfile(figSrcDir, files(k).name), 'invisible');
    catch ME
        warning('打开失败, 跳过 %s: %s', files(k).name, ME.message);
        continue;
    end

    % --- 等比还原: 字号 / 画布尺寸 ---
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
        fprintf('[%3d/%3d] %s -> 已导出\n', k, numel(files), nm);
    end
end

fprintf('\n✅ 导出完成 -> %s\n', outDir);
