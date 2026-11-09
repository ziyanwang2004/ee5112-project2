"""Check final evidence identities, original evidence and exported files."""
from __future__ import annotations
import csv
import hashlib
import json
import sys
import zipfile
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
FINAL=ROOT/'artifacts/runs/task45_final'


def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024),b''):
            h.update(chunk)
    return h.hexdigest()


def main():
    frozen=json.loads((FINAL/'frozen_config.json').read_text(encoding='utf-8-sig'))
    expected=50 if frozen['parameters']['constraintMode']=='projected' else 40
    summaries=[json.loads(p.read_text(encoding='utf-8-sig')) for p in (FINAL/'formal').glob('**/summary.json')]
    assert len(summaries)==expected
    identities={(r['scenario'],r['mode'],r['seed']) for r in summaries}
    assert len(identities)==expected
    source=frozen['metadata']['sourceFingerprint']
    for r in summaries:
        assert r['seed'] in range(5120,5130) and r['sourceFingerprint']==source
        assert r['success']==(not r['failures'])
        if r['success']:
            assert r['minVoxelClearance']>=.035-1e-9
            if r['task']==5: assert r['maxOrientationDeg']<=5+1e-8
    patch_path=FINAL/'provenance/postprocessing_patch.json'
    patch=json.loads(patch_path.read_text()) if patch_path.exists() else None
    changes={r['path']:r for r in patch['changes']} if patch else {}
    if patch:
        assert set(changes)=={'+memberC/aggregateStudy.m','run_task45_benchmark.m'}
        assert patch['originalSourceFingerprint']==source
        assert not patch['planningParametersChanged'] and not patch['rawResultsChanged']
    current_records=[]
    for record in frozen['metadata']['sources']:
        expected_hash=record['sha256']
        if record['path'] in changes:
            change=changes[record['path']]
            assert change['originalSha256']==expected_hash
            assert sha(FINAL/change['snapshotPath'])==expected_hash
            expected_hash=change['patchedSha256']
        assert sha(ROOT/'matlab'/record['path'])==expected_hash,record['path']
        current_records.append({'path':record['path'],'sha256':expected_hash})
    current_source=hashlib.sha256(json.dumps(current_records,ensure_ascii=False,separators=(',',':')).encode()).hexdigest()
    assert current_source==(patch['approvedSourceFingerprint'] if patch else source)
    original=0; checkout_crlf_only=[]
    with (ROOT/'docs/FILES_SHA256.csv').open(encoding='utf-8-sig',newline='') as f:
        for row in csv.DictReader(f):
            if row['path'].startswith('artifacts/runs/final_r2023b/'):
                path=ROOT/row['path']
                if sha(path)!=row['sha256']:
                    assert path.suffix in {'.csv','.txt','.json','.md'},row['path']
                    assert hashlib.sha256(path.read_bytes().replace(b'\r\n',b'\n')).hexdigest()==row['sha256'],row['path']
                    checkout_crlf_only.append(row['path'])
                original+=1
    assert original>30
    audit=json.loads((FINAL/'independent_audit.json').read_text(encoding='utf-8-sig'))
    assert audit['passed'] and audit['runs']==expected+4
    export=json.loads((FINAL/'demos/exports/export_manifest.json').read_text(encoding='utf-8-sig'))
    assert len(export['videos'])==6 and export['framesPerVideo']==150 and export['framesPerSecond']==15
    for path in export['videos']+export['figures']:
        assert Path(path).is_file()
    import fitz
    pages={}
    for name in ['task45_report.pdf','task45_slides.pdf']:
        with fitz.open(FINAL/'delivery'/name) as pdf:
            pages[name]=len(pdf)
            assert all(page.get_text().strip() for page in pdf)
    assert pages['task45_slides.pdf']==4
    events=list((FINAL/'technical_interruptions').glob('**/interruption_receipt.json'))
    if events:
        recovery=json.loads((FINAL/'recovery_audit.json').read_text(encoding='utf-8-sig'))
        assert recovery['passed'] and recovery['interruptedAttempts']==len(events)
        for event in events:
            record=json.loads(event.read_text(encoding='utf-8-sig'))
            assert not record['completedNominalRun'] and record['includedInAttemptStatistics']
            assert record['sourceFingerprint']==source
            for item in record['files']:
                assert sha(event.parent/item['path'])==item['sha256']
    accounting=json.loads((FINAL/'attempt_accounting.json').read_text(encoding='utf-8-sig'))
    assert accounting['completedNominalCases']==expected and accounting['technicalInterruptions']==len(events)
    assert accounting['observedAttempts']==expected+len(events)
    ns={'p':'http://schemas.openxmlformats.org/presentationml/2006/main',
        'a':'http://schemas.openxmlformats.org/drawingml/2006/main'}
    with zipfile.ZipFile(FINAL/'delivery/task45_slides.pptx') as z:
        slides=[n for n in z.namelist() if n.startswith('ppt/slides/slide') and n.endswith('.xml') and '/_rels/' not in n]
        assert len(slides)==4
        assert any(ET.fromstring(z.read(n)).find('.//a:tbl',ns) is not None for n in slides)
        notes=[n for n in z.namelist() if n.startswith('ppt/notesSlides/notesSlide') and n.endswith('.xml') and '/_rels/' not in n]
        assert len(notes)==4
        for n in notes:
            text=''.join(ET.fromstring(z.read(n)).itertext())
            assert 'Sources:' in text and any('\u4e00'<=c<='\u9fff' for c in text)
    # Manifest excludes itself and its receipt; no circular checksums.
    selected=set((ROOT/'matlab').rglob('*.m'))|set((ROOT/'scripts').glob('*.py'))
    selected|=set((ROOT/'matlab/data').glob('*'))
    selected|=set((ROOT/'scripts').glob('*.ps1'))
    selected|=set((ROOT/'scripts').glob('*.m'))
    selected|=set(FINAL.rglob('*'))
    selected|={ROOT/'README.md',ROOT/'.gitignore',ROOT/'.gitattributes',ROOT/'docs/METHODS.md',
               ROOT/'docs/TASK45_METHODS.md',ROOT/'docs/TASK45_RUNBOOK.md',ROOT/'docs/TASK45_RESULTS.md'}
    manifest=ROOT/'docs/TASK45_FILES_SHA256.csv'
    files=sorted(p for p in selected if p.is_file() and p.name!='delivery_checks.json')
    with manifest.open('w',encoding='utf-8',newline='') as f:
        writer=csv.writer(f); writer.writerow(['path','bytes','sha256'])
        writer.writerows((p.relative_to(ROOT).as_posix(),p.stat().st_size,sha(p)) for p in files)
    receipt={'passed':True,'formalRuns':expected,'formalSuccesses':sum(r['success'] for r in summaries),
             'technicalInterruptedAttempts':len(events),'observedAttempts':expected+len(events),
             'originalFrozenFilesContentUnchanged':original,'checkoutCRLFOnly':checkout_crlf_only,
             'independentAuditedRuns':audit['runs'],
             'replayedCheckpoints':audit['replayedCheckpoints'],'videos':6,'pages':pages,
             'manifestFiles':len(files),'manifestSha256':sha(manifest),'sourceFingerprint':source,
             'postprocessingSourceFingerprint':current_source,'postprocessingPatchedFiles':list(changes)}
    (FINAL/'delivery_checks.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(receipt,indent=2))


if __name__=='__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main()
