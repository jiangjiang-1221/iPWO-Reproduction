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
print("=== 特检 rId96-99 ===")
for rid in ["rId96","rId97","rId98","rId99"]:
    if rid in d.part.rels:
        rel = d.part.rels[rid]
        if "image" in rel.reltype:
            b = rel.target_part.blob
            m = [n for n,s in tif_sha.items() if s == sha(b)]
            print(f"  {rid}: IMAGE -> {m if m else '??? '+sha(b)}")
        else:
            print(f"  {rid}: 非image ({rel.reltype})")
    else:
        print(f"  {rid}: 不存在")

print("\n=== 全部 image 关系（按 rid 排序）===")
imgs = []
for rid, rel in d.part.rels.items():
    if "image" in rel.reltype:
        b = rel.target_part.blob
        m = [n for n,s in tif_sha.items() if s == sha(b)]
        imgs.append((rid, m[0] if m else "???"))
for rid, name in sorted(imgs, key=lambda x: int(x[0][3:])):
    print(f"  {rid}: {name}")
