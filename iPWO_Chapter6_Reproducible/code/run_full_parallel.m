function run_full_parallel()
% run_full_parallel - Run the three heavy Chapter-6 experiments with one
% local parallel pool. Sensitivity and runtime are fast and can be run via
% run_all_ch6 separately.

    script_dir = fileparts(mfilename('fullpath'));
    if isempty(script_dir), script_dir = pwd; end
    cd(script_dir); addpath(script_dir);

    pool = gcp('nocreate');
    if isempty(pool)
        pool = parpool('local', 8);
    end
    pctRunOnAll(sprintf('addpath(''%s'')', script_dir));

    fprintf('===== Component ablation =====\n');
    run_ablation([10 30], [1, 3:30], 51, 50, '', true);

    fprintf('===== Rally ablation =====\n');
    run_ablation_rally([1, 3:30], 51, 50, '', true);

    fprintf('===== Dimension scalability =====\n');
    run_scaling_iPWO([1, 4, 5, 6, 7, 8, 9, 10, 15, 21], [30, 50, 100], 51, 50, '', true);

    fprintf('===== ALL HEAVY CHAPTER-6 EXPERIMENTS DONE =====\n');
end
