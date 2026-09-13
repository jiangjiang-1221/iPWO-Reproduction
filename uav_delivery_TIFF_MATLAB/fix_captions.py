# 1) 原 Fig.9/10/11 (参数敏感性/运行效率/维度扩展) 顺延为 Fig.10/11/12
# 2) 把"时间窗甘特图"段对从 Fig.6/7 之间移动到 Fig.8 之后，使其成为真正的 Fig.9
# 文档先自动备份。
import os, re, shutil, datetime
from docx import Document
from docx.oxml.ns import qn

DOCX = r"C:/Users/江文/Desktop/cn-20260826-review.docx"
ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
shutil.copy2(DOCX, DOCX + f".bak_{ts}")
print("backup ->", DOCX + f".bak_{ts}")

d = Document(DOCX)

# ---- 1) 顺延 caption ----
caps = [
    ("Fig. 9 Parameter sensitivity", "Fig. 10 Parameter sensitivity"),
    ("Fig. 10 Average runtime", "Fig. 11 Average runtime"),
    ("Fig. 11 Dimension scalability", "Fig. 12 Dimension scalability"),
]
for p in d.paragraphs:
    t = p.text
    for a, b in caps:
        if a in t:
            p.text = t.replace(a, b)
            print("  renamed caption:", a, "->", b)

# ---- 1b) 顺延正文引用 "如 Fig. N" / "如图N" (N=9,10,11) ----
for p in d.paragraphs:
    t = p.text
    def repl(m):
        n = int(m.group(3))
        return f"{m.group(1)}Fig. {n+1}" if n in (9, 10, 11) else m.group(0)
    nt = re.sub(r'(如\s*)(Fig\. )(\d+)', repl, t)
    nt = re.sub(r'(图\s*)(Fig\. )(\d+)', repl, nt)  # 兜底 "如图 9"
    if nt != t:
        p.text = nt
        print("  shifted ref in para:", t[:40], "->", nt[:40])

# ---- 2) 移动甘特图段对到 Fig.8 之后 ----
cap_el = img_el = fig8_el = None
for p in d.paragraphs:
    if "Fig. 9 时间窗可行性甘特图" in p.text:
        cap_el = p._p
        img_el = cap_el.getnext()
for p in d.paragraphs:
    if "Fig. 8 Safety distance" in p.text:
        fig8_el = p._p
        break
if cap_el is None or img_el is None:
    print("  [WARN] 未找到甘特图段对")
elif fig8_el is None:
    print("  [WARN] 未找到 Fig.8")
else:
    body = cap_el.getparent()
    body.remove(cap_el)
    body.remove(img_el)
    fig8_el.addnext(img_el)     # Fig.8 之后先放图
    img_el.addnext(cap_el)      # 图之后再放 caption
    print("  moved 甘特图 to after Fig.8 (now Fig.9)")

d.save(DOCX)
print("docx saved:", DOCX)
