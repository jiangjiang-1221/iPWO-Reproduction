# iPWO Chapter 6 ablation study and mechanism verification - reproducible package

This directory contains the MATLAB reproducible code, all reproduction data, and TIFF figures for Chapter 6 (ablation study and mechanism verification) of the paper.

## Directory structure

- `code/`: MATLAB source (includes CEC2017 test data and the MTA-PP environment/cost function)
- `data/`: all reproducible data (`.mat` / `.csv`)
- `figures/`: TIFF figures used in Chapter 6 of the paper (330 DPI, 27 pt, Times New Roman, uniform 11x7.5 inch)

## How to run

In MATLAB:

```matlab
cd('D:/File/GPTTest/CEC2017_Experiment/iPWO_Reproducible/iPWO_Chapter6_Reproducible/code')
run_all_ch6            % reproduce all Chapter 6 experiments serially
```

To speed up re-running ablation / Rally / dimension scaling, use:

```matlab
run_full_parallel      % auto-open parallel pool; run component ablation, Rally ablation, and D=30/50/100 scaling
```

If the D=100 dimension scaling is interrupted midway, it can resume from checkpoint:

```matlab
run_scaling_D100_checkpoint
finalize_scaling       % aggregate D=30/50/100 and generate the TIFF for Fig. 12
```

### Redraw figures only (no re-running of optimization experiments)

All 180 figures (runtime / scaling / sensitivity / ablation convergence / ablation boxplot / average rank) can be redrawn from
the stored results in `data/` directly:

```matlab
cd('D:/File/GPTTest/CEC2017_Experiment/iPWO_Reproducible/iPWO_Chapter6_Reproducible/code')
redraw_ch6_all         % about 3-4 minutes; output all TIFFs (Times New Roman)
```

Can also be run via the `matlab -batch` command line:

```matlab
matlab -batch "cd('D:/File/GPTTest/CEC2017_Experiment/iPWO_Reproducible/iPWO_Chapter6_Reproducible/code'); redraw_ch6_all"
```

Note: `aggregate_ch6` needs the chunked raw mat files (`results_*_D30_*.mat`); use `redraw_ch6_all` for redrawing.

## Data mapping

- `data/ablation_results/`: component ablation (Table 4), including per-function raw results, average-rank CSV/TXT, `results_ablation_D10/D30.mat`
- `data/ablation_rally_results/`: Rally ablation (Table 5), including per-function raw results, average rank and significant-win statistics
- `data/sensitivity_theta_rho.csv`: theta-rho parameter sensitivity (Fig. 10 data)
- `data/runtime_times.csv`: single-run MTA-PP solving runtime of 5 algorithms (Fig. 11 data)
- `data/scaling_iPWO_results/`: raw data and summary of D=30/50/100 dimension scaling (Fig. 12 data)

## Notes

- All figures are unified as TIFF, 330 DPI, 27 pt font, **Times New Roman**, 11x7.5 inch size, exported uniformly by `ch6_print.m` (the font is set centrally inside that function).
- The F21 checkpoint for D=100 is filled from the existing complete D=100 record under the same random seed and same code (this function takes very long per run at D=100, and the worker dropped during re-running); the other 9 functions are all results from this re-run.
