function aggregate_ch6()
% aggregate_ch6 - Merge chunked ablation/rally raw .mat files into the
% final per-dimension raw data + Friedman-style average-rank figures + CSVs.
% Run AFTER all chunked background jobs (run_ablation / run_ablation_rally
% with a non-empty 'tag') have finished. Scaling/sensitivity/runtime are
% produced directly by their own single scripts (no chunking needed).

    script_dir = fileparts(mfilename('fullpath'));
    if isempty(script_dir), script_dir = pwd; end
    root = fileparts(script_dir);
    cd(script_dir); addpath(script_dir);

    %% ===== Component ablation =====
    adir = fullfile(root, 'data', 'ablation_results');
    fl = dir(fullfile(adir, 'results_ablation_D30_*.mat'));
    if isempty(fl), error('No component-ablation chunk mats found in %s', adir); end
    fds = []; Sds = []; Cds = [];
    for i = 1:numel(fl)
        m = load(fullfile(adir, fl(i).name));
        fds = [fds, m.fd(:).'];
        Sds = cat(3, Sds, m.Sd);
        Cds = cat(3, Cds, m.Cd);
    end
    [fds, ord] = sort(fds);
    Sd = Sds(:,:,ord); Cd = Cds(:,:,ord);
    variants = m.variants; runs = m.runs; pop = m.pop; d = 30;
    save(fullfile(adir, 'results_ablation_D30.mat'), 'd','fd','Sd','Cd','variants','runs','pop');
    draw_rank(d, fds, Sd, variants, adir, fullfile(root, 'figures', 'ablation_results'), 'avg_rank_D30.tif');
    nVar = size(Sd,2); nF = size(Sd,3);
    mean_per_func = squeeze(mean(Sd,1));
    ranks = nan(nF, nVar);
    for f = 1:nF, [~,o] = sort(mean_per_func(:,f)); ranks(f,o) = 1:nVar; end
    ar = mean(ranks, 1, 'omitnan');
    T = array2table(ranks, 'VariableNames', cellstr(variants)); T.Func = fds(:);
    writetable(T, fullfile(adir, 'ranks_D30.csv'));
    fid = fopen(fullfile(adir, 'avg_rank_D30.txt'),'w');
    for v = 1:nVar, fprintf(fid, '%s\t%.4f\n', variants{v}, ar(v)); end
    fclose(fid);
    cf = dir(fullfile(adir, 'summary_ablation_*.csv'));
    Tall = [];
    for i = 1:numel(cf)
        Tall = [Tall; readtable(fullfile(adir, cf(i).name))];
    end
    Tall = sortrows(Tall, 'Func');
    writetable(Tall, fullfile(adir, 'summary_ablation.csv'));
    fprintf('Component ablation aggregated: %d funcs, avg_rank = [', nF);
    fprintf('%.3f ', ar); fprintf('] (iPWO first)\n');

    %% ===== Rally ablation =====
    rdir = fullfile(root, 'data', 'ablation_rally_results');
    fl = dir(fullfile(rdir, 'results_rally_D30_*.mat'));
    if isempty(fl), error('No rally-ablation chunk mats found in %s', rdir); end
    fds = []; Sds = []; Cds = [];
    for i = 1:numel(fl)
        m = load(fullfile(rdir, fl(i).name));
        fds = [fds, m.fnames(:).'];
        Sds = cat(3, Sds, m.Sall);
        Cds = cat(3, Cds, m.Call);
    end
    [fds, ord] = sort(fds);
    Sall = Sds(:,:,ord); Call = Cds(:,:,ord);
    variants = m.variants; runs = m.runs; pop = m.pop; dim = 30;
    save(fullfile(rdir, 'results_rally_D30.mat'), 'dim','fnames','Sall','Call','variants','runs','pop');
    draw_rank(dim, fds, Sall, variants, rdir, fullfile(root, 'figures', 'ablation_rally_results'), 'avg_rank.tif');
    nVar = size(Sall,2); nF = size(Sall,3);
    mean_per_func = squeeze(mean(Sall,1));
    ranks = nan(nF, nVar);
    for f = 1:nF, [~,o] = sort(mean_per_func(:,f)); ranks(f,o) = 1:nVar; end
    ar = mean(ranks, 1, 'omitnan');
    T = array2table(ranks, 'VariableNames', cellstr(variants)); T.Func = fds(:);
    writetable(T, fullfile(rdir, 'ranks.csv'));
    fid = fopen(fullfile(rdir, 'avg_rank.txt'),'w');
    for v = 1:nVar, fprintf(fid, '%s\t%.4f\n', variants{v}, ar(v)); end
    fclose(fid);
    cf = dir(fullfile(rdir, 'summary_rally_*.csv'));
    Tall = [];
    for i = 1:numel(cf)
        Tall = [Tall; readtable(fullfile(rdir, cf(i).name))];
    end
    Tall = sortrows(Tall, 'Func');
    writetable(Tall, fullfile(rdir, 'summary_rally.csv'));
    fprintf('Rally ablation aggregated: %d funcs, avg_rank = [', nF);
    fprintf('%.3f ', ar); fprintf('] (iPWO first)\n');

    fprintf('AGGREGATION DONE\n');
end

function draw_rank(dim, funcs, Sd, variants, outdir, figsdir, fname)
    nVar = size(Sd, 2);
    nF = size(Sd, 3);
    mean_per_func = squeeze(mean(Sd, 1));
    ranks = nan(nF, nVar);
    for f = 1:nF
        [~, ord] = sort(mean_per_func(:, f));
        ranks(f, ord) = 1:nVar;
    end
    avg_rank = mean(ranks, 1, 'omitnan');
    fig = figure('Visible', 'off', 'Position', [100 100 900 620]);
    bar(avg_rank, 'FaceColor', [0.18 0.45 0.75]);
    set(gca, 'XTickLabel', variants);
    ylabel('Average Rank (lower is better)');
    title(sprintf('Friedman-style Average Rank - D=%d', dim));
    grid on;
    ylim([0 nVar + 1]);
    if ~exist(figsdir, 'dir'), mkdir(figsdir); end
    ch6_print(fig, fullfile(figsdir, fname));
end
