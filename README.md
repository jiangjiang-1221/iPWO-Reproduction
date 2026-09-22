# iPWO — Reproduction Package

Reproduction material for the paper on **iPWO**, a rally-guided SHADE hybrid with
entropy–chaos reset and orthogonal local refinement, evaluated on the IEEE CEC2017 /
CEC2022 benchmark suites and applied to the **Multi-UAV Task Assignment and Path
Planning (MTA-PP)** problem.

This repository contains the MATLAB source code, baseline implementations, the
experimental settings, the analysis and figure-generation scripts, the processed
experimental data, and the final publication figures.

> **Note on language.** The in-package `README.txt` / `README.md` files shipped with
> each sub-package are written in Chinese; this top-level README is the English entry
> point. Nothing else has been altered.

---

## 1. Repository layout

```
iPWO-Reproduction/
├── CEC2017/                                   IEEE CEC2017 benchmark (D = 10/30/50/100)
│   ├── iPWO_D10_Reproducible/                 per-dimension package:
│   ├── iPWO_D30_Reproducible/                   code/    MATLAB code + CEC2017 mex + input_data17
│   ├── iPWO_D50_Reproducible/                   data/    repro/, landscape_cache/, *Summary.csv
│   ├── iPWO_D100_Reproducible/                  figures/ publication TIFFs (692×692 px, 600 DPI)
│   ├── CEC2017Dim10/  CEC2017Dim30/  CEC2017Dim50/
│   │                                          per-function .mat / .xlsx / .png / Statistics.txt
│   ├── CEC2017Dim10_TIFF_MATLAB/  ·Dim30·  ·Dim50·
│   │                                          publication TIFFs of the boxplots and
│   │                                          convergence curves + generate_figures.m
│   ├── consistency_check.py                   package consistency audit
│   └── consistency_report.txt
├── CEC2022/iPWO_CEC2022_Reproducible/         IEEE CEC2022 benchmark (D = 10/20)
├── iPWO_Chapter6_Reproducible/                ablation / sensitivity / runtime / scaling
│   ├── code/                                  iPWO variants, run_* scripts, redraw_ch6_all.m
│   ├── data/                                  ablation + rally results, sensitivity & runtime CSVs
│   └── figures/                               publication TIFFs (330 DPI, Times New Roman)
└── uav_delivery_TIFF_MATLAB/                  MTA-PP (multi-UAV) experiment
    ├── *.m                                    iPWO, PWO, GWO, PSO, DE, MGO, SFOA + cost/env models
    ├── data/                                  delivery_results.mat, comparison_table.csv, run_log.txt
    └── figs/                                  fig1–fig9 TIFFs (330 DPI)
```

### What each sub-package is for

| Sub-package | Paper figures | Reproduces |
|---|---|---|
| `CEC2017/iPWO_D{10,30,50,100}_Reproducible` | qualitative 5-panel figures (a) 3-D landscape, (b) objective space, (c) trajectory, (d) average fitness, (e) search history | iPWO behaviour on CEC2017 |
| `CEC2017/CEC2017Dim{10,30,50}` + `*_TIFF_MATLAB` | boxplots of best values + convergence curves | CEC2017 comparison statistics over the eight compared algorithms (per-function best/mean/median/Std/rank tables and the per-function figure data are included) |
| `CEC2022/iPWO_CEC2022_Reproducible` | same qualitative panels | supplementary CEC2022 results |
| `iPWO_Chapter6_Reproducible` | component ablation, rally ablation, θ–ρ sensitivity, average runtime, dimension scalability | mechanism verification |
| `uav_delivery_TIFF_MATLAB` | 3-D scene, flight paths, load profile, mean cost, makespan distribution, conflict check, comparison table, sensitivity, time-window Gantt | MTA-PP engineering application |

---

## 2. Requirements

- **MATLAB R2020a or newer** (`exportgraphics` is used for TIFF export).
  Tested with MATLAB R2024a on Windows x64.
- The CEC2017 / CEC2022 function implementations are shipped as a pre-built Windows
  x64 MEX (`cec17_func.mexw64`) **together with its C++ source** (`cec17_func.cpp`).
  The folder `code/input_data17/` (or `code/input_data/`) **must stay next to the MEX**,
  otherwise the MEX cannot load its data and the 3-D landscape slices become `NaN`.
  To rebuild the MEX on another platform, compile `cec17_func.cpp` (see the CEC2017
  technical report, reference [CEC2017-BoundContrained]).
- A few auxiliary scripts are Python 3 (package auditing / figure post-processing);
  they need `numpy`, `matplotlib`, `Pillow`, `python-docx`, `openpyxl`.

---

## 3. How to reproduce

### 3.1 CEC2017 five-panel figures (per dimension)

```matlab
cd CEC2017/iPWO_D30_Reproducible/code

main30a                    % full run from scratch: iPWO on F1,F3..F30, 30 runs (~4-5 h)
% --- or, without re-optimising ---
make_iPWO_figures          % redraw every TIFF from data/raw/*.mat  (~30-60 min)
reproduce_figures_from_data% redraw from the compact data/repro/*.mat only (no MEX needed)
```

`make_iPWO_figures` needs `data/raw/`; `reproduce_figures_from_data` needs only
`data/repro/` and therefore runs without the CEC2017 MEX.

### 3.2 CEC2017 boxplots + convergence curves

```matlab
cd CEC2017/CEC2017Dim30_TIFF_MATLAB
generate_figures
```

### 3.3 Chapter 6 (ablation / sensitivity / runtime / scalability)

```matlab
cd iPWO_Chapter6_Reproducible/code

run_all_ch6                % serial reproduction of every Chapter-6 experiment
run_full_parallel          % parallel version (component ablation, rally ablation, D scaling)
redraw_ch6_all             % redraw all figures from the saved data (~3-4 min)
```

`run_scaling_D100_checkpoint` resumes an interrupted D = 100 scaling run, then
`finalize_scaling` aggregates D = 30/50/100 and writes the scalability figure.

### 3.4 MTA-PP (multi-UAV) experiment

```matlab
cd uav_delivery_TIFF_MATLAB

run_uav_delivery           % full experiment: 7 algorithms × 51 runs on the MTA-PP instance
run_uav_delivery(true)     % REDRAW mode — regenerates all figures from data/delivery_results.mat
redraw_bar_mean            % mean-cost bar chart from the saved table
redraw_gantt               % time-window feasibility Gantt chart
```

`run_uav_delivery(true)` is the fast path: it needs no re-optimisation and reproduces
`figs/fig1…fig9` exactly as shipped.

---

## 4. Experimental settings (summary)

| Item | Value |
|---|---|
| Benchmark | IEEE CEC2017 (29 functions, F2 skipped), IEEE CEC2022 (12 functions, supplementary) |
| Dimensions | CEC2017: D = 10/30/50/100; CEC2022: D = 10/20 |
| Budget | `MaxFEs = 10000 × D` |
| Population | 30 (qualitative analysis and Chapter-6 experiments), linear population size reduction in the MTA-PP runs |
| Independent runs | 30 per function (CEC2017/CEC2022 panels); 51 runs (MTA-PP comparison) |
| MTA-PP instance | 6 UAVs, 30 customers, cargo capacity 10 kg, cruise speed 15 m/s, service time 30 s, minimum safety distance 6 m, time windows enabled |
| Statistics | best / median / mean / standard deviation, average rank, Wilcoxon rank-sum test |
| Figures | TIFF; Times New Roman; CEC2017 panels 600 DPI (692×692 px each, 2.928 cm square), Chapter-6 and MTA-PP figures 330 DPI on an 11 × 7.5 in canvas |

Full parameter tables (including every baseline parameter) are in the paper and in the
per-package `README` / `README.txt` files.

---

## 5. Figures shipped in this repository

All figure files under `*/figures/` and `*/figs/` are the **exact** publication figures
used in the manuscript. TIFFs that were stored uncompressed have been re-saved with
**lossless LZW compression** to keep the repository a reasonable size — pixel values,
pixel dimensions and DPI metadata are unchanged.

---

## 6. Data and Code Availability

The source code, baseline implementations, experimental settings, analysis scripts,
and figure-generation scripts used in this study are publicly available at
<https://github.com/jiangjiang-1221/iPWO-Reproduction>.

The accompanying resources required to reproduce the reported experiments — including
the processed experimental data used for figure generation and the final publication
figures — are archived in the same repository.

The full **per-run raw optimization records** (`CEC2017_F*_Dim*_iPWO_Results.mat`,
≈ 15 GB in total, with individual files exceeding GitHub's 100 MB per-file limit) are
not included here; they are available from the corresponding author upon reasonable
request. They are only required for the `make_iPWO_figures` path — every figure in the
paper can be regenerated from the compact `data/repro/` files that *are* included.

### Scope note — what is deliberately not shipped

Two things are intentionally absent, so that nobody is misled about how far the package
goes:

1. **Raw per-run records** — see above.
2. **The DRA and LCA baseline implementations.** The CEC2017 comparison tables
   (`CEC2017/CEC2017Dim*/CEC2017_F*_Statistics.txt` and the summary spreadsheets)
   contain the DRA and LCA statistics used in the paper, but the source files of those
   two algorithms are not redistributed here. Source code is provided for the remaining
   comparison algorithms (PWO, GWO, PSO, DE, MGO, SFOA).

---

## 7. License

Released under the MIT License — see [`LICENSE`](LICENSE).

### Third-party notice

The IEEE CEC2017 and CEC2022 benchmark implementations (`cec17_func.cpp`,
`cec17_func.mexw64`), the accompanying `input_data*` files and the
`Get_Functions_cec2017.m` wrappers originate from the official benchmark suites
distributed by their authors and remain subject to their own terms. They are
redistributed here solely to make the experiments reproducible.

## 8. Citation

If you use this code, please cite the paper (bibliographic details to be filled in
upon publication).
