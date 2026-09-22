function unifyTiffSizes(figDir)
% UNIFYTIFFSIZES  unify TIFF image crop size
%   unify five-panel figures (*_5Panels.tif) under figDir to the same pixel size,
%   also unify each panel sub-figure (F*_[1-5]_*.tif) to the same pixel size.
%   method: take the max width/height in the group as reference, pad smaller images with centered white background,
%   ensure all function output images have identical size, meeting the "unified crop" requirement.
%   also keep 330 DPI metadata.

files = dir(fullfile(figDir, '*.tif'));
if isempty(files)
    fprintf('  No TIFF file found: %s\n', figDir);
    return;
end

% group: five-panel figure / sub-panel
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

    % read sizes, find max width/height in group
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

    % unify: center-pad to reference size; padding (PAD) keeps white margin on the widest image
    if g == 1
        PAD = 0;    % five-panel figure: keep consistent with D10/D30, no extra white border
    else
        PAD = 80;   % single panel: white border around (about 17 pt at 330 DPI) to keep ylabel off the edge
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
                continue;   % already matches
            end
            canvas = uint8(255 * ones(CH, CW, 3));
            y0 = floor((CH - h) / 2) + 1;
            x0 = floor((CW - w) / 2) + 1;
            canvas(y0:y0+h-1, x0:x0+w-1, :) = A;
            imwrite(canvas, p, 'Compression', 'lzw', ...
                'Resolution', [330 330]);
        catch ME
            warning('Failed to unify size, skipping %s: %s', files(idx(j)).name, ME.message);
        end
    end
    if g == 1
        fprintf('  Five-panel figure unified size: %d x %d px\n', CW, CH);
    else
        fprintf('  Sub-panel unified size:   %d x %d px (%d px padding)\n', CW, CH, PAD);
    end
end
end
