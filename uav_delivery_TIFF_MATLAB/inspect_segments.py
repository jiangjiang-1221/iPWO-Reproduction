from docx import Document
from docx.oxml.ns import qn
DOCX = r"C:/Users/JiangWen/Desktop/cn-20260826-review.docx"
d = Document(DOCX)
for i, p in enumerate(d.paragraphs):
    if 104 <= i <= 145:
        has_pic = p._p.find('.//' + qn('w:drawing')) is not None
        t = p.text.replace("\n", " ")[:58]
        print(f"[{i:3d}] {'[PIC]' if has_pic else '     '} {t}")
