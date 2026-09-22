import os, hashlib
from docx import Document
from PIL import Image

DOCX = r"C:/Users/USER/Desktop/cn-20260826-review.docx"
PKG  = r"D:/File/GPTTest/uav_delivery/uav_delivery_TIFF_MATLAB"
FIGS = os.path.join(PKG, "figs")

def tif_to_png(tif_path, max_w=1800):
    im = Image.open(tif_path)
    if im.mode != "RGB": im = im.convert("RGB")
    if im.width > max_w:
        h = int(im.height * max_w / im.width); im = im.resize((max_w, h), Image.LANCZOS)
    out = tif_path + ".embed.png"; im.save(out, "PNG", optimize=True); return out

def sha(b): return hashlib.sha256(b).hexdigest()[:12]

tif_sha = {}
for name in ["fig1_scene","fig4_convergence","fig5_boxplot","fig6_conflict","fig9_gantt"]:
    png = tif_to_png(os.path.join(FIGS, name + ".tif"))
    tif_sha[name] = (sha(open(png,"rb").read()), png)

d = Document(DOCX)
print("rId -> matched figure")
for rid, rel in d.part.rels.items():
    if "image" in rel.reltype:
        b = rel.target_part.blob
        m = [n for n, (s, _) in tif_sha.items() if s == sha(b)]
        print(f"  {rid}: {m if m else '??? (sha='+sha(b)+')'}")
print("\nfig file sha prefix:")
for n,(s,_) in tif_sha.items(): print(f"  {n}: {s}")
