function make_preview(figDir, scale)
% MAKE_PREVIEW  convert directory TIFFs to enlarged PNGs, for visually checking label cropping
%   make_preview(figDir, scale)  scale default 2 (nearest-neighbor upscale, no toolbox needed)

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
    % nearest-neighbor upscale (avoid depending on Image Processing Toolbox)
    I2 = I(ceil((1:(H*scale)) / scale), ceil((1:(W*scale)) / scale), :);
    [~, nm, ~] = fileparts(d(i).name);
    imwrite(I2, fullfile(outDir, [nm '.png']));
end
fprintf('generated %d preview PNGs (x%d) -> %s\n', numel(d), scale, outDir);
end
