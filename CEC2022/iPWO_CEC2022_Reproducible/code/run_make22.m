function run_make22()
% Wrapper so `matlab -batch` can run the make_iPWO_figures script.
codeDir = 'D:\File\GPTTest\CEC2017_Experiment\iPWO_Reproducible\CEC2022\iPWO_CEC2022_Reproducible\code';
cd(codeDir);
addpath(codeDir);
make_iPWO_figures;
end
