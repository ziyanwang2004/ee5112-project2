"""Read-only package, data and media checks; then write a handoff manifest/ZIP."""
from __future__ import annotations
import csv
import hashlib
import io
import json
import posixpath
import re
import zipfile
import xml.etree.ElementTree as E
from pathlib import Path
from urllib.parse import unquote

import fitz
import openpyxl

OUT=Path(__file__).resolve().parents[1]
ROOT=OUT.parents[1]
PRIVATE=ROOT/'artifacts/local_runs/task45_presentation_20261110'
P='http://schemas.openxmlformats.org/presentationml/2006/main'
A='http://schemas.openxmlformats.org/drawingml/2006/main'
C='http://schemas.openxmlformats.org/drawingml/2006/chart'
REL='http://schemas.openxmlformats.org/package/2006/relationships'


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def check_pptx(path,n,media_stems):
    with zipfile.ZipFile(path) as z:
        names=z.namelist();assert z.testzip() is None
        slides=sorted(n for n in names if re.fullmatch(r'ppt/slides/slide\d+\.xml',n))
        notes=[n for n in names if re.fullmatch(r'ppt/notesSlides/notesSlide\d+\.xml',n)]
        assert len(slides)==n and len(notes)==n
        external_media=[]
        valid_native_media_markers=0
        for name in names:
            if name.endswith('.rels'):
                for r in E.fromstring(z.read(name)):
                    if r.get('TargetMode')=='External' and any(x in r.get('Type','') for x in ['video','audio','media','chart','package']):external_media.append((name,r.attrib))
                    if r.get('TargetMode')!='External':
                        owner_dir=posixpath.dirname(name).replace('/_rels','')
                        target=unquote(r.get('Target',''))
                        resolved=posixpath.normpath(posixpath.join(owner_dir,target)).lstrip('/')
                        if name=='_rels/.rels':resolved=posixpath.normpath(target).lstrip('/')
                        assert resolved in names,(name,resolved)
        for part in slides:
            root=E.fromstring(z.read(part))
            rel_part=posixpath.dirname(part)+'/_rels/'+posixpath.basename(part)+'.rels'
            rel_ids={r.get('Id') for r in E.fromstring(z.read(rel_part))}
            for element in root.iter():
                for attr,value in element.attrib.items():
                    if not attr.startswith('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}'):continue
                    if value:assert value in rel_ids,(part,value)
                    else:
                        assert element.tag==f'{{{A}}}hlinkClick' and element.get('action')=='ppaction://media',(part,element.attrib)
                        valid_native_media_markers+=1
        assert not external_media
        media=[p for p in names if p.startswith('ppt/media/') and p.endswith('.mp4')]
        expected={sha(OUT/'media'/f'{s}.mp4') for s in media_stems}
        actual={hashlib.sha256(z.read(x)).hexdigest() for x in media}
        assert actual==expected,(path,actual,expected)
        tables=sum(len(E.fromstring(z.read(p)).findall(f'.//{{{A}}}tbl')) for p in slides)
        charts=[p for p in names if re.fullmatch(r'ppt/charts/chart\d+\.xml',p)]
        if n==16:
            assert len(charts)==2
            for k,column in [(1,'orientation_deg'),(2,'voxel_gap_m')]:
                chart_part=f'ppt/charts/chart{k}.xml'
                chart=E.fromstring(z.read(chart_part))
                rels=E.fromstring(z.read(f'ppt/charts/_rels/chart{k}.xml.rels'))
                rid=chart.find(f'{{{C}}}externalData').get('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id')
                target=next(r.get('Target') for r in rels if r.get('Id')==rid)
                workbook_part=posixpath.normpath(posixpath.join(posixpath.dirname(chart_part),target))
                wb=openpyxl.load_workbook(io.BytesIO(z.read(workbook_part)),read_only=True,data_only=True)
                sheet=wb['Evidence'];values=list(sheet.iter_rows(values_only=True))
                series=chart.findall(f'.//{{{C}}}scatterChart/{{{C}}}ser')
                assert len(series)==3
                for j,task in enumerate([4,5]):
                    with (OUT/'evidence'/f'task{task}_demo_dense.csv').open(encoding='utf-8') as f:rows=list(csv.DictReader(f))
                    cache=[float(v.text) for v in series[j].findall(f'{{{C}}}yVal/{{{C}}}numRef/{{{C}}}numCache/{{{C}}}pt/{{{C}}}v')]
                    assert len(cache)==len(rows)
                    for i,r in enumerate(rows,2):
                        value=float(r[column])*(1000 if column.endswith('_m') else 1)
                        assert abs(values[i-1][2*j+1]-value)<1e-10
                        assert abs(cache[i-2]-value)<1e-10
                wb.close()
            hidden=[]
            for i in range(1,17):
                s=E.fromstring(z.read(f'ppt/slides/slide{i}.xml'))
                if s.get('show')=='0':hidden.append(i)
            assert hidden==list(range(5,17)),hidden
        text=' '.join(' '.join(t.text or '' for t in E.fromstring(z.read(p)).findall(f'.//{{{A}}}t')) for p in slides)
        assert all(t in text for t in ['20/20','30.42','68.19','0.997','35.23','92 / 181'])
        assert all('Sources:' in z.read(p).decode('utf-8') for p in notes)
        return dict(file=path.name,slides=n,embeddedVideoCount=len(media),nativeTables=tables,nativeCharts=len(charts),
            externalMedia=external_media,validNativeMediaMarkers=valid_native_media_markers)


def main():
    receipt=json.loads((PRIVATE/'powerpoint_readback.json').read_text(encoding='utf-8'))
    assert receipt['passed'],receipt
    decks=[check_pptx(OUT/'task45_main.pptx',4,['task5_motion','paired_motion']),
           check_pptx(OUT/'task45_full.pptx',16,['task4_motion','task5_motion','paired_motion'])]
    pages={}
    for name,expected in [('task45_main',4),('task45_full',16),('project_understanding_zh',9),
                          ('speaker_script_zh_en',3),('task45_report_section_en',4)]:
        doc=fitz.open(OUT/f'{name}.pdf');assert len(doc)==expected,(name,len(doc))
        assert all(page.get_text().strip() for page in doc)
        assert not any('\ufffd' in page.get_text() for page in doc)
        pages[name]=len(doc)
    media=json.loads((PRIVATE/'video_qa.json').read_text(encoding='utf-8'))
    assert media['passed'] and all(v['sha256']==sha(OUT/'media'/f"{v['name']}.mp4") for v in media['videos'])
    creation=json.loads((PRIVATE/'powerpoint_creation.json').read_text(encoding='utf-8'))
    lines=['# 备份页中文备注与来源','', '正常主讲使用前4页。完整PPT的第5–16页默认隐藏，供答辩时按页号跳转。','']
    for note in creation['notes']:
        lines.extend([f"## 第{note['slide']}页：{note['title']}",'',note['chinese'],'','依据：'+note['source'],''])
    (OUT/'backup_notes_zh.md').write_text('\n'.join(lines),encoding='utf-8')
    sources=json.loads((OUT/'evidence/source_assets.json').read_text(encoding='utf-8'))
    assert all(sha(ROOT/s['source'])==s['sha256'] for s in sources)
    result=dict(passed=True,decks=decks,pdfPages=pages,videoFrames=sum(x['frames'] for x in media['videos']),
        nativeChartValuesMatchSavedCsv=True,sourceAssetsUnchanged=True)
    (PRIVATE/'delivery_check.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    files=sorted(p for p in OUT.rglob('*') if p.is_file() and '__pycache__' not in p.parts
        and not p.name.startswith('~$') and p.name!='FILES_SHA256.csv')
    with (OUT/'FILES_SHA256.csv').open('w',encoding='utf-8',newline='') as f:
        writer=csv.writer(f);writer.writerow(['path','bytes','sha256'])
        for p in files:writer.writerow([p.relative_to(OUT).as_posix(),p.stat().st_size,sha(p)])
    target=OUT.parent/'task45_20261110_bundle.zip'
    with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED) as z:
        for p in [*files,OUT/'FILES_SHA256.csv']:z.write(p,Path(OUT.name)/p.relative_to(OUT))
    with zipfile.ZipFile(target) as z:assert z.testzip() is None
    target.with_suffix('.sha256').write_text(sha(target)+'  '+target.name+'\n',encoding='ascii')
    print(json.dumps(dict(**result,bundle=str(target),bundleBytes=target.stat().st_size),indent=2))


if __name__=='__main__':main()
