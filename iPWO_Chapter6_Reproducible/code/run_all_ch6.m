% run_all_ch6.m
% =====================================================================
% one-click reproduction of all Chapter-6 figures and data (ablation study and mechanism validation).
% all figures are TIFF / 330 DPI / 18pt font (see ch6_print.m); figure size is uniformly 11x7.5 inch.
% data (.mat / .csv) and each .tif are saved in this folder to ensure reproducibility.
%
% usage:
%   cd to this code/ directory, then run in MATLAB:
%       run_all_ch6
%   or run a single section (note parameter order in each function help):
%       run_ablation(dims, funcs, runs, pop)        % component ablation -> Table 3
%       run_ablation_rally(funcs, runs, pop)        % Rally ablation -> Table 4 (D=30)
%       run_sensitivity()                            % parameter sensitivity theta-rho
%       run_scaling_iPWO(funcs, dims, runs, pop)     % dimensional scalability D=30/50/100
%       run_runtime()                                % runtime efficiency
%
% default parameters (matching the paper): component ablation / Rally ablation runs=51, MaxFEs=10000*D,
% fixed random seed; parameter sensitivity 6x6 grid x 5 runs; scalability runs=51; runtime 5 runs.
% =====================================================================
script_dir = fileparts(mfilename('fullpath'));
cd(script_dir); addpath(script_dir);

fprintf('\n===== [1/5] component ablation (Table 3: Friedman mean rank) =====\n');
run_ablation();

fprintf('\n===== [2/5] Rally ablation (Table 4: iPWO vs SHADE / SHADE+ECR+OED / PWO @ D=30) =====\n');
run_ablation_rally();

fprintf('\n===== [3/5] parameter sensitivity (theta-rho grid) =====\n');
run_sensitivity();

fprintf('\n===== [4/5] dimensional scalability (D=30/50/100, iPWO vs PWO) =====\n');
run_scaling_iPWO();

fprintf('\n===== [5/5] runtime efficiency =====\n');
run_runtime();

fprintf('\nALL CHAPTER-6 EXPERIMENTS DONE. figures = TIFF/330dpi/18pt; data in *_results subdirs and .mat/.csv in this dir.\n');
