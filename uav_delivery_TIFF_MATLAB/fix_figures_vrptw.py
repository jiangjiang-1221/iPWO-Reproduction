# 硬编码权威映射重嵌 Fig.5-8（修复 update 脚本的 caption 启发式错位），
# 并微调统计段 best_clause 措辞。文档先自动备份。
import os, re, glob, shutil, datetime
from docx import Document
from docx.shared import Inches
from PIL import Image

DOCX = r"C:/Users/江文/Desktop/cn-20260826-review.docx"
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

# ---------- 1) 修正统计段 best_clause ----------
d = Document(DOCX)
def find_para(sub):
    for i, p in enumerate(d.paragraphs):
        if sub in p.text:
            return i
    return None

i111 = find_para("51 次独立运行的统计指标显示")
if i111 is not None:
    old = ("iPWO 的 Z 最优值为 201.64 s（全场最低为 PSO 的 199.08 s）")
    new = ("iPWO 在 Median（314.14 s）、Mean（327.80 s）与 Avg.Rank（2.41，全场最优）上均居首位，"
           "单次最优 Best（201.64 s）与 PSO（199.08 s）基本持平（二者差异不显著，p=0.22）")
    if old in d.paragraphs[i111].text:
        d.paragraphs[i111].text = d.paragraphs[i111].text.replace(old, new)
        print("  fixed best_clause in para", i111)
    else:
        print("  (best_clause 文本未匹配，跳过文本修正)")

# ---------- 2) 硬编码重嵌 Fig.5-8 ----------
rels = d.part.rels
MAP = {
    "rId96": "fig1_scene.tif",        # Fig.5 场景
    "rId97": "fig4_convergence.tif",  # Fig.6 收敛
    "rId98": "fig5_boxplot.tif",      # Fig.7 箱线
    "rId99": "fig6_conflict.tif",     # Fig.8 冲突
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
