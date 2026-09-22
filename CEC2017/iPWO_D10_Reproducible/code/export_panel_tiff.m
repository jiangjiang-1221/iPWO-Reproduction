function export_panel_tiff(fig, tifPath, tgtCm, dpi)
% EXPORT_PANEL_TIFF  export panel figure to TIFF per paper spec (enlarged render + area-average downscale)
%
%   rendering a small canvas directly is unstable in layout/text metrics, so:
%     1) enlarge figure logical size by K=4 (font/linewidth etc. scaled up too), stable layout metrics
%     2) print -r600 high-resolution rasterization
%     3) area-average downscale to exactly 692 x 692 (= tgtCm @ dpi)
%     4) imwrite writes the correct DPI tag
%
%   inputs:
%     fig    : completed figure (logical size = tgtCm*K, do not modify)
%     tifPath: output TIFF path
%     tgtCm  : target physical side length cm (2.928)
%     dpi    : target DPI tag (600)

K = 4;                        % magnification (consistent with iPWO_build_figures)
renderCm = tgtCm * K;         % render canvas side length
outPx = round(tgtCm / 2.54 * dpi);   % output pixels 692

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

% write via Tiff object, precisely control DPI tag (600) + LZW lossless compression
% (directly use TIFF standard values: RGB=2, LZW=5, INCH=2, Chunky=1)
t = Tiff(tifPath, 'w');
t.setTag('ImageLength', size(I2, 1));
t.setTag('ImageWidth', size(I2, 2));
t.setTag('Photometric', 2);                 % RGB (must precede BitsPerSample)
t.setTag('BitsPerSample', 8);               % 8 bits per sample
t.setTag('SamplesPerPixel', 3);
t.setTag('Compression', 5);                 % LZW lossless compression
t.setTag('PlanarConfiguration', 1);         % Chunky
t.setTag('XResolution', dpi);
t.setTag('YResolution', dpi);
t.setTag('ResolutionUnit', 2);              % inch
t.setTag('Software', 'MATLAB');
t.write(I2);
t.close();
end

function ifexist_delete(f)
if exist(f, 'file'), delete(f); end
end
