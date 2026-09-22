function res = verify_panels(figDir)
% VERIFY_PANELS  verify directory TIFF panels meet publication spec
%
%   checks:
%     1) pixel size is 692 x 692 (2.928cm @ 600 DPI)
%     2) resolution tag is 600 DPI
%     3) four-side margin sufficient -> judge whether axis labels are cropped
%     4) is square
%
%   usage:
%     verify_panels('D:\...\figures');          % specify directory
%     verify_panels();                          % default <rootDir>/figures
%     res = verify_panels(...);                 % return struct array

if nargin < 1 || isempty(figDir)
    codeDir = fileparts(mfilename('fullpath'));
    rootDir = fullfile(codeDir, '..');
    figDir = fullfile(rootDir, 'figures');
end

EXPECT_PX  = 692;   % 2.928cm @ 600 DPI
EXPECT_DPI = 600;
MARGIN_MIN = 4;     % min acceptable margin (px @600DPI); below this labels may be cropped

d = dir(fullfile(figDir, '*.tif'));
if isempty(d)
    error('no TIFF found in directory: %s', figDir);
end

fprintf('verifying directory: %s\n', figDir);
fprintf('%d TIFFs total\n\n', numel(d));
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
    mask = G < 250;                       % non-white pixels (text/lines)
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
fprintf('total %d | FAIL %d | WARN %d | OK %d\n', ...
    numel(d), nBad, nWarn, numel(d) - nBad - nWarn);

if nBad == 0 && nWarn == 0
    fprintf(' all passed: size %dx%d @ %d DPI, all four margins >= %dpx (labels intact)\n', ...
        EXPECT_PX, EXPECT_PX, EXPECT_DPI, MARGIN_MIN);
else
    fprintf(' anomalies found, check FAIL/WARN rows above\n');
end
end
