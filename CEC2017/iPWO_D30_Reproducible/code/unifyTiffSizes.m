function unifyTiffSizes(figDir)
% UNIFYTIFFSIZES  统一 TIFF 图片裁剪尺寸
%   将 figDir 下的五联图(*_5Panels.tif)统一为同一像素尺寸,
%   将各面板子图(F*_[1-5]_*.tif)也统一为同一像素尺寸。
%   方法: 以组内最大宽高为基准, 对较小图片用白色背景居中补齐,
%   保证所有函数输出图片尺寸完全一致, 满足"统一切边"要求。
%   同时保留 330 DPI 元数据。

files = dir(fullfile(figDir, '*.tif'));
if isempty(files)
    fprintf('  未找到 TIFF 文件: %s\n', figDir);
    return;
end

% 分组: 五联图 / 子图
grp = zeros(numel(files), 1);
for k = 1:numel(files)
    if contains(files(k).name, '5Panels.tif')
        grp(k) = 1;
    else
        grp(k) = 2;
    end
end

for g = 1:2
    idx = find(grp == g);
    if isempty(idx), continue; end

    % 读取尺寸, 求组内最大宽高
    maxW = 0; maxH = 0;
    info = cell(numel(idx), 1);
    for j = 1:numel(idx)
        p = fullfile(figDir, files(idx(j)).name);
        try
            I = imfinfo(p);
            info{j} = I;
            maxW = max(maxW, I.Width);
            maxH = max(maxH, I.Height);
        catch
            info{j} = [];
        end
    end
    if maxW == 0, continue; end

    % 统一: 居中补齐到基准尺寸, 四周可补白(PAD)保证最宽图也留白边
    if g == 1
        PAD = 0;    % 五联图: 保持与 D10/D30 一致, 不加额外白边
    else
        PAD = 80;   % 单独面板: 四周补白(330 DPI 下约 17pt), 防止 ylabel 贴边
    end
    CW = maxW + 2*PAD;
    CH = maxH + 2*PAD;
    for j = 1:numel(idx)
        p = fullfile(figDir, files(idx(j)).name);
        try
            [A, map] = imread(p);
            if ~isempty(map)
                A = ind2rgb(A, map);
                A = uint8(round(A * 255));
            end
            if size(A, 3) == 1
                A = repmat(A, [1 1 3]);
            end
            [h, w, ~] = size(A);
            if h == CH && w == CW
                continue;   % 已符合
            end
            canvas = uint8(255 * ones(CH, CW, 3));
            y0 = floor((CH - h) / 2) + 1;
            x0 = floor((CW - w) / 2) + 1;
            canvas(y0:y0+h-1, x0:x0+w-1, :) = A;
            imwrite(canvas, p, 'Compression', 'lzw', ...
                'Resolution', [330 330]);
        catch ME
            warning('统一尺寸失败, 跳过 %s: %s', files(idx(j)).name, ME.message);
        end
    end
    if g == 1
        fprintf('  五联图统一尺寸: %d x %d px\n', CW, CH);
    else
        fprintf('  子图统一尺寸:   %d x %d px (含 %d px 补白)\n', CW, CH, PAD);
    end
end
end
