iPWO CEC2022 性能评估与可视化 —— 可复现包
================================================

一、内容结构
  code/     MATLAB 可复现代码
    main30a.m                    完整测试入口: 运行 iPWO, CEC2022 标准预算 MaxFEs=10000*D,
                                 维度 D=10 与 D=20, 每函数30次独立运行, 共12个函数,
                                 输出原始结果与复现数据
    iPWO.m / iPWO_history.m       iPWO 算法实现 (history 版本记录每代种群/适应度/最优轨迹)
    iPWO_build_figures.m           单独面板图绘制函数(论文出版规格, 与 CEC2017 iPWO_D* 系列一致):
                                   - Times New Roman 全局字体
                                   - 单独面板 TIFF, 2.928cm 见方, 600 DPI (692x692 px)
                                   - 导出物理字号 6pt (A4 版心一行可放 5 张)
                                   - 同时把复现图片所需数据保存到 data/repro
    export_panel_tiff.m             面板导出: 放大渲染 + 面积平均缩放到精确像素尺寸
    downscaleAvg.m                  面积平均缩放实现 (export_panel_tiff 依赖)
    Get_Functions_cec2022.m         CEC2022 函数接口 (12个函数)
    cec22_func.mexw64 / .cpp        CEC2022 C 实现 (Windows 64位 mex, 附源码)
    input_data22/                   CEC2022 mex 运行时数据文件 (必须与本代码同目录)
    make_iPWO_figures.m             从 data/raw 的 Results.mat 直接重新生成全部 TIFF 图
                                    (自动识别基准/函数编号/维度; 自动删除旧五联图;
                                     每个面板另存 .fig 源文件到 figures/fig)
    run_make22.m                    -batch 包装函数: matlab -batch "run_make22"
    reproduce_figures_from_data.m   仅用 data/repro 复现数据重新绘图 (无需 mex)
    summarize_iPWO_results.m        汇总脚本: 按维度输出 Best/Median/Mean/Std/成功次数/耗时

  data/
    raw/                 24 个原始结果文件 CEC2022_F*_Dim{10,20}_iPWO_Results.mat
                        (每个含: 最优一次运行的 score/pos/curve/history/time,
                         30次逐次最终值 best_all, 30次平均收敛曲线, 成功次数与耗时)
    landscape_cache/     地形切片缓存 (120x120 网格, 由最优解附近切片生成)
    repro/               图片复现数据 (收敛曲线/轨迹/搜索历史/地形网格/图规格), 每函数一个 mat
    iPWO_CEC2022_Dim10_Summary.csv / Dim20  各维度汇总

  figures/              单独面板 TIFF (2.928cm 见方, 600 DPI, 692x692 px, Times New Roman)
    F*_Dim{10,20}_1_3D_Landscape.tif ... F*_Dim{10,20}_5_Search_History.tif
                                        各面板子图 (12函数 x 2维度 x 5面板 = 120张)
    fig/                                 每个面板对应的 .fig 源文件 (120个)
    注: 旧版五联图 CEC2022_F*_iPWO_5Panels.tif 已删除 (新规格不再生成)

二、如何复现
  1) 完整复现(从优化开始, 约3-4小时):
       cd code; main30a
     - 按 CEC2022 标准预算 MaxFEs=10000*D 运行 iPWO, 每函数30次, D=10 与 D=20
  2) 从原始结果快速重绘 TIFF 图(约10分钟, 无需重新优化):
       cd code; make_iPWO_figures
     - 或命令行: matlab -batch "cd('...code'); run_make22"
     - 读取 data/raw 的 Results.mat, 生成 figures/ 下全部 TIFF + .fig
  3) 纯数据复现(无需 CEC2022 mex, 仅依赖 data/repro):
       cd code; reproduce_figures_from_data
     - 输出到 figures/from_repro_data/
  4) 汇总统计:
       cd code; summarize_iPWO_results

三、图规格说明 (与 CEC2017 iPWO_D* 系列统一)
  - 版面: A4(21.0x29.7cm), 上下边距 2.54cm, 左右边距 3.18cm
    => 正文宽度 14.64cm, 一行放 5 张 => 每张 2.928cm 见方
  - 格式: TIFF (.tif), 600 DPI => 692x692 px/张
  - 字体: Times New Roman, 导出物理字号 6pt
  - 单独面板: 不再生成五联图; 每个面板另存 .fig 源文件便于后期编辑
  - iPWO 相关标记使用红色以突出显示
  - 子图文件名含维度 (F*_Dim*_[1-5]_*.tif), 避免 D10/D20 相互覆盖

四、测试设置
  - 函数: CEC2022 F1~F12 (12个)
  - 维度: 10 与 20
  - 预算: MaxFEs = 10000 * D
  - 独立运行: 30 次/函数
  - 指标: 最优成绩(best_run.score), 30次逐次最终值(best_all),
           30次平均收敛曲线, 平均运行时间
