function make_extras()
    cd('D:\File\GPTTest\CEC2017_Experiment');
    addpath(pwd);
    addpath(fullfile(pwd, 'CEC2017TestD10', 'CEC2017Test'));

    %% --- ablation stats from 30-run summary ---
    T = readtable('ablation_results/summary_ablation.csv');
    D30 = T(T.Dim == 30, :);
    variants = {'iPWO','noECR','noOED','noNAS','PWO'};
    fprintf('=== Ablation D=30 mean-of-means ===\n');
    mm = zeros(1,5);
    ss = zeros(1,5);
    for v = 1:5
        col = D30.Mean(strcmp(D30.Variant, variants{v}));
        mm(v) = mean(col);
        ss(v) = std(col);
        fprintf('%s: mean-of-means=%.4g, std-of-means=%.4g\n', variants{v}, mm(v), ss(v));
    end
    for v = 2:4
        fprintf('%s degradation vs iPWO (mean): %.2f%%\n', variants{v}, (mm(v)-mm(1))/abs(mm(1))*100);
    end

    % bar chart for F4, F11, F21 at D=30
    fs = [4 11 21];
    fig = figure('Visible','off','Position',[100 100 1000 620]);
    for k = 1:3
        subplot(1,3,k);
        vals = zeros(5,1);
        for v = 1:5
            r = D30(D30.Func==fs(k) & strcmp(D30.Variant, variants{v}), :);
            vals(v) = r.Mean;
        end
        b = bar(vals, 'FaceColor', [0.18 0.45 0.75]);
        set(gca, 'XTickLabel', variants, 'FontSize', 9);
        title(sprintf('F%d', fs(k)));
        ylabel('Mean'); grid on;
    end
    exportgraphics(fig, 'ablation_F4_F11_F21.png', 'Resolution', 300);
    close(fig);

    %% --- SHADE runtime (5 runs) ---
    func = 30; dim = 30; pop = 30; maxFES = 10000*dim; runs = 5;
    [lb, ub, ~, ~] = Get_Functions_cec2017(func, dim);
    fobj = @(X) cec17_func(X', func);
    shadet = zeros(runs,1);
    for r = 1:runs
        rng(6000 + r*100);
        t0 = tic;
        iPWO_abl(pop, maxFES, lb, ub, dim, fobj, false, false, false, false);
        shadet(r) = toc(t0);
    end
    fprintf('SHADE avg runtime: %.3f s\n', mean(shadet));

    % combine with existing runtime_times.csv and regenerate chart
    if exist('runtime_times.csv','file')
        Rt = readtable('runtime_times.csv');
        algos = Rt.Properties.VariableNames;
        M = table2array(Rt);
        M2 = [M, shadet];
        allAlg = [algos, {'SHADE'}];
        writetable(array2table(M2,'VariableNames',allAlg), 'runtime_times_full.csv');
        avg = mean(M2,1);
        fig2 = figure('Visible','off','Position',[100 100 900 600]);
        bar(avg, 'FaceColor', [0.18 0.45 0.75]);
        set(gca,'XTickLabel',allAlg,'FontSize',12);
        ylabel('Average CPU time (s)');
        title(sprintf('CPU time on F30 (D=30), MaxFEs=%d', maxFES));
        grid on;
        exportgraphics(fig2, 'runtime_times.png', 'Resolution', 300);
        close(fig2);
        for a = 1:numel(allAlg)
            fprintf('%s: %.3f s\n', allAlg{a}, avg(a));
        end
    end
end
