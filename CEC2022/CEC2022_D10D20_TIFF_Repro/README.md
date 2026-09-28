# CEC2022 reproduction package (D = 10 / D = 20, TIFF 330 DPI, 22 pt Times New Roman)

Reproducible export package for all CEC2022 convergence-curve and boxplot figures
(Dim = 10 and Dim = 20) used in the paper. The drawing style follows the reference code in
`CEC2017/CEC2017Dim10_TIFF_MATLAB` (Times New Roman, 22 pt, gradient hand-drawn boxplots,
log axis with log-space adaptive ylim).

## Layout

```
CEC2022_D10D20_TIFF_Repro/
├─ README.md                      this file
├─ code/
│  ├─ reproduce_cec2022_figs.m    main MATLAB script (redraws from xlsx, no CEC mex needed)
│  └─ reproduce_cec2022_figs_old18pt.m.bak   previous 18 pt spec, kept as a backup
├─ data/                          inputs required for reproduction
│  ├─ *_Avg_Convergence.xlsx      per-algorithm average convergence traces (convergence plots)
│  ├─ *_Best_Values.xlsx          per-run best-value matrices (boxplots)
│  ├─ *_Results.mat               raw experiment result structures
│  ├─ *_Statistics.txt            per-function statistics (mean/median/std/rank)
│  └─ CEC2022_Summary.* / PerFuncMean.xlsx / Ranks.xlsx  cross-function summaries
└─ figures/                       output TIFFs (48 files: 12 functions x 2 dims x 2 types)
   ├─ CEC2022_F{1..12}_Dim10_Convergence.tif
   ├─ CEC2022_F{1..12}_Dim10_Boxplot_BestValues.tif
   ├─ CEC2022_F{1..12}_Dim20_Convergence.tif
   └─ CEC2022_F{1..12}_Dim20_Boxplot_BestValues.tif
```

## Export specification (identical to the CEC2017Dim10 reference)

| Item | Value |
|---|---|
| Format | **TIFF** (`.tif`), 48/48 files, written by `exportgraphics` |
| Resolution | **330 DPI** |
| Font | **Times New Roman, 22 pt** (global default plus explicit per-item settings; legend 20 pt) |
| Canvas | boxplot **9 x 6 in**, convergence plot **9.5 x 6 in** (matches the reference; sizes are deliberately not unified) |
| Convergence y-axis | **log axis with log-space adaptive ylim** (fitted to each function's own data, 5% log-space padding top and bottom, so the nine curves fill the axis and stay distinguishable) |
| Ticks | e-notation on the y-axis (`fmt_e`: 1000 -> '1e3', 1500 -> '1.5e3') |
| Anti-clipping | explicit `ax.Position` margins (boxplot `[0.13 0.14 0.84 0.76]`, convergence `[0.14 0.14 0.80 0.76]`) |

### Colour scheme for the nine algorithms (RGB 0-1, same as main30New.m and the CEC2017Dim series)

| Algorithm | RGB | Colour |
|---|---|---|
| iPWO | [1.00 0.00 0.00] | bright red |
| PWO | [0.00 0.45 0.74] | blue |
| SFOA | [0.13 0.55 0.13] | green |
| DRA | [0.55 0.00 0.80] | purple |
| MGO | [0.92 0.55 0.10] | orange |
| LCA | [0.00 0.62 0.62] | teal |
| DE | [0.95 0.78 0.00] | gold |
| PSO | [0.30 0.75 0.93] | light blue |
| GWO | [0.50 0.50 0.50] | grey |

## How to reproduce

1. Start MATLAB (verified on R2024a).
2. Run:
   ```matlab
   cd('<this folder>/code')
   reproduce_cec2022_figs
   ```
   or from the command line:
   ```matlab
   matlab -batch "cd('<this folder>/code'); reproduce_cec2022_figs"
   ```
3. The script reads the per-function xlsx files from `../data/`, redraws the figures and writes
   them into `../figures/` (about 1.5 minutes for the full set).
   - Narrow `dims` (e.g. `[10]`) and `funcs` (e.g. `1:12`) to reproduce a subset.
   - Export parameters sit at the top of the script: `FONT_SIZE`, `DPI`, `palette`, `MARKERS`.

## Fidelity notes

- **Convergence plots**: main30New palette for the nine algorithms, `semilogy` with explicit
  `ax.YScale='log'`, log-space adaptive ylim (`lpad = 0.05*(lmax-lmin)`,
  `ylo/yhi = 10^(lmin -/+ lpad)`, positive values only), line width 2.0, MarkerSize 6,
  e-notation ticks, x-axis starting at 0 (data-driven), no inset.
- **Boxplots**: hand-drawn gradient boxes (`surface` with texturemap, colour graded top to bottom,
  same as main30New.m) plus box outline, thickened median line, whiskers and caps; x ticks are the
  algorithm names (22 pt bold TNR) and the y-axis uses e-notation ticks.
- **Data guard**: non-positive values of every algorithm are set to NaN on the log axis, which
  replaces the special-casing of the first two SFOA points in the old script and is both general
  and safe.
- **Data source**: reads the `*_Avg_Convergence.xlsx` / `*_Best_Values.xlsx` files produced by the
  experiments directly, so drawing can be reproduced without the CEC benchmark mex files.
- **Legacy backup**: `code/reproduce_cec2022_figs_old18pt.m.bak` keeps the previous 18 pt /
  built-in boxplot version; rename it back to `.m` to reproduce the old style.
