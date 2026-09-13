#!/usr/env python
# -*- coding: utf-8 -*-
"""把箱型图（boxplot，fig5_boxplot.tif，纵轴 Z = 最终解代价，与 Table 3 同指标）重嵌进论文副本 rId98。
原 docx 被占用时保留副本。"""
import os, glob, shutil
from PIL import Image
import docx

SCRIPT_DIR = r"D:\File\GPTTest\uav_delivery\uav_delivery_TIFF_MATLAB"
FIGS = os.path.join(SCRIPT_DIR, "figs")
SRC = r"C:/Users/江文/Desktop/cn-20260826-review.docx"
DST = r"C:/Users/江文/Desktop/cn-20260826-review_Fig6mean.docx"

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

d = docx.Document(SRC)
rels = d.part.rels
tif = glob.glob(os.path.join(FIGS, "fig5_boxplot.tif"))
assert tif, "fig5_boxplot.tif 未找到"
png = tif_to_png(tif[0])
with open(png, "rb") as fh:
    rels["rId98"].target_part._blob = fh.read()
print("re-embedded boxplot (rId98) <-", os.path.basename(png))
d.save(DST)
print("saved:", DST)
try:
    shutil.copy2(DST, SRC)
    print("OVERWRITTEN_ORIGINAL")
except PermissionError:
    print("ORIGINAL_LOCKED_KEEP_COPY")
