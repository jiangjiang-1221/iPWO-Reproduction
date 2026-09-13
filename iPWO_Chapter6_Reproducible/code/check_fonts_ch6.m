function check_fonts_ch6()
% check_fonts_ch6 - Object-level font audit for Chapter-6 figures.
% Rebuilds one figure of each type, applies ch6_print (keepOpen), then
% enumerates EVERY handle in the figure tree and reports all FontName /
% FontSize values found. Any font other than 'Times New Roman' is listed
% as an offender with its graphics object type.

    script_dir = fileparts(mfilename('fullpath'));
    root = fileparts(script_dir);
    cd(script_dir); addpath(script_dir);
    tmpdir = fullfile(root, 'figures', '_font_check_tmp');
    if ~exist(tmpdir, 'dir'), mkdir(tmpdir); end
    variants = {'iPWO','noECR','noOED','noNAS','PWO'};
    offenders = {};

    %% 1) convergence
    fig = figure('Visible','off','Position',[100 100 1200 780]);
    colors = lines(numel(variants)); hold on;
    for v = 1:numel(variants)
        semilogy((1:100)', 100./((1:100)'.^0.5).*ones(100,1)*(v+1), 'LineWidth', 1.6, 'Color', colors(v,:));
    end
    hold off; grid on;
    xlabel('Iteration'); ylabel('Best Score');
    title('Convergence - D=30, F10');
    legend(variants, 'Location', 'northeast', 'Interpreter', 'none');
    offenders = [offenders; audit_fig(fig, 'conv', tmpdir)];

    %% 2) boxplot
    fig = figure('Visible','off','Position',[100 100 1000 720]);
    boxplot(rand(51,5).*1e3 + 1, 'Labels', variants);
    set(gca, 'YScale', 'log'); grid on;
    ylabel('Best Score'); title('Boxplot - D=30, F5');
    offenders = [offenders; audit_fig(fig, 'box', tmpdir)];

    %% 3) average rank bar
    fig = figure('Visible','off','Position',[100 100 900 620]);
    bar([1.2 2.5 3.1 3.8 4.4], 'FaceColor', [0.18 0.45 0.75]);
    set(gca, 'XTickLabel', variants);
    ylabel('Average Rank (lower is better)');
    title('Friedman-style Average Rank - D=30'); grid on; ylim([0 6]);
    offenders = [offenders; audit_fig(fig, 'rank', tmpdir)];

    %% 4) runtime bar
    fig = figure('Visible','off','Position',[100 100 900 620]);
    bar([12 34 45 56 67]);
    set(gca, 'XTickLabel', {'iPWO','PWO','GWO','PSO','DE'});
    ylabel('Average CPU time (s)');
    title('Average runtime per MTA-PP solve (5 runs)'); grid on;
    offenders = [offenders; audit_fig(fig, 'runtime', tmpdir)];

    %% 5) sensitivity heatmap (colorbar + greek text)
    fig = figure('Visible','off','Position',[100 100 820 680]);
    imagesc(1:8, 1:8, rand(8));
    colorbar; xlabel('\rho'); ylabel('\theta');
    title('Sensitivity of iPWO to \theta and \rho');
    set(gca, 'XTick', 1:8, 'YTick', 1:8); colormap(parula); axis xy;
    offenders = [offenders; audit_fig(fig, 'sensitivity', tmpdir)];

    %% summary
    fprintf('\n===== FONT AUDIT SUMMARY =====\n');
    if isempty(offenders)
        fprintf('ALL text objects use Times New Roman. NO offenders found.\n');
    else
        fprintf('%d NON-TNR object(s) found:\n', numel(offenders));
        for i = 1:numel(offenders)
            fprintf('  [%s] %s\n', offenders{i}{1}, offenders{i}{2});
        end
    end
    rmdir(tmpdir, 's');
end

function offenders = audit_fig(fig, tag, tmpdir)
    % apply the exact export styling without closing the figure
    ch6_print(fig, fullfile(tmpdir, [tag '_audit.tif']), true);
    offenders = {};
    fonts = containers.Map('KeyType', 'char', 'ValueType', 'any');
    hs = findall(fig);
    for i = 1:numel(hs)
        h = hs(i);
        try
            fn = h.FontName;
            tp = h.Type;
            if ~fonts.isKey(fn)
                fonts(fn) = {tp};
            else
                prev = fonts(fn);
                if ~any(strcmp(prev, tp))
                    fonts(fn) = [prev, {tp}];
                end
            end
            if ~strcmpi(fn, 'Times New Roman')
                offenders = [offenders; {{sprintf('%s (FontName=%s)', tp, fn), ''}}];
            end
        catch
            % handle has no FontName property (lines, patches, ...) - skip
        end
    end
    fnames = fonts.keys;
    fprintf('[%s] distinct FontName values:\n', tag);
    for k = 1:numel(fnames)
        tps = fonts(fnames{k});
        fprintf('    "%s"  <- %s\n', fnames{k}, strjoin(tps, ', '));
    end
    close(fig);
end
