function make_preview(figDir, scale)
% MAKE_PREVIEW  把目录下 TIFF 转成放大 PNG, 便于目视检查标签是否被裁
%   make_preview(figDir, scale)   scale 默认 2 (最近邻放大, 不依赖工具箱)

if nargin < 1 || isempty(figDir)
    codeDir = fileparts(mfilename('fullpath'));
    rootDir = fullfile(codeDir, '..');
    figDir = fullfile(rootDir, 'figures');
end
if nargin < 2 || isempty(scale), scale = 2; end

outDir = fullfile(figDir, '_preview');
if ~exist(outDir, 'dir'), mkdir(outDir); end

d = dir(fullfile(figDir, '*.tif'));
for i = 1:numel(d)
    I = imread(fullfile(figDir, d(i).name));
    [H, W, ~] = size(I);
    % 最近邻放大(避免依赖 Image Processing Toolbox)
    I2 = I(ceil((1:(H*scale)) / scale), ceil((1:(W*scale)) / scale), :);
    [~, nm, ~] = fileparts(d(i).name);
    imwrite(I2, fullfile(outDir, [nm '.png']));
end
fprintf('已生成 %d 张预览 PNG (x%d) -> %s\n', numel(d), scale, outDir);
end
