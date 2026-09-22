# 1) original Fig.9/10/11 (parameter sensitivity / runtime efficiency / dimensional scalability) shifted to Fig.10/11/12
# 2) move the "time-window Gantt chart" caption pair from between Fig.6/7 to after Fig.8, making it the real Fig.9
# back up the document automatically first.
import os, re, shutil, datetime
from docx import Document
from docx.oxml.ns import qn

DOCX = r"C:/Users/JiangWen/Desktop/cn-20260826-review.docx"
ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
shutil.copy2(DOCX, DOCX + f".bak_{ts}")
print("backup ->", DOCX + f".bak_{ts}")

d = Document(DOCX)

# ---- 1) shift captions ----
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

# ---- 1b) shift in-text references "e.g. Fig. N" / "Fig.N" (N=9,10,11) ----
for p in d.paragraphs:
    t = p.text
    def repl(m):
        n = int(m.group(3))
        return f"{m.group(1)}Fig. {n+1}" if n in (9, 10, 11) else m.group(0)
    nt = re.sub(r'(\s*)(Fig\. )(\d+)', repl, t)
    nt = re.sub(r'(\s*)(Fig\. )(\d+)', repl, nt)  # fallback for "Fig. 9"
    if nt != t:
        p.text = nt
        print("  shifted ref in para:", t[:40], "->", nt[:40])

# ---- 2) move Gantt caption pair to after Fig.8 ----
cap_el = img_el = fig8_el = None
for p in d.paragraphs:
    if "Fig. 9 Time-window feasibility Gantt" in p.text:
        cap_el = p._p
        img_el = cap_el.getnext()
for p in d.paragraphs:
    if "Fig. 8 Safety distance" in p.text:
        fig8_el = p._p
        break
if cap_el is None or img_el is None:
    print("  [WARN] Gantt caption pair not found")
elif fig8_el is None:
    print("  [WARN] Fig.8 not found")
else:
    body = cap_el.getparent()
    body.remove(cap_el)
    body.remove(img_el)
    fig8_el.addnext(img_el)     # Fig.8 followed by image
    img_el.addnext(cap_el)      # image followed by caption
    print("  moved Gantt to after Fig.8 (now Fig.9)")

d.save(DOCX)
print("docx saved:", DOCX)
