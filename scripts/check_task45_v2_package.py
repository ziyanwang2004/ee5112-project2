"""Validate V2 native PowerPoint, PDF pages, and source-backed table content."""
import json
import posixpath
import zipfile
from pathlib import Path
from urllib.parse import unquote
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
FINAL=ROOT/'artifacts/runs/task45_v2'
OUT=FINAL/'delivery'
A='http://schemas.openxmlformats.org/drawingml/2006/main'
P='http://schemas.openxmlformats.org/presentationml/2006/main'
def main():
    tables=relations=parsed=0
    with zipfile.ZipFile(OUT/'task45_v2_slides.pptx') as z:
        assert z.testzip() is None; names=set(z.namelist())
        slides=sorted(n for n in names if n.startswith('ppt/slides/slide') and n.endswith('.xml') and '/_rels/' not in n)
        assert len(slides)==4
        for name in names:
            if not name.endswith(('.xml','.rels')): continue
            tree=ET.fromstring(z.read(name)); parsed+=1
            if name.endswith('.rels'):
                base='' if name=='_rels/.rels' else name.rsplit('/_rels/',1)[0]
                for relation in tree:
                    if relation.attrib.get('TargetMode')=='External': continue
                    target=unquote(relation.attrib['Target']).split('#',1)[0]
                    resolved=target.lstrip('/') if target.startswith('/') else posixpath.normpath(posixpath.join(base,target))
                    assert resolved in names,(name,resolved); relations+=1
        for name in slides:
            node=ET.fromstring(z.read(name)); tables+=len(node.findall('.//{'+A+'}tbl'))
            for transform in node.findall('.//{'+A+'}xfrm'):
                off=transform.find('{'+A+'}off'); ext=transform.find('{'+A+'}ext')
                if off is None or ext is None: continue
                x,y=int(off.attrib['x']),int(off.attrib['y']); w,h=int(ext.attrib['cx']),int(ext.attrib['cy'])
                assert x>=-12700 and y>=-12700 and x+w<=960*12700+12700 and y+h<=540*12700+12700,(name,x,y,w,h)
        assert tables>=1
        notes=[n for n in names if n.startswith('ppt/notesSlides/notesSlide') and n.endswith('.xml') and '/_rels/' not in n]; assert len(notes)==4
        for name in notes:
            text=''.join(ET.fromstring(z.read(name)).itertext()); assert 'Sources:' in text and any('\u4e00'<=c<='\u9fff' for c in text)
        table=ET.fromstring(z.read('ppt/slides/slide3.xml')).find('.//{'+A+'}tbl'); assert table is not None
        actual=[]
        for row in table.findall('{'+A+'}tr'):
            actual.append([''.join(cell.itertext()) for cell in row.findall('{'+A+'}tc')])
        study=json.loads((FINAL/'formal/study_summary.json').read_text(encoding='utf-8'))
        for row,group in zip(actual[1:],study['groups'],strict=True):
            scene,mode=group['name'].rsplit('_',1)
            expected_label=scene+' / '+{'none':'Task 4','projected':'Task 5','penalty':'penalty only'}[mode]
            assert row[0]==expected_label and row[1]==f"{group['successes']}/{group['n']}"
            expected_time='-' if group['plannerSecondsAll']['median'] is None else f"{group['plannerSecondsAll']['median']:.2f}"
            expected_tilt='-' if group['maxTiltSuccessful']['median'] is None else f"{group['maxTiltSuccessful']['median']:.2f}"
            assert row[2]==expected_time and row[3]==expected_tilt
    import fitz
    pages={}; render=OUT/'review'; render.mkdir(exist_ok=True)
    for name in ['task45_v2_report.pdf','task45_v2_slides.pdf']:
        with fitz.open(OUT/name) as doc:
            assert len(doc)==4,(name,len(doc)); pages[name]=len(doc)
            for i,page in enumerate(doc,1):
                assert page.get_text().strip()
                page.get_pixmap(matrix=fitz.Matrix(1.5,1.5)).save(render/f'{Path(name).stem}_{i}.png')
    receipt={'passed':True,'slides':4,'nativeEditableTables':tables,'chineseNotes':4,'parsedXML':parsed,'relationships':relations,'pdfPages':pages,'tableSourceMatched':True,'renderedForVisualReview':True}
    (FINAL/'package_qa.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(receipt,indent=2))
if __name__=='__main__': main()
