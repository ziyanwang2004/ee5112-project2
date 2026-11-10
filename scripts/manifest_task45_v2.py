"""Create a separate V2 handoff manifest after computation and visual QA."""
import csv
import hashlib
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
FINAL=ROOT/'artifacts/runs/task45_v2'
def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda:f.read(1024*1024),b''): h.update(block)
    return h.hexdigest()
frozen=json.loads((FINAL/'frozen_config.json').read_text(encoding='utf-8'))
for record in frozen['metadata']['sources']:
    assert sha(ROOT/'upgrades/task45_v2/matlab'/record['path'])==record['sha256'],record['path']
for record in frozen['drivers']:
    assert sha(ROOT/record['path'])==record['sha256'],record['path']
audit=json.loads((FINAL/'formal/independent_audit.json').read_text(encoding='utf-8'))
study=json.loads((FINAL/'formal/study_summary.json').read_text(encoding='utf-8'))
assert audit['passed'] and audit['runs']==50 and study['totalRuns']==50
assert json.loads((FINAL/'v1_preservation_check.json').read_text())['verifiedFiles']==6458
assert json.loads((FINAL/'package_qa.json').read_text())['passed']
assert json.loads((FINAL/'visual_qa.json').read_text())['passed']
assert json.loads((FINAL/'public_entrypoints_qa.json').read_text())['passed']
assert json.loads((FINAL/'video_qa.json').read_text())['passed']
selected=set(FINAL.rglob('*'))|set((ROOT/'upgrades/task45_v2').rglob('*'))
selected|=set((ROOT/'scripts').glob('*task45_v2*'))
selected|={ROOT/'README_TASK45_V2.md',ROOT/'scripts/diagnose_task5_v1.m',ROOT/'scripts/probe_task5_collision.m',ROOT/'scripts/check_task45_v1_preserved.py',ROOT/'docs/TASK5_V1_FAILURE_ANALYSIS.md',ROOT/'docs/TASK45_V2_RESULTS.md',ROOT/'docs/TASK45_V2_HANDOFF_ZH.md'}
files=sorted(p for p in selected if p.is_file() and p.name!='delivery_checks.json' and '__pycache__' not in p.parts)
manifest=ROOT/'docs/TASK45_V2_FILES_SHA256.csv'
with manifest.open('w',encoding='utf-8',newline='') as stream:
    writer=csv.writer(stream); writer.writerow(['path','bytes','sha256']); writer.writerows((p.relative_to(ROOT).as_posix(),p.stat().st_size,sha(p)) for p in files)
receipt={'passed':True,'formalCases':50,'formalSuccesses':study['successfulRuns'],'sourceFingerprint':frozen['metadata']['sourceFingerprint'],'manifestFiles':len(files),'manifestSha256':sha(manifest),'originalV1Unchanged':True}
(FINAL/'delivery_checks.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
print(json.dumps(receipt,indent=2))
