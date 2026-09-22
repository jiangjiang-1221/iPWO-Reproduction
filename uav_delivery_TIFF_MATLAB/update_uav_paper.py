# -*- coding: utf-8 -*-
"""
# NOTE: this utility edits the Chinese manuscript copy. The Chinese literals below are
# match/replacement strings for that document and are kept verbatim on purpose.
Update cn-20260826-review.docx (Desktop copy) after the 6-UAV / 30-customer re-run.
Reads the FRESH comparison_table.csv + the new TIFF figures produced by the run, then:
  1) changes the engineering-instance description 4->6 UAV, 20->30 customer;
  2) rewrites Table 3 from the new CSV (authoritative);
  3) regenerates the statistical prose (para 111) from the new CSV;
  4) fixes the pair-count prose (para 117: C(4,2)=6 -> C(6,2)=15);
  5) updates the representative-instance / future-work prose (para 115);
  6) replaces the embedded Fig.5-8 images with the new TIFFs (as PNG for Word).
A timestamped backup of the docx is made first.
"""
import os, re, csv, shutil, glob, datetime
from PIL import Image
import docx
from docx.oxml.ns import qn

DOCX = r"C:/Users/USER/Desktop/cn-20260826-review.docx"
PKG  = r"D:/File/GPTTest/uav_delivery/uav_delivery_TIFF_MATLAB"
CSV  = os.path.join(PKG, "data", "comparison_table.csv")
FIGS = os.path.join(PKG, "figs")

assert os.path.exists(CSV), "comparison_table.csv not found - run not finished?"
assert os.path.exists(DOCX), "docx not found"

# ---------- backup ----------
ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
bak = DOCX + f".bak_{ts}"
shutil.copy2(DOCX, bak)
print("backup ->", bak)

# ---------- parse CSV ----------
with open(CSV, encoding="utf-8-sig") as f:
    reader = csv.reader(f)
    rows = [r for r in reader if r and any(c.strip() for c in r)]
header = [re.sub(r"[^a-z]", "", h.lower()) for h in rows[0]]
idx = {name: i for i, name in enumerate(header)}
def col(name):  # fuzzy match
    for k in idx:
        if name in k:
            return idx[k]
    raise KeyError(name)
ci_b, ci_med, ci_mean, ci_std, ci_rank, ci_p = (
    col("best"), col("median"), col("mean"), col("std"),
    [i for k, i in idx.items() if "rank" in k][0],
    [i for k, i in idx.items() if "p" in k][0],
)
ci_algo = idx["algorithm"]
ALGOS = [r[ci_algo].strip() for r in rows[1:]]
data = {}
for r in rows[1:]:
    a = r[ci_algo].strip()
    data[a] = dict(
        best=float(r[ci_b]), median=float(r[ci_med]), mean=float(r[ci_mean]),
        std=float(r[ci_std]), rank=float(r[ci_rank]), p=r[ci_p].strip(),
    )
print("algorithms:", ALGOS)

def f2(x):  # approx 3 significant figures
    return f"{x:.2f}" if abs(x) >= 10 else f"{x:.2f}"

# ---------- derived stats ----------
ipwo = data["iPWO"]; pwo = data["PWO"]
order = sorted(ALGOS, key=lambda a: data[a]["rank"])
rank_ipwo = order.index("iPWO") + 1
top = order[0]
min_std = min(data[a]["std"] for a in ALGOS)
conc = [a for a in ALGOS if data[a]["std"] <= 1.5 * min_std]
conc_sorted = sorted(conc, key=lambda a: data[a]["std"])
conc_range = f"{min(data[a]['std'] for a in conc):.2f}-{max(data[a]['std'] for a in conc):.2f}"
sig = [a for a in ALGOS if a != "iPWO" and data[a]["p"] not in ("-", "") and float(data[a]["p"]) < 0.05]
nonsig = [a for a in ALGOS if a != "iPWO" and a not in sig]
ratio = pwo["std"] / ipwo["std"]
ratio_s = f"{ratio:.0f}" if ratio >= 10 else f"{ratio:.1f}"
best_overall = min(ALGOS, key=lambda a: data[a]["best"])
is_ipwo_best = (best_overall == "iPWO")

def join_cn(names, sep="、"):
    if len(names) == 1:
        return names[0]
    if len(names) == 2:
        return f"{names[0]}{sep}{names[1]}"
    return "、".join(names[:-1]) + " 与 " + names[-1]

def pval_s(a):
    p = data[a]["p"]
    try:
        v = float(p)
        if v == 0 or v < 1e-3:
            return f"{v:.1e}"
        return f"{v:.1e}"
    except Exception:
        return p

sig_clause = join_cn([f"{a}（p={pval_s(a)}）" for a in sig])
nonsig_clause = "/".join(nonsig) if nonsig else "其余算法"

rank_phrase = (f"平均排名 Avg.Rank={ipwo['rank']:.2f}（全场最优）"
               if rank_ipwo == 1 else
               f"平均排名 Avg.Rank={ipwo['rank']:.2f}（位列第{rank_ipwo}，仅次于 {top} 的 {data[top]['rank']:.2f}）")
worst = order[-1]
best_clause = (f"并取得全场最低最优值 {ipwo['best']:.2f} s"
               if is_ipwo_best else
               f"iPWO 最优值为 {ipwo['best']:.2f} s（全场最低为 {best_overall} 的 {data[best_overall]['best']:.2f} s）")

new_p111 = (
    f"51 次独立运行的统计指标显示：iPWO 取得 Best={ipwo['best']:.2f} s、Median={ipwo['median']:.2f} s、"
    f"Mean={ipwo['mean']:.2f} s、Std={ipwo['std']:.3f} s，{rank_phrase}；"
    f"{worst} 表现最差（Best={data[worst]['best']:.2f} s、Median={data[worst]['median']:.2f} s、"
    f"Mean={data[worst]['mean']:.2f} s、Std={data[worst]['std']:.3f} s、Avg.Rank={data[worst]['rank']:.2f}）。"
    f"如 Fig. 7 所示，箱线图（对数刻度）显示 iPWO 箱体接近最低且与 {'/'.join(conc_sorted)} 同属最集中一档"
    f"（Std {conc_range} s）；Wilcoxon 秩和检验（基于 51 次）表明 iPWO 在 p<0.05 水平显著优于 {sig_clause}，"
    f"而与 {nonsig_clause} 的差异未达显著（p>0.05）。值得注意的是，iPWO 相比原始 PWO 将完工时间方差降低约 {ratio_s} 倍"
    f"（{ipwo['std']:.3f} s vs {pwo['std']:.3f} s），{best_clause}，说明其在保持与先进基线相当的均值水平的同时，"
    f"显著抑制了结果离散度、提升了对随机种子的可重复性。上述统计量汇总于表 3（Table 3）。"
)

# ---------- load docx ----------
d = docx.Document(DOCX)

# locate paragraphs
def find_para(substr):  # substring matched against source docx paragraphs; Chinese literals kept verbatim
    for i, p in enumerate(d.paragraphs):
        if substr in p.text:
            return i
    return None

# para 78: scenario
i78 = find_para("设置 Nu=4 架无人机")
if i78 is not None:
    d.paragraphs[i78].text = d.paragraphs[i78].text.replace("Nu=4 架无人机、Nc=20 个客户",
                                                            "Nu=6 架无人机、Nc=30 个客户")
    print("updated para", i78, "(scenario 4->6 / 20->30)")

# para 111: stats
i111 = find_para("51 次独立运行的统计指标显示")
if i111 is not None:
    d.paragraphs[i111].text = new_p111
    print("updated para", i111, "(stats regenerated)")

# para 115: representative instance + future work
i115 = find_para("上述 MTA-PP 对比在单一代表性实例")
if i115 is not None:
    t = d.paragraphs[i115].text
    t = t.replace("N_u=4、N_c=20", "N_u=6、N_c=30")
    t = t.replace("（如 N_u=6、N_c=30）", "（如 N_u=8、N_c=40）")
    d.paragraphs[i115].text = t
    print("updated para", i115, "(instance + future work)")

# para 117: pair count
i117 = find_para("C(4,2)=6 对机间距离")
if i117 is not None:
    t = d.paragraphs[i117].text
    t = t.replace("C(4,2)=6 对机间距离", "C(6,2)=15 对机间距离")
    t = t.replace("全部 6 对均满足", "全部 15 对均满足")
    d.paragraphs[i117].text = t
    print("updated para", i117, "(pair count 6 -> 15)")

# ---------- Table 3 rewrite ----------
def clean_p(p):
    try:
        v = float(p)
        if v < 1e-3:
            return f"{v:.1e}"
        return f"{v:.1e}"
    except Exception:
        return p if p not in ("-", "") else "-"

tbl = d.tables[3]
hdr = [c.text.strip() for c in tbl.rows[0].cells]
# ensure header order: Algorithm | Best | Median | Mean | Std | Avg.Rank | p-value
tbl.rows[0].cells[0].text = "Algorithm"
labels = ["Best (s)", "Median (s)", "Mean (s)", "Std (s)", "Avg.Rank", "p-value"]
for k, lab in enumerate(labels):
    tbl.rows[0].cells[1 + k].text = lab
for r, a in enumerate(ALGOS, start=1):
    row = tbl.rows[r]
    row.cells[0].text = a
    row.cells[1].text = f"{data[a]['best']:.2f}"
    row.cells[2].text = f"{data[a]['median']:.2f}"
    row.cells[3].text = f"{data[a]['mean']:.2f}"
    row.cells[4].text = f"{data[a]['std']:.3f}"
    row.cells[5].text = f"{data[a]['rank']:.2f}"
    row.cells[6].text = clean_p(data[a]["p"])
print("rewrote Table 3")

# ---------- replace embedded Fig.5-8 images (TIFF -> PNG blob) ----------
def tif_to_png(tif_path):
    im = Image.open(tif_path)
    if im.mode != "RGB":
        im = im.convert("RGB")
    # downscale for docx embedding (keep standalone TIFF at full 330 DPI)
    max_w = 1800
    if im.width > max_w:
        h = int(im.height * max_w / im.width)
        im = im.resize((max_w, h), Image.LANCZOS)
    out = tif_path + ".png"
    im.save(out, "PNG", optimize=True)
    return out

mapping = {  # caption fragment -> tif base name
    "Fig. 5": "fig1_scene",
    "Fig. 6": "fig4_convergence",
    "Fig. 7": "fig5_boxplot",
    "Fig. 8": "fig6_conflict",
}
rels = d.part.rels
# find rId for each figure by scanning paragraphs for embed + nearby caption
embed_rids = {}
for i, para in enumerate(d.paragraphs):
    xml = para._p.xml
    for rid in re.findall(r'embed="(rId\d+)"', xml):
        for cap_frag in mapping:
            # search nearby captions within +-3 paragraphs
            for j in range(max(0, i - 3), min(len(d.paragraphs), i + 4)):
                if cap_frag in d.paragraphs[j].text:
                    embed_rids[rid] = cap_frag
                    break
print("figure rIds:", embed_rids)

for rid, cap in embed_rids.items():
    base = mapping[cap]
    tif = glob.glob(os.path.join(FIGS, base + ".tif"))
    if not tif:
        tif = glob.glob(os.path.join(FIGS, base + ".png"))   # fallback (.png ext, TIFF content)
    if not tif:
        print("  WARN: missing", base); continue
    png = tif_to_png(tif[0])
    with open(png, "rb") as fh:
        blob = fh.read()
    rels[rid].blob = blob
    print(f"  replaced {rid} ({cap}) <- {os.path.basename(tif[0])}")

# ---------- save ----------
d.save(DOCX)
print("docx saved:", DOCX)
print("\n--- new para 111 ---\n", new_p111)
