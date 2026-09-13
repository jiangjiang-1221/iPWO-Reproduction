function export_panel_tiff(fig, tifPath, tgtCm, dpi)
% EXPORT_PANEL_TIFF  面板图按论文规格导出 TIFF(放大渲染+面积平均缩放)
%
%   小画布直接 -batch 渲染时布局/文字度量不稳定, 故:
%     1) figure 逻辑尺寸放大 K=4 倍(字号/线宽等已同步放大), 布局度量稳定
%     2) print -r600 高分辨率光栅化
%     3) 面积平均缩放到精确 692 x 692 (= tgtCm @ dpi)
%     4) imwrite 写入正确的 DPI 标记
%
%   输入:
%     fig    : 已绘制完成的 figure(逻辑尺寸 = tgtCm*K, 勿改动)
%     tifPath: 输出 TIFF 路径
%     tgtCm  : 目标物理边长 cm (2.928)
%     dpi    : 目标 DPI 标记 (600)

K = 4;                        % 放大倍数(与 iPWO_build_figures 一致)
renderCm = tgtCm * K;         % 渲染画布边长
outPx = round(tgtCm / 2.54 * dpi);   % 输出像素 692

fig.Units = 'centimeters';
fig.PaperUnits = 'centimeters';
fig.PaperSize = [renderCm renderCm];
fig.PaperPosition = [0 0 renderCm renderCm];
fig.PaperPositionMode = 'manual';

tmpFile = [tempname '.tif'];
cleanup = onCleanup(@() ifexist_delete(tmpFile));
print(fig, tmpFile, '-dtiff', sprintf('-r%d', dpi));

I = imread(tmpFile);
I2 = downscaleAvg(I, outPx);

% 用 Tiff 对象写入, 精确控制 DPI 标记(600) + LZW 无损压缩
% (直接使用 TIFF 标准数值: RGB=2, LZW=5, INCH=2, Chunky=1)
t = Tiff(tifPath, 'w');
t.setTag('ImageLength', size(I2, 1));
t.setTag('ImageWidth', size(I2, 2));
t.setTag('Photometric', 2);                 % RGB (须先于 BitsPerSample)
t.setTag('BitsPerSample', 8);               % 每样本 8 位
t.setTag('SamplesPerPixel', 3);
t.setTag('Compression', 5);                 % LZW 无损压缩
t.setTag('PlanarConfiguration', 1);         % Chunky
t.setTag('XResolution', dpi);
t.setTag('YResolution', dpi);
t.setTag('ResolutionUnit', 2);              % 英寸
t.setTag('Software', 'MATLAB');
t.write(I2);
t.close();
end

function ifexist_delete(f)
if exist(f, 'file'), delete(f); end
end
