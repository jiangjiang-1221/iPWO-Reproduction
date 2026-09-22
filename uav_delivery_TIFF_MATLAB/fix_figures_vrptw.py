# re-embed Fig.5-8 with the hardcoded authoritative mapping (fix the caption misalignment from the update script's heuristic),
# and fine-tune the wording of the statistics paragraph best_clause. Back up the document first.
import os, re, glob, shutil, datetime
from docx import Document
from docx.shared import Inches
from PIL import Image

DOCX = r"C:/Users/JiangWen/Desktop/cn-20260826-review.docx"
PKG  = r"D:/File/GPTTest/uav_delivery/uav_delivery_TIFF_MATLAB"
FIGS = os.path.join(PKG, "figs")

ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
bak = DOCX + f".bak_{ts}"
shutil.copy2(DOCX, bak)
print("backup ->", bak)

def tif_to_png(tif_path, max_w=1800):
    im = Image.open(tif_path)
    if im.mode != "RGB":
        im = im.convert("RGB")
    if im.width > max_w:
        h = int(im.height * max_w / im.width)
        im = im.resize((max_w, h), Image.LANCZOS)
    out = tif_path + ".embed.png"
    im.save(out, "PNG", optimize=True)
    return out

# ---------- 1) fix statistics paragraph best_clause ----------
d = Document(DOCX)
def find_para(sub):
    for i, p in enumerate(d.paragraphs):
        if sub in p.text:
            return i
    return None

i111 = find_para("statistics of 51 independent runs show")
if i111 is not None:
    old = ("iPWO best Z is 201.64 s (the overall lowest is PSO's 199.08 s)")
    new = ("iPWO ranks first in Median (314.14 s), Mean (327.80 s) and Avg.Rank (2.41, best overall),"
           "single-run best (201.64 s) is on par with PSO (199.08 s) (difference not significant, p=0.22)")
    if old in d.paragraphs[i111].text:
        d.paragraphs[i111].text = d.paragraphs[i111].text.replace(old, new)
        print("  fixed best_clause in para", i111)
    else:
        print("  (best_clause text not matched, skipping text fix)")

# ---------- 2) hardcode re-embed Fig.5-8 ----------
rels = d.part.rels
MAP = {
    "rId96": "fig1_scene.tif",        # Fig.5 scene
    "rId97": "fig4_convergence.tif",  # Fig.6 convergence
    "rId98": "fig5_boxplot.tif",      # Fig.7 boxplot
    "rId99": "fig6_conflict.tif",     # Fig.8 conflict
}
for rid, tif in MAP.items():
    tifp = os.path.join(FIGS, tif)
    if not os.path.exists(tifp):
        print("  WARN missing", tifp); continue
    png = tif_to_png(tifp)
    with open(png, "rb") as fh:
        rels[rid].target_part._blob = fh.read()
    print(f"  replaced {rid} <- {tif}")

d.save(DOCX)
print("docx saved:", DOCX)
