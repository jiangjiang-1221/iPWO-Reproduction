iPWO CEC2017 D=30 performance evaluation and visualization -- reproducible package
================================================

1. Content
  code/     MATLAB reproducible code
    main30a.m                    Full test entry: run iPWO (MaxFEs=10000*D, 30 independent runs,
                                 D=30, F1+F3~F30 , 29 functions), and output raw results and reproduction data
    iPWO.m / iPWO_history.m       iPWO algorithm implementation (history version records per-generation population/fitness/best trajectory)
    iPWO_build_figures.m           Single-panel figure plotting function (journal publication spec):
                                   - Times New Roman global font
                                   - Single-panel TIFF, 2.928 cm square, 600 DPI (692x692 px)
                                   - Exported physical font size 6 pt (A4 text width fits 5 panels per row)
                                   - Also saves the data needed to reproduce figures to data/repro
    export_panel_tiff.m             Panel export: upscaled rendering + area-average downscaling to exact pixel size
    downscaleAvg.m                  Area-average downscaling implementation (export_panel_tiff dependency)
    Get_Functions_cec2017.m         CEC2017 function interface
    cec17_func.mexw64 / .cpp        CEC2017 C implementation (Windows 64-bit mex, with source)
    input_data17/                   CEC2017 mex runtime data files (must be in same directory as this code,
                                    otherwise mex cannot read, terrain slice will contain NaN)
    make_iPWO_figures.m             Regenerate all TIFF figures directly from Results.mat in data/raw
                                    (auto-deletes old 5-in-1 figures; saves each panel's .fig source to figures/fig)
    reproduce_figures_from_data.m   Redraw using only reproduction data in data/repro (no mex needed)

  data/
    raw/                 29 raw result files CEC2017_F*_Dim30_iPWO_Results.mat
                        (each contains: best single run's score/pos/curve/history/time,
                         30-run average convergence curve avg_best_curve/avg_fit_curve, success count and runtime)
    landscape_cache/     Terrain slice cache (120x120 grid, sliced from near the best solution)
    repro/               Figure reproduction data (convergence curves/trajectories/search history/terrain grid/figure spec), one mat per function
    iPWO_Dim30_Summary.csv  29 functions' best scores and final value of the average curve summary

  figures/              Single-panel TIFF (2.928 cm square, 600 DPI, 692x692 px, Times New Roman)
    F*_Dim30_1_3D_Landscape.tif ... F*_Dim30_5_Search_History.tif   individual panel subfigures (145 figures)
    fig/                                 the .fig source for each panel (145 files)
    Note: old 5-in-1 figures deleted (no longer generated under new spec)

2. How to reproduce
  1) Full reproduction (from optimization, ~4-5 hours):
       cd code; main30a
     - Runs iPWO at the CEC2017 standard budget MaxFEs=10000*D, 30 times per function, D=30
  2) Fast redraw of TIFF figures from raw results (~30-60 min, no re-optimization):
       cd code; make_iPWO_figures
     - Reads Results.mat in data/raw, generates all TIFF + .fig under figures/
  3) Pure-data reproduction (no CEC2017 mex, depends only on data/repro):
       cd code; reproduce_figures_from_data
     - writes into figures/from_repro_data/

3. Figure specification (uniform across all iPWO_D* and CEC2022 reproduction packages)
  - Layout: A4 (21.0x29.7 cm), top/bottom margins 2.54 cm, left/right margins 3.18 cm
    => text width 14.64 cm, 5 figures per row => each 2.928 cm square
  - Format: TIFF (.tif), 600 DPI => 692x692 px per figure
  - Font: Times New Roman, exported physical font size 6 pt
  - Single panel: 5-in-1 figures no longer generated; each panel saved as .fig source for later editing
  - iPWO-related markers drawn in red to stand out

4. Test settings
  - Functions: CEC2017 F1, F3~F30 (29, F2 skipped by convention)
  - Dimension: 30
  - Budget: MaxFEs = 10000 * D = 300000
  - Independent runs: 30 per function
  - Metrics: best score (best_run.score), 30-run average convergence curve, average runtime
