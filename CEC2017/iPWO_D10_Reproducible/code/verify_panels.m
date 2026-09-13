function res = verify_panels(figDir)
% VERIFY_PANELS  校验目录下 TIFF 面板是否满足论文出版规格
%
%   检查项:
%     1) 像素尺寸是否为 692 x 692 (2.928cm @ 600 DPI)
%     2) 分辨率标记是否为 600 DPI
%     3) 四边留白(margin)是否充足 -> 判断坐标标签是否被裁切
%     4) 是否为正方形
%
%   用法:
%     verify_panels('D:\...\figures');          % 指定目录
%     verify_panels();                          % 默认 <rootDir>/figures
%     res = verify_panels(...);                 % 返回结构体数组

if nargin < 1 || isempty(figDir)
    codeDir = fileparts(mfilename('fullpath'));
    rootDir = fullfile(codeDir, '..');
    figDir = fullfile(rootDir, 'figures');
end

EXPECT_PX  = 692;   % 2.928cm @ 600 DPI
EXPECT_DPI = 600;
MARGIN_MIN = 4;     % 最小可接受留白(px @600DPI), 低于此值视为标签可能被裁

d = dir(fullfile(figDir, '*.tif'));
if isempty(d)
    error('目录下未找到 TIFF: %s', figDir);
end

fprintf('校验目录: %s\n', figDir);
fprintf('共 %d 个 TIFF\n\n', numel(d));
fprintf('%-44s %-11s %5s | %4s %4s %4s %4s | %s\n', ...
    'file', 'size', 'DPI', 'L', 'R', 'T', 'B', 'status');
fprintf('%s\n', repmat('-', 1, 96));

nBad = 0;
nWarn = 0;
res = struct();

for i = 1:numel(d)
    p = fullfile(figDir, d(i).name);
    info = imfinfo(p);
    I = imread(p);
    if size(I, 3) == 3
        G = rgb2gray(I);
    else
        G = I;
    end
    mask = G < 250;                       % 非白像素(文字/线条)
    [rows, cols] = find(mask);
    if isempty(rows)
        L = info.Width; R = info.Width; T = info.Height; B = info.Height;
    else
        L = min(cols) - 1;
        R = info.Width  - max(cols);
        T = min(rows) - 1;
        B = info.Height - max(rows);
    end

    okSize = (info.Width == EXPECT_PX) && (info.Height == EXPECT_PX);
    okDpi  = (round(info.XResolution) == EXPECT_DPI) && ...
             (round(info.YResolution) == EXPECT_DPI);
    mm = min([L R T B]);
    okMargin = mm >= MARGIN_MIN;

    if ~okSize || ~okDpi
        status = 'FAIL(size/dpi)';
        nBad = nBad + 1;
    elseif ~okMargin
        status = 'WARN(crop?)';
        nWarn = nWarn + 1;
    else
        status = 'OK';
    end

    fprintf('%-44s %-11s %5d | %4d %4d %4d %4d | %s\n', ...
        d(i).name, sprintf('%dx%d', info.Width, info.Height), ...
        round(info.XResolution), L, R, T, B, status);

    res(i).name   = d(i).name;
    res(i).width  = info.Width;
    res(i).height = info.Height;
    res(i).dpi    = round(info.XResolution);
    res(i).margin = [L R T B];
    res(i).status = status;
end

fprintf('%s\n', repmat('-', 1, 96));
fprintf('合计 %d 个 | FAIL %d | WARN %d | OK %d\n', ...
    numel(d), nBad, nWarn, numel(d) - nBad - nWarn);

if nBad == 0 && nWarn == 0
    fprintf('✅ 全部通过: 尺寸 %dx%d @ %d DPI, 四边留白均 >= %dpx (标签完整)\n', ...
        EXPECT_PX, EXPECT_PX, EXPECT_DPI, MARGIN_MIN);
else
    fprintf('⚠ 存在异常项, 请检查上表 FAIL/WARN 行\n');
end
end
