function I2 = downscaleAvg(I, outPx)
% DOWNSCALE_AVG  area-average downscaling (integral-image impl, no toolbox), high-quality antialiased downsampling
%   I2 = downscaleAvg(I, outPx)  scale RGB/grayscale image proportionally to outPx x outPx

[H, W, C] = size(I);
if H == outPx && W == outPx
    I2 = I;
    return;
end
ex = round(linspace(0, W, outPx + 1));
ey = round(linspace(0, H, outPx + 1));
ax_ = diff(ex);               % each block width
I2 = zeros(outPx, outPx, C, 'uint8');
for c = 1:C
    P = cumsum(cumsum(double(I(:,:,c)), 1), 2);   % double to avoid precision loss
    P = [zeros(1, W + 1); [zeros(H, 1), P]];      % (H+1) x (W+1)
    top = P(ey(1:end-1) + 1, :);
    bot = P(ey(2:end) + 1, :);
    s = bot(:, ex(2:end) + 1) - top(:, ex(2:end) + 1) - ...
        bot(:, ex(1:end-1) + 1) + top(:, ex(1:end-1) + 1);
    area = (ey(2:end) - ey(1:end-1)).' * ax_;   % outer product: each block height x width
    I2(:, :, c) = uint8(round(s ./ max(area, 1)));
end
end
