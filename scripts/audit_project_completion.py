"""Read-only inventory and frozen evidence checks for the whole project."""
import csv
import hashlib
import json
import subprocess
from collections import Counter
from pathlib import Path
import fitz

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'artifacts/audits/project_completion_20261109'
OUT.mkdir(parents=True,exist_ok=True)
def sha(path):
    with path.open('rb') as stream: return hashlib.file_digest(stream,'sha256').hexdigest()
def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def check_manifest(path,allow_crlf=False):
    with path.open(encoding='utf-8-sig',newline='') as stream: rows=list(csv.DictReader(stream))
    crlf=[]; changed=[]
    for row in rows:
        target=ROOT/row['path']
        if not target.is_file(): changed.append(row['path']); continue
        if sha(target)==row['sha256']: continue
        if allow_crlf and hashlib.sha256(target.read_bytes().replace(b'\r\n',b'\n')).hexdigest()==row['sha256']:
            crlf.append(row['path'])
        else: changed.append(row['path'])
    return {'manifest':path.relative_to(ROOT).as_posix(),'entries':len(rows),
            'bytes':sum(int(r['bytes']) for r in rows),'changed':changed,'checkoutCRLFOnly':crlf}

checks=[check_manifest(ROOT/'docs/TASK45_FILES_SHA256.csv'),check_manifest(ROOT/'docs/TASK45_V2_FILES_SHA256.csv')]
assert all(not item['changed'] for item in checks),'Frozen release hash mismatch.'
original=check_manifest(ROOT/'docs/FILES_SHA256.csv',True)
assert set(original['changed'])=={'.gitattributes','.gitignore','README.md','docs/METHODS.md','matlab/helperSTOMP.m'}
source=check_manifest(ROOT/'provenance/SOURCE_SHA256.csv',True)
assert source['changed']==['matlab/helperSTOMP.m'],'Unexpected baseline source change.'

brief=ROOT.parent/'EE5112_Project-2_AY26-27.pdf'
assert sha(brief)=='6fb9421e4132f2978502d2b288917d3ed36058f768af50b4b00c708213663723'
with fitz.open(brief) as doc:
    text='\n'.join(f'PAGE {i+1}\n'+page.get_text() for i,page in enumerate(doc))
    (OUT/'official_requirements.txt').write_text(text,encoding='utf-8')
    assert len(doc)==5

release=ROOT/'artifacts/runs/task45_v2'
summaries=[read(p) for p in (release/'formal').glob('**/summary.json')]
assert len(summaries)==50
groups={}
for row in summaries:
    key=row['scenario']+'_'+row['mode']
    group=groups.setdefault(key,{'n':0,'successes':0,'failures':Counter()})
    group['n']+=1; group['successes']+=int(row['success']); group['failures'].update(row['failures'])
assert all(groups[key]['successes']==10 for key in ['main_none','variant_none','main_projected','variant_projected'])
assert groups['main_penalty']['successes']==0 and groups['main_penalty']['failures']['orientation']==10

pdfs=[]; pptx=[]; archives=[]; sizes=Counter()
for path in ROOT.rglob('*'):
    if not path.is_file() or '.git' in path.parts: continue
    relative=path.relative_to(ROOT); sizes[relative.parts[0]]+=path.stat().st_size
    # Final authored documents, excluding private rendering and source snapshots.
    if any(x in relative.parts for x in ['review','source_snapshot','local_runs']): continue
    if path.suffix.lower()=='.pdf':
        with fitz.open(path) as doc:
            pdfs.append({'path':relative.as_posix(),'pages':len(doc),'firstPage':doc[0].get_text()[:250]})
    elif path.suffix.lower()=='.pptx': pptx.append(relative.as_posix())
    elif path.suffix.lower()=='.zip': archives.append(relative.as_posix())

report={
    'clientDate':'2026-11-09','officialBriefSha256':sha(brief),'officialBriefPages':5,
    'frozenManifests':checks,'originalHandoffManifest':original,'baselineSource':source,
    'formalGroups':groups,'pdfs':pdfs,'presentations':pptx,'submissionZipCandidates':archives,
    'workspaceBytesByTopDirectory':dict(sizes),
    'gitHead':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
    'gitBranch':subprocess.check_output(['git','branch','--show-current'],cwd=ROOT,text=True).strip(),
    'gitStatus':subprocess.check_output(['git','status','--short'],cwd=ROOT,text=True),
    'scope':'Current local workspace plus separately recorded live GitHub branch query. No Canvas submission or oral understanding verification.'}
(OUT/'static_audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'frozenFilesVerified':sum(x['entries'] for x in checks),'baselineSourceChanges':source['changed'],
                  'pdfs':len(pdfs),'pptx':len(pptx),'zipCandidates':len(archives),'formalGroups':groups},indent=2))
