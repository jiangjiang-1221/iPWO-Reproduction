# -*- coding: utf-8 -*-
"""
CEC2017 Dim10/30/50 复现数据 与原文件夹 一致性核查
=================================================
对每一个复现文件夹 CEC2017Dim{N}_TIFF_MATLAB/data/ 与其原始 CEC2017Dim{N}/ 做逐项比对:
  (1) 复制完整性: 每个 *_Best_Values.xlsx / *_Avg_Convergence.xlsx 都存在且算法列一致
  (2) 单元格级一致: 除 Avg_Convergence 的 SFOA 列(col3)第1行外, 其余所有单元格必须与原文件逐值相等
  (3) SFOA 修正正确性: 被改的单元格 = 原文件同表 SFOA 列第2行值 (等价于 curve(1)=curve(2))
  (4) SFOA 不再有首行 0
  (5) nfe (x轴终点): Avg_Convergence 行数-1 符合维度预期 (Dim10=3335, Dim30=10001, Dim50=16668)
  (6) 箱线图数值一致性: 复现 data 的 Best_Values 与 原文件夹 Best_Values 逐值相等 (箱线图直接由它绘制)
输出 PASS/FAIL 汇总, 任何 FAIL 会列出细节。
"""
import openpyxl, os, glob, numpy as np

ROOT = r"D:\File\GPTTest\CEC2017_Experiment\iPWO_Reproducible\CEC2017"
DIMS = [10, 30, 50]
EXPECT_NFE = {10: 3335, 30: 10001, 50: 16668}   # Avg_Convergence 行数 (excl header)

def load_matrix(fp):
    wb = openpyxl.load_workbook(fp, read_only=True, data_only=True)
    rows = list(wb.active.iter_rows(values_only=True))
    wb.close()
    header = list(rows[0])
    data = np.array(rows[1:], dtype=float)
    return header, data

def check_dim(dim):
    src = os.path.join(ROOT, f"CEC2017Dim{dim}")
    rep = os.path.join(ROOT, f"CEC2017Dim{dim}_TIFF_MATLAB", "data")
    problems = []
    funcs = [f for f in list(range(1,31)) if f != 2]   # CEC2017 无 F2

    for fid in funcs:
        bv = f"CEC2017_F{fid}_Dim{dim}_Best_Values.xlsx"
        av = f"CEC2017_F{fid}_Dim{dim}_Avg_Convergence.xlsx"
        src_bv, src_av = os.path.join(src, bv), os.path.join(src, av)
        rep_bv, rep_av = os.path.join(rep, bv), os.path.join(rep, av)

        # (1) 复制完整性
        for p in [rep_bv, rep_av]:
            if not os.path.exists(p):
                problems.append(f"F{fid}: 缺失 {os.path.basename(p)}")
                continue

        # Best_Values: 逐值等于原
        if os.path.exists(src_bv) and os.path.exists(rep_bv):
            h1, d1 = load_matrix(src_bv)
            h2, d2 = load_matrix(rep_bv)
            if list(h1) != list(h2):
                problems.append(f"F{fid} Best_Values 表头不一致: {h1} vs {h2}")
            if d1.shape != d2.shape:
                problems.append(f"F{fid} Best_Values 形状不一致: {d1.shape} vs {d2.shape}")
            else:
                if not np.allclose(d1, d2, rtol=0, atol=1e-12, equal_nan=True):
                    diff = np.abs(d1 - d2)
                    problems.append(f"F{fid} Best_Values 有 {int((diff>1e-12).sum())} 个单元格与原文件不同 (max|Δ|={diff.max():.3e})")

        # Avg_Convergence: 除 SFOA(col3)第1行外全部等于原
        if os.path.exists(src_av) and os.path.exists(rep_av):
            h1, d1 = load_matrix(src_av)   # 原
            h2, d2 = load_matrix(rep_av)   # 复现
            if list(h1) != list(h2):
                problems.append(f"F{fid} Avg_Convergence 表头不一致")
            if d1.shape != d2.shape:
                problems.append(f"F{fid} Avg_Convergence 形状不一致: {d1.shape} vs {d2.shape}")
            else:
                # 构造掩码: SFOA 列(索引2)第1行(index0)允许不同
                mask = np.ones(d1.shape, dtype=bool)
                mask[0, 2] = False
                diff = np.abs(d1 - d2)
                if not np.allclose(d1[mask], d2[mask], rtol=1e-9, atol=1e-6, equal_nan=True):
                    nd = int((diff[mask] > 1e-6).sum())
                    problems.append(f"F{fid} Avg_Convergence 有 {nd} 个非SFOA首行单元格与原文件差异>1e-6 (max|Δ|={diff[mask].max():.3e})")
                # (3) SFOA 修正正确性
                rep_first = d2[0, 2]
                src_second = d1[1, 2]
                if abs(rep_first - src_second) > max(1e-3, 1e-9*abs(src_second)):
                    problems.append(f"F{fid} SFOA首行修正错误: 复现={rep_first:.4e} 应=原第2行={src_second:.4e}")
                # (4) SFOA 首行非0
                if rep_first == 0 or rep_first is None:
                    problems.append(f"F{fid} SFOA首行仍为 0")

            # (5) nfe
        if os.path.exists(rep_av):
            wb = openpyxl.load_workbook(rep_av, data_only=True)
            n = wb.active.max_row - 1
            wb.close()
            if n != EXPECT_NFE[dim]:
                problems.append(f"F{fid} nfe={n} 期望 {EXPECT_NFE[dim]}")

    return problems

if __name__ == "__main__":
    print("="*70)
    print("CEC2017 复现数据 vs 原文件夹 一致性核查")
    print("说明: 差异容差 rtol=1e-9/atol=1e-6 (仅捕捉真实改动, 忽略 openpyxl 重写 xlsx 的浮点序列化噪声)")
    print("="*70)
    all_ok = True
    for dim in DIMS:
        probs = check_dim(dim)
        status = "PASS" if not probs else "FAIL"
        if probs: all_ok = False
        print(f"\n[Dim {dim}]  {status}  (问题数 {len(probs)})")
        for p in probs[:20]:
            print("   -", p)
        if len(probs) > 20:
            print(f"   ... 其余 {len(probs)-20} 项省略")

    # (7) 图文件完整性: 每维度 figures/ 应有 29 Boxplot + 29 Convergence TIFF
    print("\n" + "-"*70)
    print("图文件完整性检查 (figures/*.tif)")
    print("-"*70)
    import glob
    for dim in DIMS:
        figdir = os.path.join(ROOT, f"CEC2017Dim{dim}_TIFF_MATLAB", "figures")
        box = glob.glob(os.path.join(figdir, "*Boxplot*.tif"))
        conv = glob.glob(os.path.join(figdir, "*Convergence.tif"))
        ok = (len(box)==29 and len(conv)==29)
        if not ok: all_ok = False
        print(f"  Dim {dim}: Boxplot={len(box)} Convergence={len(conv)}  {'OK' if ok else 'FAIL (期望各29)'}")

    print("\n" + "="*70)
    print("总结果:", "ALL PASS" if all_ok else "存在 FAIL")
    print("="*70)
