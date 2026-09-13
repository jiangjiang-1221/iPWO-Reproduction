% run_all_ch6.m
% =====================================================================
% 一键复现论文第六章「消融实验与机制验证」全部图表与数据。
% 所有图均为 TIFF / 330 DPI / 字体 18pt（见 ch6_print.m），图幅统一 11x7.5 inch。
% 数据（.mat / .csv）与各 .tif 一同保存在本文件夹下，保证可复现。
%
% 用法：
%   cd 到本 code/ 目录后，在 MATLAB 中运行：
%       run_all_ch6
%   或单独运行某一节（注意参数顺序见各函数帮助）：
%       run_ablation(dims, funcs, runs, pop)        % 组件消融 -> Table 3
%       run_ablation_rally(funcs, runs, pop)        % Rally 消融 -> Table 4 (D=30)
%       run_sensitivity()                            % 参数敏感性 theta-rho
%       run_scaling_iPWO(funcs, dims, runs, pop)     % 维度可扩展性 D=30/50/100
%       run_runtime()                                % 运行效率
%
% 默认参数（与论文一致）：组件消融 / Rally 消融 runs=51，MaxFEs=10000*D，
% 固定随机种子；参数敏感性 6x6 网格 x 5 runs；可扩展性 runs=51；运行效率 5 runs。
% =====================================================================
script_dir = fileparts(mfilename('fullpath'));
cd(script_dir); addpath(script_dir);

fprintf('\n===== [1/5] 组件消融 (Table 3: Friedman 平均秩) =====\n');
run_ablation();

fprintf('\n===== [2/5] Rally 消融 (Table 4: iPWO vs SHADE / SHADE+ECR+OED / PWO @ D=30) =====\n');
run_ablation_rally();

fprintf('\n===== [3/5] 参数敏感性 (theta-rho 网格) =====\n');
run_sensitivity();

fprintf('\n===== [4/5] 维度可扩展性 (D=30/50/100, iPWO vs PWO) =====\n');
run_scaling_iPWO();

fprintf('\n===== [5/5] 运行效率 =====\n');
run_runtime();

fprintf('\nALL CHAPTER-6 EXPERIMENTS DONE. 图 = TIFF/330dpi/18pt；数据见本目录各 *_results 子目录与 .mat/.csv。\n');
