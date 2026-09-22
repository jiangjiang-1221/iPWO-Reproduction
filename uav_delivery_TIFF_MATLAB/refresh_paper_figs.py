#!/usr/env python
# -*- coding: utf-8 -*-
"""Re-embed only the UAV figures into the paper (no body text touched).
Replace the embedded figures for Fig.5-9 in cn-20260826-review.docx with the
new TIFFs under figs/ (Times New Roman / 28pt redrawn versions).
Figure-caption matching logic is the same as update_uav_paper_vrptw.py (+-3 paragraph window matching caption fragments).
Make a timestamped backup first, then save in place."""
import os, re, shutil, glob
from datetime import datetime
from PIL import Image
from docx import Document

DOCX = r"C:/Users/USER/Desktop/cn-20260826-review.docx"
PKG  = r"D:\File\GPTTest\uav_delivery\uav_delivery_TIFF_MATLAB"
FIGS = os.path.join(PKG, "figs")
BAK  = DOCX + ".bak_before_figrefresh_" + datetime.now().strftime("%Y%m%d_%H%M%S")

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

shutil.copy2(DOCX, BAK)
print("backup ->", BAK)

d = Document(DOCX)
mapping = {"Fig. 5": "fig1_scene", "Fig. 6": "fig4_convergence",
           "Fig. 7": "fig5_boxplot", "Fig. 8": "fig6_conflict",
           "Fig. 9": "fig9_gantt"}
paras = d.paragraphs
embed_rids = {}
for i, para in enumerate(paras):
    xml = para._p.xml
    for rid in re.findall(r'embed="(rId\d+)"', xml):
        for cap_frag in mapping:
            for j in range(max(0, i - 3), min(len(paras), i + 4)):
                if cap_frag in paras[j].text:
                    embed_rids[rid] = cap_frag
                    break

rels = d.part.rels
print("figure rIds found:", embed_rids)
done = []
for rid, cap in embed_rids.items():
    base = mapping[cap]
    tif = glob.glob(os.path.join(FIGS, base + ".tif"))
    if not tif:
        print("  WARN missing:", base)
        continue
    png = tif_to_png(tif[0])
    with open(png, "rb") as fh:
        rels[rid].target_part._blob = fh.read()
    done.append((rid, cap, base))
    print(f"  replaced {rid} ({cap} <- {base})")

d.save(DOCX)
print("SAVED:", DOCX)
print("replaced:", len(done), "figures")
