iPWO CEC2022 performance evaluation and visualization -- reproducible package
================================================

1. Content
  code/     MATLAB reproducible code
    main30a.m                    full test entry: runs iPWO with the CEC2022 standard budget MaxFEs=10000*D,
                                 dimensions D=10 and D=20, 30 independent runs per function, 12 functions,
                                 output raw results and reproduction data
    iPWO.m / iPWO_history.m       iPWO algorithm implementation (history version records per-generation population/fitness/best trajectory)
    iPWO_build_figures.m           Single-panel figure plotting function (journal publication spec, consistent with CEC2017 iPWO_D* series):
                                   - Times New Roman global font
                                   - Single-panel TIFF, 2.928 cm square, 600 DPI (692x692 px)
                                   - Exported physical font size 6 pt (A4 text width fits 5 panels per row)
                                   - Also saves the data needed to reproduce figures to data/repro
    export_panel_tiff.m             Panel export: upscaled rendering + area-average downscaling to exact pixel size
    downscaleAvg.m                  Area-average downscaling implementation (export_panel_tiff dependency)
    Get_Functions_cec2022.m         CEC2022 function interface (12 functions)
    cec22_func.mexw64 / .cpp        CEC2022 C implementation (Windows 64-bit mex, with source)
    input_data22/                   CEC2022 mex runtime data files (must be in same directory as this code)
    make_iPWO_figures.m             Regenerate all TIFF figures directly from Results.mat in data/raw
                                    (auto-detects benchmark/function id/dimension; auto-deletes old 5-in-1 figures;
                                     saves each panel's .fig source to figures/fig)
    run_make22.m                    -batch wrapper: matlab -batch "run_make22"
    reproduce_figures_from_data.m   Redraw using only reproduction data in data/repro (no mex needed)
    summarize_iPWO_results.m        Summary script: outputs Best/Median/Mean/Std/success count/runtime by dimension

  data/
    raw/                 24 raw result files CEC2022_F*_Dim{10,20}_iPWO_Results.mat
                        (each contains: best single run's score/pos/curve/history/time,
                         30 per-run final values best_all, 30-run average convergence curve, success count and runtime)
    landscape_cache/     Terrain slice cache (120x120 grid, sliced from near the best solution)
    repro/               Figure reproduction data (convergence curves/trajectories/search history/terrain grid/figure spec), one mat per function
    iPWO_CEC2022_Dim10_Summary.csv / Dim20  summary by dimension

  figures/              Single-panel TIFF (2.928 cm square, 600 DPI, 692x692 px, Times New Roman)
    F*_Dim{10,20}_1_3D_Landscape.tif ... F*_Dim{10,20}_5_Search_History.tif
                                        individual panel subfigures (12 functions x 2 dimensions x 5 panels = 120 figures)
    fig/                                 the .fig source for each panel (120 files)
    Note: old 5-in-1 figure CEC2022_F*_iPWO_5Panels.tif deleted (no longer generated under new spec)

2. How to reproduce
  1) Full reproduction (from optimization, ~3-4 hours):
       cd code; main30a
     - Runs iPWO at the CEC2022 standard budget MaxFEs=10000*D, 30 times per function, D=10 and D=20
  2) Fast redraw of TIFF figures from raw results (~10 min, no re-optimization):
       cd code; make_iPWO_figures
     - or command line: matlab -batch "cd('...code'); run_make22"
     - Reads Results.mat in data/raw, generates all TIFF + .fig under figures/
  3) Pure-data reproduction (no CEC2022 mex, depends only on data/repro):
       cd code; reproduce_figures_from_data
     - writes into figures/from_repro_data/
  4) Summary statistics:
       cd code; summarize_iPWO_results

3. Figure specification (uniform with CEC2017 iPWO_D* series)
  - Layout: A4 (21.0x29.7 cm), top/bottom margins 2.54 cm, left/right margins 3.18 cm
    => text width 14.64 cm, 5 figures per row => each 2.928 cm square
  - Format: TIFF (.tif), 600 DPI => 692x692 px per figure
  - Font: Times New Roman, exported physical font size 6 pt
  - Single panel: 5-in-1 figures no longer generated; each panel saved as .fig source for later editing
  - iPWO-related markers drawn in red to stand out
  - Subfigure file names include dimension (F*_Dim*_[1-5]_*.tif) to avoid D10/D20 overwriting each other

4. Test settings
  - Functions: CEC2022 F1-F12 (12)
  - Dimension: 10 and 20
  - Budget: MaxFEs = 10000 * D
  - Independent runs: 30 per function
  - Metrics: best score (best_run.score), 30-run final value per run (best_all),
           30-run average convergence curve, average runtime
