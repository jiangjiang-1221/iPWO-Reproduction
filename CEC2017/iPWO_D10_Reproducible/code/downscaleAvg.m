function I2 = downscaleAvg(I, outPx)
% DOWNSCALE_AVG  面积平均缩放(积分图实现, 无需工具箱), 高质量抗锯齿下采样
%   I2 = downscaleAvg(I, outPx)  把 RGB/灰度图等比缩到 outPx x outPx

[H, W, C] = size(I);
if H == outPx && W == outPx
    I2 = I;
    return;
end
ex = round(linspace(0, W, outPx + 1));
ey = round(linspace(0, H, outPx + 1));
ax_ = diff(ex);               % 各块宽度
I2 = zeros(outPx, outPx, C, 'uint8');
for c = 1:C
    P = cumsum(cumsum(double(I(:,:,c)), 1), 2);   % double 防精度损失
    P = [zeros(1, W + 1); [zeros(H, 1), P]];      % (H+1) x (W+1)
    top = P(ey(1:end-1) + 1, :);
    bot = P(ey(2:end) + 1, :);
    s = bot(:, ex(2:end) + 1) - top(:, ex(2:end) + 1) - ...
        bot(:, ex(1:end-1) + 1) + top(:, ex(1:end-1) + 1);
    area = (ey(2:end) - ey(1:end-1)).' * ax_;   % 外积: 各块高 x 宽
    I2(:, :, c) = uint8(round(s ./ max(area, 1)));
end
end
