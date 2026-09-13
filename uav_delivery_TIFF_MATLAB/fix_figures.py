# -*- coding: utf-8 -*-
"""Re-embed the 4 MTA-PP figures (rId96-99) with the CORRECT mapping, downscaled PNG.
Reads the current docx (which already has 6/30 text + Table 3) and only fixes image blobs.
Hardcoded mapping (document order = figure order):
  rId96 = Fig.5 3D scene        -> fig1_scene.tif
  rId97 = Fig.6 convergence     -> fig4_convergence.tif
  rId98 = Fig.7 boxplot         -> fig5_boxplot.tif
  rId99 = Fig.8 conflict/safety -> fig6_conflict.tif
"""
import os, glob, datetime
from PIL import Image
import docx
from docx.oxml.ns import qn

DOCX = r"C:/Users/江文/Desktop/cn-20260826-review.docx"
PKG  = r"D:/File/GPTTest/uav_delivery/uav_delivery_TIFF_MATLAB"
FIGS = os.path.join(PKG, "figs")

# backup first
ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
bak = DOCX + f".bak_figfix_{ts}"
import shutil
shutil.copy2(DOCX, bak)
print("backup ->", bak)

MAPPING = {
    "rId96": "fig1_scene",
    "rId97": "fig4_convergence",
    "rId98": "fig5_boxplot",
    "rId99": "fig6_conflict",
}

def tif_to_png(tif_path):
    im = Image.open(tif_path)
    if im.mode != "RGB":
        im = im.convert("RGB")
    max_w = 1800
    if im.width > max_w:
        h = int(im.height * max_w / im.width)
        im = im.resize((max_w, h), Image.LANCZOS)
    out = tif_path + ".embed.png"
    im.save(out, "PNG", optimize=True)
    return out

d = docx.Document(DOCX)
rels = d.part.rels
for rid, base in MAPPING.items():
    tif = glob.glob(os.path.join(FIGS, base + ".tif"))
    if not tif:
        tif = glob.glob(os.path.join(FIGS, base + ".png"))
    if not tif:
        print("  WARN: missing", base); continue
    png = tif_to_png(tif[0])
    with open(png, "rb") as fh:
        blob = fh.read()
    rels[rid].blob = blob
    print(f"  replaced {rid} <- {base}.tif  ({os.path.getsize(png)} bytes png)")

d.save(DOCX)
print("docx saved:", DOCX)
