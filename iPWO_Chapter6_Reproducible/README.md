# iPWO 第六章消融实验与机制验证——可复现包

本目录包含论文第六章「消融实验与机制验证」的 MATLAB 可复现代码、全部复现数据与 TIFF 图。

## 目录结构

- `code/`：MATLAB 源码（含 CEC2017 测试数据与 MTA-PP 环境/代价函数）
- `data/`：所有可复现数据（`.mat` / `.csv`）
- `figures/`：论文第 6 章用到的 TIFF 图（330 DPI、27 pt、Times New Roman、统一 11×7.5 英寸）

## 运行方法

在 MATLAB 中：

```matlab
cd('D:/File/GPTTest/CEC2017_Experiment/iPWO_Reproducible/iPWO_Chapter6_Reproducible/code')
run_all_ch6            % 串行复现全部第六章实验
```

如需加速重跑消融 / Rally / 维度扩展，可使用：

```matlab
run_full_parallel      % 自动开并行池，运行组件消融、Rally 消融和 D=30/50/100 扩展
```

D=100 维度扩展若中途中断，可断点续跑：

```matlab
run_scaling_D100_checkpoint
finalize_scaling       % 汇总 D=30/50/100 并生成 Fig. 12 的 TIFF
```

### 只重绘图片（不重跑任何优化实验）

全部 180 张图（runtime / scaling / sensitivity / 消融收敛 / 消融箱线 / 平均排名）都可以从
`data/` 已存结果直接重绘：

```matlab
cd('D:/File/GPTTest/CEC2017_Experiment/iPWO_Reproducible/iPWO_Chapter6_Reproducible/code')
redraw_ch6_all         % 约 3-4 分钟，输出全部 TIFF（Times New Roman）
```

也可用 `matlab -batch` 命令行运行：

```matlab
matlab -batch "cd('D:/File/GPTTest/CEC2017_Experiment/iPWO_Reproducible/iPWO_Chapter6_Reproducible/code'); redraw_ch6_all"
```

注意：`aggregate_ch6` 需要分块原始 mat（`results_*_D30_*.mat`），重绘请使用 `redraw_ch6_all`。

## 数据对应关系

- `data/ablation_results/`：组件消融（Table 4），含逐函数原始结果、平均秩 CSV/TXT、`results_ablation_D10/D30.mat`
- `data/ablation_rally_results/`：Rally 消融（Table 5），含逐函数原始结果、平均秩与显著胜场统计
- `data/sensitivity_theta_rho.csv`：θ–ρ 参数敏感性（Fig. 10 数据）
- `data/runtime_times.csv`：5 种算法单次 MTA-PP 求解运行时间（Fig. 11 数据）
- `data/scaling_iPWO_results/`：D=30/50/100 维度扩展原始数据与汇总（Fig. 12 数据）

## 说明

- 所有图统一为 TIFF、330 DPI、27 pt 字体、**Times New Roman**、11×7.5 英寸图幅，由 `ch6_print.m` 统一导出（字体在该函数内集中设置）。
- D=100 的 F21 检查点由同一随机种子、同一代码的既有完整 D=100 记录补齐（该函数在 D=100 上单次耗时极长，重跑过程中工作进程掉线）；其余 9 个函数均为本次重跑结果。
