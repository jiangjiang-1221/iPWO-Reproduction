import re
from docx import Document
DOCX = r"C:/Users/江文/Desktop/cn-20260826-review.docx"
d = Document(DOCX)
paras = d.paragraphs

print("===== 关键段落（含关键词）=====")
keys = ["时间窗", "约束", "增广", "目标", "makespan", "代价 Z", "Table", "Fig.", "Wilcoxon", "六类", "MTA", "VRPTW", "容量", "31", "30 个", "6 架"]
for i, p in enumerate(paras):
    if any(k in p.text for k in keys):
        t = p.text.replace("\n", " ")
        print(f"[{i:3d}] {t[:110]}")

print("\n===== 图片 rId + 邻近 caption =====")
for i, p in enumerate(paras):
    xml = p._p.xml
    for rid in re.findall(r'embed="(rId\d+)"', xml):
        # 向前向后搜 caption
        cap = ""
        for j in range(max(0,i-3), min(len(paras), i+4)):
            if "Fig." in paras[j].text:
                cap = paras[j].text.strip()[:80]; break
        print(f"{rid} @para{i}: {cap}")

print("\n===== Table 3 内容 =====")
for ti, tbl in enumerate(d.tables):
    txt = [[c.text.strip() for c in r.cells] for r in tbl.rows]
    flat = " | ".join(" / ".join(r) for r in txt)
    if "iPWO" in flat or "Best" in flat:
        print(f"-- table {ti} --")
        for r in txt:
            print("  ", " | ".join(r))
