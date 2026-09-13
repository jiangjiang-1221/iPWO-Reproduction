function run_scaling_D100_checkpoint()
% run_scaling_D100_checkpoint - Resumable D=100 scalability run.
% Uses parfeval so the client saves one checkpoint .mat per function;
% if the session is interrupted, re-running skips finished functions.

    script_dir = fileparts(mfilename('fullpath'));
    if isempty(script_dir), script_dir = pwd; end
    root = fileparts(script_dir);
    cd(script_dir); addpath(script_dir);

    outdir = fullfile(root, 'data', 'scaling_iPWO_results');
    ckdir = fullfile(outdir, 'checkpoints_D100');
    if ~exist(ckdir, 'dir'), mkdir(ckdir); end

    funcs = [1, 4, 5, 6, 7, 8, 9, 10, 15, 21];
    dim = 100; runs = 51; pop = 50; nVar = 2; Lcurve = 1000;

    pool = gcp('nocreate');
    if isempty(pool), pool = parpool('local', 4); end
    pctRunOnAll(sprintf('addpath(''%s'')', script_dir));

    completed = false(size(funcs));
    while any(~completed)
        futures = {};
        idxs = [];
        for k = 1:numel(funcs)
            if completed(k), continue; end
            f = funcs(k);
            ckfile = fullfile(ckdir, sprintf('results_scaling_D100_f%d.mat', f));
            if exist(ckfile, 'file')
                completed(k) = true;
                fprintf('  D100 F%d already done\n', f);
                continue;
            end
            fut = parfeval(pool, @run_one_task, 1, f, dim, runs, nVar, Lcurve, pop);
            futures{end + 1} = fut; %#ok<AGROW>
            idxs(end + 1) = k; %#ok<AGROW>
        end
        if isempty(futures)
            break;
        end
        for q = 1:numel(futures)
            try
                [~, s] = fetchNext(futures{q});
                k = idxs(q);
                f = funcs(k);
                ckfile = fullfile(ckdir, sprintf('results_scaling_D100_f%d.mat', f));
                save(ckfile, 's', 'dim', 'f', 'runs', 'pop');
                completed(k) = true;
                fprintf('  D100 F%d checkpoint saved\n', f);
            catch ME
                fprintf('  D100 F%d failed: %s\n', funcs(idxs(q)), ME.message);
            end
        end
    end

    fprintf('D100 checkpoint phase done\n');
end

function s = run_one_task(f, dim, runs, nVar, Lcurve, pop)
    [lb, ub, ~, ~] = Get_Functions_cec2017(f, dim);
    fobj = @(X) cec17_func(X', f);
    maxFES = 10000 * dim;

    S = zeros(runs, nVar);
    C = zeros(Lcurve, nVar);
    for r = 1:runs
        seed = 3000000 + dim * 10000 + f * 100 + r;
        for v = 1:nVar
            rng(seed);
            sc = inf; cg = [];
            if v == 1
                [sc, ~, cg] = iPWO_abl(pop, maxFES, lb, ub, dim, fobj, true, true, true, true);
            else
                [sc, ~, cg] = PWO_vec(pop, maxFES, lb, ub, dim, fobj);
            end
            S(r, v) = sc;
            cg = cg(:);
            if isempty(cg), cg = sc; end
            cc = interp1((1:numel(cg))', cg, linspace(1, numel(cg), Lcurve)', 'linear', 'extrap');
            C(:, v) = C(:, v) + cc;
        end
    end
    C = C ./ runs;
    s = struct('f', f, 'S', S, 'C', C, 'med', median(S, 1), 'mean', mean(S, 1));
end
