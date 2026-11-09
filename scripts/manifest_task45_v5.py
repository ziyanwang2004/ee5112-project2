"""Bind V5 source, audits and data; separately inventory the compact Git set."""
from pathlib import Path
import csv,hashlib,json
ROOT=Path(__file__).resolve().parents[1]
RELEASE=ROOT/'artifacts/runs/task45_v5'
def sha(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def git_file(p):
    if p.is_relative_to(RELEASE):
        parts=p.relative_to(RELEASE).parts
        if parts[0] in ['development','regression','review']:return False
        if parts[0]=='formal' and ('iterations' in parts or 'refinement' in parts or p.name=='input_checkpoint.mat'):return False
        if len(parts)==1 and (p.name.endswith('_log.txt') or p.name.endswith('_progress.json')):return False
    return True
def main():
    frozen=read(RELEASE/'frozen_config.json')
    for row in frozen['metadata']['sources']:assert sha(ROOT/'upgrades/task45_v5/matlab'/row['path'])==row['sha256'],row['path']
    for row in frozen['drivers']+frozen['assetFiles']:assert sha(ROOT/row['path'])==row['sha256'],row['path']
    prior=[]
    for name in ['TASK45_FILES_SHA256.csv','TASK45_V2_FILES_SHA256.csv','TASK45_V3_FILES_SHA256.csv','TASK45_V4_FILES_SHA256.csv']:
        with (ROOT/'docs'/name).open(encoding='utf-8-sig',newline='') as f:rows=list(csv.DictReader(f))
        for row in rows:assert sha(ROOT/row['path'])==row['sha256'],row['path']
        prior.append(dict(manifest=name,verifiedEntries=len(rows),sha256=sha(ROOT/'docs'/name)))
    (RELEASE/'prior_release_preservation.json').write_text(json.dumps(dict(passed=True,manifests=prior,verifiedEntries=sum(p['verifiedEntries'] for p in prior)),indent=2)+'\n',encoding='utf-8')
    checks=['unit_tests','geometry_preflight','v4_sampling_regression','sampling_ablation','sampling_ablation_audit','task4_regression',
        'task4_regression_audit','development_gate','development_audit','formal_audit','numpy_fk_crosscheck','joint_path_diagnostics','compact_verifier_qa','plot_qa','visual_qa']
    for name in checks:assert read(RELEASE/f'{name}.json')['passed'],name
    audit=read(RELEASE/'formal_audit.json');summary=read(RELEASE/'study_summary.json');assert audit['runs']==summary['formalRuns']==75
    assert summary['successes']==audit['fineSuccessfulRuns']
    copied=0
    for arm in ['fixed50','adaptive']:
        source=RELEASE/'development/workcell'/arm/'Task5'/f"seed_{frozen['demoSeed']}"
        target=RELEASE/'demos/workcell'/arm/'Task5'/f"seed_{frozen['demoSeed']}"
        a={p.relative_to(source) for p in source.rglob('*') if p.is_file()};b={p.relative_to(target) for p in target.rglob('*') if p.is_file()};assert a==b
        for name in a:assert sha(source/name)==sha(target/name);copied+=1
    (RELEASE/'demo_copy_audit.json').write_text(json.dumps(dict(passed=True,runs=2,byteIdenticalFiles=copied,sourceAudit='development_audit.json'),indent=2)+'\n',encoding='utf-8')
    selected=set(RELEASE.rglob('*'))|set((ROOT/'upgrades/task45_v5').rglob('*'))|set((ROOT/'scripts').glob('*task45_v5*'))
    selected|={ROOT/'README_TASK45_V5.md',ROOT/'docs/TASK45_V5_PROTOCOL.md',ROOT/'docs/TASK45_V5_RESULTS.md',ROOT/'docs/TASK45_V5_METHODS_ZH.md'}
    files=sorted(p for p in selected if p.is_file() and '__pycache__' not in p.parts and p.name!='delivery_checks.json')
    records={p:(p.relative_to(ROOT).as_posix(),p.stat().st_size,sha(p)) for p in files};inventories=[]
    for name,subset in [('TASK45_V5_FILES_SHA256.csv',files),('TASK45_V5_GIT_FILES_SHA256.csv',[p for p in files if git_file(p)])]:
        path=ROOT/'docs'/name;git='_GIT_' in name
        with path.open('w',encoding='utf-8',newline='') as f:
            writer=csv.writer(f);writer.writerow(['path','bytes','sha256','hashMode'])
            for p in subset:
                if git and p==ROOT/'README_TASK45_V5.md':
                    data=p.read_bytes().replace(b'\r\n',b'\n');writer.writerow([p.relative_to(ROOT).as_posix(),len(data),hashlib.sha256(data).hexdigest(),'markdown-lf'])
                else:writer.writerow([*records[p],'exact-bytes'])
        inventories.append(dict(path=path.relative_to(ROOT).as_posix(),files=len(subset),sha256=sha(path)))
    receipt=dict(passed=True,formalRuns=75,formalNominalSuccesses=audit['successfulRuns'],formalFineSuccesses=audit['fineSuccessfulRuns'],
        replayedCheckpoints=audit['replayedCheckpoints'],sourceFingerprint=frozen['metadata']['sourceFingerprint'],
        priorEntriesVerified=sum(p['verifiedEntries'] for p in prior),manifests=inventories,
        scope='Five-arm Task5 algorithm study, three cases. All failures retained. Complete formal raw replay remains local; probe replay and copied development demos ship in Git.')
    (RELEASE/'delivery_checks.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8');print(json.dumps(receipt,indent=2))
if __name__=='__main__':main()
