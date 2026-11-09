"""Freeze the complete local V3 release and its smaller Git handoff subset."""
from pathlib import Path
import csv
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
RELEASE = ROOT / 'artifacts/runs/task45_v3'


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def snapshot_file(path):
    """Demos retain full replay data; formal runs retain final results."""
    rel = path.relative_to(ROOT).as_posix()
    if rel.startswith('artifacts/runs/task45_v3/'):
        parts = path.relative_to(RELEASE).parts
        if parts[0] == 'development' or 'review' in parts or 'video_review' in parts:
            return False
        if parts[0] == 'formal' and ('iterations' in parts or path.name == 'input_checkpoint.mat'):
            return False
        if len(parts) == 1 and (path.name.endswith('_log.txt') or path.name.startswith('worker_')):
            return False
        if path.name == 'development_progress.json':
            return False
    return True


def main():
    frozen = read(RELEASE / 'frozen_config.json')
    for record in frozen['metadata']['sources']:
        assert sha(ROOT / 'upgrades/task45_v3/matlab' / record['path']) == record['sha256'], record['path']
    for record in read(RELEASE / 'formal_driver_hashes.json'):
        assert sha(ROOT / record['path']) == record['sha256'], record['path']
    prior = []
    for name in ['TASK45_FILES_SHA256.csv', 'TASK45_V2_FILES_SHA256.csv']:
        with (ROOT / 'docs' / name).open(encoding='utf-8-sig', newline='') as stream:
            rows = list(csv.DictReader(stream))
        for row in rows:
            assert sha(ROOT / row['path']) == row['sha256'], row['path']
        prior.append({'manifest': name, 'verifiedEntries': len(rows), 'manifestSha256': sha(ROOT / 'docs' / name)})
    preservation = {'passed': True, 'priorReleases': prior,
                    'verifiedPriorEntries': sum(x['verifiedEntries'] for x in prior)}
    (RELEASE / 'prior_release_preservation.json').write_text(json.dumps(preservation, indent=2) + '\n', encoding='utf-8')
    for name in ['formal_audit.json', 'demo_audit.json', 'fine_validation.json', 'decision_audit.json',
                 'package_qa.json', 'video_qa.json', 'visual_qa.json', 'assets_matlab_qa.json',
                 'numpy_fk_crosscheck.json']:
        assert read(RELEASE / name)['passed'], name
    formal = read(RELEASE / 'formal_audit.json')
    fine = read(RELEASE / 'fine_validation.json')
    assert formal['runs'] == 40 and fine['checkedSuccessfulPaths'] == formal['successfulRuns']
    selected = set(RELEASE.rglob('*')) | set((ROOT / 'upgrades/task45_v3').rglob('*'))
    selected |= set((ROOT / 'scripts').glob('*task45_v3*'))
    selected |= {ROOT / 'README_TASK45_V3.md', ROOT / 'docs/TASK45_V3_RESULTS.md',
                 ROOT / 'docs/TASK45_V3_PROTOCOL.md', ROOT / 'docs/LOCAL_ARTIFACT_POLICY.md',
                 ROOT / 'scripts/configure_local_artifacts.py', ROOT / 'scripts/show_project_demo.m',
                 ROOT / 'docs/PROJECT_DEMO_GUIDE_ZH.md', ROOT / 'GIT_SNAPSHOT.md'}
    files = sorted(p for p in selected if p.is_file() and '__pycache__' not in p.parts
                   and p.name != 'delivery_checks.json')
    records = {p: (p.relative_to(ROOT).as_posix(), p.stat().st_size, sha(p)) for p in files}
    manifests = []
    for name, subset in [('TASK45_V3_FILES_SHA256.csv', files),
                         ('TASK45_V3_GIT_FILES_SHA256.csv', [p for p in files if snapshot_file(p)])]:
        target = ROOT / 'docs' / name
        is_git_subset = '_GIT_' in name
        with target.open('w', encoding='utf-8', newline='') as stream:
            writer = csv.writer(stream)
            writer.writerow(['path', 'bytes', 'sha256', 'hashMode'])
            for path in subset:
                if is_git_subset and path.suffix.lower() == '.md':
                    content = path.read_bytes().replace(b'\r\n', b'\n')
                    writer.writerow([path.relative_to(ROOT).as_posix(), len(content),
                                     hashlib.sha256(content).hexdigest(), 'markdown-lf'])
                else:
                    writer.writerow([*records[path], 'exact-bytes'])
        manifests.append({'path': target.relative_to(ROOT).as_posix(), 'files': len(subset),
                          'bytes': sum(p.stat().st_size for p in subset), 'sha256': sha(target)})
    receipt = {'passed': True, 'formalCases': formal['runs'], 'formalSuccesses': formal['successfulRuns'],
               'replayedFormalCheckpoints': formal['replayedCheckpoints'],
               'fineJointStep': fine['jointStep'], 'sourceFingerprint': frozen['metadata']['sourceFingerprint'],
               'priorReleaseEntriesVerified': preservation['verifiedPriorEntries'],
               'manifests': manifests,
               'archiveScope': 'Complete local release and smaller Git subset have separate manifests. Formal raw checkpoints remain local; demonstration replay data is included in Git.'}
    (RELEASE / 'delivery_checks.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(receipt, indent=2))


if __name__ == '__main__':
    main()
