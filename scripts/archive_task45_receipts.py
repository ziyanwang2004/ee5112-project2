"""Archive development summaries and Windows baseline receipts without reruns."""
import json
import shutil
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
FINAL=ROOT/'artifacts/runs/task45_final'


def copy_once(source,target):
    assert source.is_file(),source
    if target.exists():
        assert target.read_bytes()==source.read_bytes(),target
        return
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(source,target)


def main():
    frozen=json.loads((FINAL/'frozen_config.json').read_text(encoding='utf-8-sig'))
    dev=Path(frozen['developmentRoot'])
    state=json.loads((dev/'development_state.json').read_text(encoding='utf-8-sig'))
    assert state['phase']=='frozen'
    for name in ['development_results.csv','development_state.json','source_identity.json']:
        copy_once(dev/name,FINAL/'development_evidence'/name)
    if (dev/'feasible_priority_regression.json').exists():
        copy_once(dev/'feasible_priority_regression.json',FINAL/'development_evidence/feasible_priority_regression.json')
    names={'summary.json','trajectory.csv','dense_validation.csv','cost_history.csv'}
    for source in dev.rglob('*'):
        if source.is_file() and source.name in names:
            copy_once(source,FINAL/'development_evidence'/source.relative_to(dev))
    pilot=ROOT/'artifacts/local_runs/task45_development/protocol_20261105'
    if (pilot/'PILOT_RETAINED.json').exists():
        for name in ['PILOT_RETAINED.json','development_results.csv','development_state.json']:
            copy_once(pilot/name,FINAL/'diagnostic_pilot'/name)
    baseline=ROOT/'artifacts/local_runs/task45_baseline_20261105'
    for relative in ['linux_windows_portability.json','BASELINE_PASSED.txt',
                     'windows_fresh/verification_summary.json','after_hook/regression_passed.json']:
        copy_once(baseline/relative,FINAL/'baseline_evidence'/relative)
    print('Archived development summaries and original-task regression receipts.')


if __name__=='__main__': main()
