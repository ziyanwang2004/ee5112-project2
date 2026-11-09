"""Preserve the first render, then repair two native table headers only."""
from pathlib import Path
import hashlib
import json
import shutil
import win32com.client

ROOT=Path(__file__).resolve().parents[1]
FINAL=ROOT/'artifacts/runs/task45_v2'
OUT=FINAL/'delivery'
backup=OUT/'review/pre_layout_repair'
assert not backup.exists(); backup.mkdir()
for name in ['task45_v2_slides.pptx','task45_v2_slides.pdf']:
    shutil.copy2(OUT/name,backup/name)
app=win32com.client.DispatchEx('PowerPoint.Application'); count=app.Presentations.Count
deck=app.Presentations.Open(str(OUT/'task45_v2_slides.pptx'),False,False,False)
try:
    tables=[shape for shape in deck.Slides.Item(3).Shapes if shape.HasTable]
    assert len(tables)==1
    table=tables[0].Table
    table.Cell(1,3).Shape.TextFrame.TextRange.Text='Median time\n(s)'
    table.Cell(1,4).Shape.TextFrame.TextRange.Text='Median max tilt\n(deg)'
    for j in [3,4]:
        shape=table.Cell(1,j).Shape
        shape.TextFrame.TextRange.ParagraphFormat.SpaceBefore=0
        shape.TextFrame.TextRange.ParagraphFormat.SpaceAfter=0
    deck.Save(); deck.SaveAs(str(OUT/'task45_v2_slides.pdf'),32)
finally:
    deck.Close()
    if count==0 and app.Presentations.Count==0: app.Quit()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
receipt={'type':'postprocessing-layout-only','planningSourcesChanged':False,'rawRunsChanged':False,
         'originalDeckSha256':sha(backup/'task45_v2_slides.pptx'),'repairedDeckSha256':sha(OUT/'task45_v2_slides.pptx'),
         'changes':['Slide 3 table column 3 and 4 header line breaks','Diagnosis figure title margins'],
         'initialDeckPreserved':str(backup.relative_to(ROOT))}
(FINAL/'layout_repair.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
print('Native table header layout repaired.')
