function unifyTiffSizes(figDir)
% UNIFYTIFFSIZES  unify TIFF crop size
%   unify five-panel figures (*_5Panels.tif) under figDir to the same pixel size,
%   and unify each panel sub-figure (F*_[1-5]_*.tif) to the same pixel size.
%   method: use the max width/height in the group as baseline, pad smaller images centered on white background,
%   ensure all functions output identical image size, meeting the 'unified crop' requirement.
%   also keep 330 DPI metadata.

files = dir(fullfile(figDir, '*.tif'));
if isempty(files)
    fprintf('  no TIFF file found: %s\n', figDir);
    return;
end

% group: five-panel / sub-panel
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

    % read sizes, get max width/height in group
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

    % unify: center-pad to maxW x maxH
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
            if h == maxH && w == maxW
                continue;   % already matches
            end
            canvas = uint8(255 * ones(maxH, maxW, 3));
            y0 = floor((maxH - h) / 2) + 1;
            x0 = floor((maxW - w) / 2) + 1;
            canvas(y0:y0+h-1, x0:x0+w-1, :) = A;
            imwrite(canvas, p, 'Compression', 'lzw', ...
                'Resolution', [330 330]);
        catch ME
            warning('size unification failed, skip %s: %s', files(idx(j)).name, ME.message);
        end
    end
    if g == 1
        fprintf('  five-panel unified size: %d x %d px\n', maxW, maxH);
    else
        fprintf('  sub-panel unified size:   %d x %d px\n', maxW, maxH);
    end
end
end
