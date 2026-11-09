"""Freeze audited V4 evidence and a separate compact Git handoff inventory."""
from pathlib import Path
import csv,hashlib,json
ROOT=Path(__file__).resolve().parents[1]
RELEASE=ROOT/'artifacts/runs/task45_v4'
def sha(path):
    with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def read(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def git_file(p):
    if p.is_relative_to(RELEASE):
        parts=p.relative_to(RELEASE).parts
        if parts[0] in ['development','regression','review']:return False
        if parts[0]=='formal' and ('iterations' in parts or 'refinement' in parts or p.name=='input_checkpoint.mat'):return False
        if len(parts)==1 and (p.name.endswith('_log.txt') or p.name.endswith('_progress.json')):return False
    return True
def main():
    frozen=read(RELEASE/'frozen_config.json')
    for row in frozen['metadata']['sources']:
        assert sha(ROOT/'upgrades/task45_v4/matlab'/row['path'])==row['sha256'],row['path']
    for row in frozen['drivers']:assert sha(ROOT/row['path'])==row['sha256'],row['path']
    prior=[]
    for name in ['TASK45_FILES_SHA256.csv','TASK45_V2_FILES_SHA256.csv','TASK45_V3_FILES_SHA256.csv']:
        with (ROOT/'docs'/name).open(encoding='utf-8-sig',newline='') as f:rows=list(csv.DictReader(f))
        for row in rows:assert sha(ROOT/row['path'])==row['sha256'],row['path']
        prior.append({'manifest':name,'verifiedEntries':len(rows),'sha256':sha(ROOT/'docs'/name)})
    (RELEASE/'prior_release_preservation.json').write_text(json.dumps({'passed':True,'manifests':prior,'verifiedEntries':sum(x['verifiedEntries'] for x in prior)},indent=2)+'\n',encoding='utf-8')
    for name in ['unit_tests.json','regression_audit.json','development_audit.json','formal_audit.json','paired_prefix_audit.json','numpy_fk_crosscheck.json','visual_qa.json','plot_qa.json']:
        assert read(RELEASE/name)['passed'],name
    audit=read(RELEASE/'formal_audit.json');summary=read(RELEASE/'study_summary.json')
    assert audit['runs']==summary['formalRuns']==40
    # The demonstrations are exact copies of the already independently audited development records.
    copied=0
    for variant in ['baseline','anytime','tangent','combined']:
        source=RELEASE/'development'/variant/'workcell/Task5'/f"seed_{frozen['demoSeed']}"
        target=RELEASE/'demos'/variant/'workcell/Task5'/f"seed_{frozen['demoSeed']}"
        for p in source.rglob('*'):
            if p.is_file():assert sha(p)==sha(target/p.relative_to(source));copied+=1
    (RELEASE/'demo_copy_audit.json').write_text(json.dumps({'passed':True,'runs':4,'byteIdenticalFiles':copied,'sourceAudit':'development_audit.json'},indent=2)+'\n',encoding='utf-8')
    selected=set(RELEASE.rglob('*'))|set((ROOT/'upgrades/task45_v4').rglob('*'))|set((ROOT/'scripts').glob('*task45_v4*'))
    selected|={ROOT/'README_TASK45_V4.md',ROOT/'docs/TASK45_V4_PROTOCOL.md',ROOT/'docs/TASK45_V4_RESULTS.md'}
    files=sorted(p for p in selected if p.is_file() and '__pycache__' not in p.parts and p.name!='delivery_checks.json')
    records={p:(p.relative_to(ROOT).as_posix(),p.stat().st_size,sha(p)) for p in files}
    inventories=[]
    for name,subset in [('TASK45_V4_FILES_SHA256.csv',files),('TASK45_V4_GIT_FILES_SHA256.csv',[p for p in files if git_file(p)])]:
        target=ROOT/'docs'/name;git='_GIT_' in name
        with target.open('w',encoding='utf-8',newline='') as f:
            writer=csv.writer(f);writer.writerow(['path','bytes','sha256','hashMode'])
            for p in subset:
                # Only the new root README uses Git's automatic text conversion.
                # docs/TASK45* and both V4 trees explicitly use -text attributes.
                if git and p==ROOT/'README_TASK45_V4.md':
                    data=p.read_bytes().replace(b'\r\n',b'\n');writer.writerow([p.relative_to(ROOT).as_posix(),len(data),hashlib.sha256(data).hexdigest(),'markdown-lf'])
                else:writer.writerow([*records[p],'exact-bytes'])
        inventories.append({'path':target.relative_to(ROOT).as_posix(),'files':len(subset),'sha256':sha(target)})
    receipt={'passed':True,'formalRuns':40,'formalSuccesses':audit['successfulRuns'],'replayedCheckpoints':audit['replayedCheckpoints'],
             'sourceFingerprint':frozen['metadata']['sourceFingerprint'],'priorEntriesVerified':sum(x['verifiedEntries'] for x in prior),'manifests':inventories,
             'scope':'Four-arm Task5 algorithm study on the fixed mounted workcell. Complete raw formal replay remains in the local archive; copied development demos include replay inputs.'}
    (RELEASE/'delivery_checks.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8');print(json.dumps(receipt,indent=2))
if __name__=='__main__':main()
