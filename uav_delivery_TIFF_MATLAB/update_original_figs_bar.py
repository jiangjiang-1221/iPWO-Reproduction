#!/usr/env python
# -*- coding: utf-8 -*-
"""Swap Fig.6 (rId97) in the original paper from the "mean convergence curve" to a "mean bar chart"
# NOTE: this utility edits the Chinese manuscript copy. The Chinese literals below are
# match/replacement strings for that document and are kept verbatim on purpose.
(bar_means), with colors matching the Fig.5 boxplot. Back up the original first, then overwrite in place."""
import os, glob, shutil
from datetime import datetime
from PIL import Image
import docx

SCRIPT_DIR = r"D:\File\GPTTest\uav_delivery\uav_delivery_TIFF_MATLAB"
FIGS = os.path.join(SCRIPT_DIR, "figs")
SRC = r"C:/Users/USER/Desktop/cn-20260826-review.docx"
BAK = SRC + ".bak_before_barfig_" + datetime.now().strftime("%Y%m%d_%H%M%S")

def tif_to_png(tif, max_w=1800):
    im = Image.open(tif)
    if im.mode != "RGB":
        im = im.convert("RGB")
    if im.width > max_w:
        h = int(im.height * max_w / im.width)
        im = im.resize((max_w, h), Image.LANCZOS)
    out = tif + ".embed.png"
    im.save(out, "PNG", optimize=True)
    return out

# 0) backup
shutil.copy2(SRC, BAK)
print("backup ->", BAK)

d = docx.Document(SRC)
rels = d.part.rels

# 1) re-embed Fig.6 = mean bar chart (rId97)
tif = glob.glob(os.path.join(FIGS, "fig4_bar_mean.tif"))
assert tif, "fig4_bar_mean.tif not found"
png = tif_to_png(tif[0])
with open(png, "rb") as fh:
    rels["rId97"].target_part._blob = fh.read()
print("re-embedded Fig.6 (rId97) <-", os.path.basename(png), "size", os.path.getsize(png))

# 2) rewrite Fig.6 description paragraph
NEW_DESC = ("将 iPWO 与 PWO、GWO、PSO、DE、MGO、SFOA 共 7 种算法在统一设置下"
            "（种群规模 pop=30、最大函数评估次数 MaxFEs=8000）各独立运行 R=51 次"
            "（确定性随机种子、可复现）进行对比。如Fig. 6所示，各算法约束代价 "
            "Z = 完工时间 + 时间窗迟到的均值（即表 3 的 Mean 列）以柱状图展示，"
            "每根柱对应一种算法、颜色与图 5 箱型图一一对应，误差棒表示跨 51 次运行的标准差；"
            "柱越低代表平均性能越好。iPWO 的均值最低（327.80），明显优于其余基准算法，"
            "而 PWO 的均值最高（961.31）；该排名与表 3 的 Mean 列及图 5 的箱型分布完全一致。")
for p in d.paragraphs:
    if "如Fig. 6所示" in p.text:  # Chinese docx caption marker; kept verbatim
        p.text = NEW_DESC
        print("updated Fig.6 description para")

# 3) rewrite Fig.6 caption
NEW_CAP = ("Fig. 6 Mean constrained cost Z = makespan + time-window lateness of each algorithm "
           "over 51 runs (error bars = std; bar colors match the boxplot in Fig. 5; lower is better).")
for p in d.paragraphs:
    if p.text.strip().startswith("Fig. 6") and "convergence" in p.text.lower():
        p.text = NEW_CAP
        print("updated Fig.6 caption para")

# 4) prefer overwriting the original; if still locked by preview, write a new copy
try:
    d.save(SRC)
    print("OVERWRITTEN_ORIGINAL_OK ->", SRC)
except PermissionError:
    DST = r"C:/Users/USER/Desktop/cn-20260826-review_Fig6bar_v2.docx"
    d.save(DST)
    print("ORIGINAL_LOCKED_SAVED_COPY ->", DST)
