iPWO CEC2017 D=10 性能评估与可视化 —— 可复现包
================================================

一、内容结构
  code/     MATLAB 可复现代码
    main30a.m                    完整测试入口: 运行 iPWO (MaxFEs=10000*D, 30次独立运行,
                                 D=10, F1+F3~F30 共29函数), 并输出原始结果与复现数据
    iPWO.m / iPWO_history.m       iPWO 算法实现 (history 版本记录每代种群/适应度/最优轨迹)
    iPWO_build_figures.m           单独面板图绘制函数(论文出版规格):
                                   - Times New Roman 全局字体
                                   - 单独面板 TIFF, 2.928cm 见方, 600 DPI (692x692 px)
                                   - 导出物理字号 6pt (A4 版心一行可放 5 张)
                                   - 同时把复现图片所需数据保存到 data/repro
    export_panel_tiff.m             面板导出: 放大渲染 + 面积平均缩放到精确像素尺寸
    downscaleAvg.m                  面积平均缩放实现 (export_panel_tiff 依赖)
    Get_Functions_cec2017.m         CEC2017 函数接口
    cec17_func.mexw64 / .cpp        CEC2017 C 实现 (Windows 64位 mex, 附源码)
    input_data17/                   CEC2017 mex 运行时数据文件 (必须与本代码同目录,
                                    否则 mex 无法读取, 地形切片会出现 NaN)
    make_iPWO_figures.m             从 data/raw 的 Results.mat 直接重新生成全部 TIFF 图
                                    (自动删除旧五联图; 每个面板另存 .fig 源文件到 figures/fig)
    reproduce_figures_from_data.m   仅用 data/repro 复现数据重新绘图 (无需 mex)

  data/
    raw/                 29 个原始结果文件 CEC2017_F*_Dim10_iPWO_Results.mat
                        (每个含: 最优一次运行的 score/pos/curve/history/time,
                         30次平均收敛曲线 avg_best_curve/avg_fit_curve, 成功次数与耗时)
    landscape_cache/     地形切片缓存 (120x120 网格, 由最优解附近切片生成)
    repro/               图片复现数据 (收敛曲线/轨迹/搜索历史/地形网格/图规格), 每函数一个 mat
    iPWO_Dim10_Summary.csv  29 函数最优成绩与平均曲线终值汇总

  figures/              单独面板 TIFF (2.928cm 见方, 600 DPI, 692x692 px, Times New Roman)
    F*_Dim10_1_3D_Landscape.tif ... F*_Dim10_5_Search_History.tif   各面板子图 (145张)
    fig/                                 每个面板对应的 .fig 源文件 (145个)
    注: 旧版五联图已删除 (新规格不再生成)

二、如何复现
  1) 完整复现(从优化开始, 约4-5小时):
       cd code; main30a
     - 按 CEC2017 标准预算 MaxFEs=10000*D 运行 iPWO, 每函数30次, D=10
  2) 从原始结果快速重绘 TIFF 图(约30-60分钟, 无需重新优化):
       cd code; make_iPWO_figures
     - 读取 data/raw 的 Results.mat, 生成 figures/ 下全部 TIFF + .fig
  3) 纯数据复现(无需 CEC2017 mex, 仅依赖 data/repro):
       cd code; reproduce_figures_from_data
     - 输出到 figures/from_repro_data/

三、图规格说明 (各 iPWO_D* 与 CEC2022 复现包统一)
  - 版面: A4(21.0x29.7cm), 上下边距 2.54cm, 左右边距 3.18cm
    => 正文宽度 14.64cm, 一行放 5 张 => 每张 2.928cm 见方
  - 格式: TIFF (.tif), 600 DPI => 692x692 px/张
  - 字体: Times New Roman, 导出物理字号 6pt
  - 单独面板: 不再生成五联图; 每个面板另存 .fig 源文件便于后期编辑
  - iPWO 相关标记使用红色以突出显示

四、测试设置
  - 函数: CEC2017 F1, F3~F30 (29个, F2 按惯例跳过)
  - 维度: 10
  - 预算: MaxFEs = 10000 * D = 100000
  - 独立运行: 30 次/函数
  - 指标: 最优成绩(best_run.score), 30次平均收敛曲线, 平均运行时间
