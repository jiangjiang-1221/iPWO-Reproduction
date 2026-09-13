import os, hashlib
from docx import Document
from PIL import Image

DOCX = r"C:/Users/江文/Desktop/cn-20260826-review.docx"
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
    tif_sha[name] = sha(open(png,"rb").read())

d = Document(DOCX)
print("=== rId -> 图（Fig.5-9）===")
for rid in ["rId96","rId97","rId98","rId99","rId105"]:
    rel = d.part.rels.get(rid)
    if rel and "image" in rel.reltype:
        b = rel.target_part.blob
        m = [n for n,s in tif_sha.items() if s == sha(b)]
        print(f"  {rid}: {m[0] if m else '??? '+sha(b)}")
    else:
        print(f"  {rid}: 不存在/非image")

print("\n=== Table 3 内容 ===")
for ti, tbl in enumerate(d.tables):
    txt = [[c.text.strip() for c in r.cells] for r in tbl.rows]
    flat = " | ".join(" / ".join(r) for r in txt)
    if "iPWO" in flat and ("Best" in flat or "Z" in flat or "Rank" in flat):
        print(f"-- table {ti} --")
        for r in txt:
            print("  ", " | ".join(r))
