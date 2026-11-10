"""Hide retained machine-local experiment archives from Git's untracked list.

Only .git/info/exclude is edited. Tracked files remain visible to Git.
"""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BEGIN = '# BEGIN EE5112 retained local experiment archives'
END = '# END EE5112 retained local experiment archives'
PATTERNS = [
    '/artifacts/audits/',
    '/artifacts/runs/task45_final/demos/',
    '/artifacts/runs/task45_final/development_evidence/',
    '/artifacts/runs/task45_final/diagnostic_pilot/',
    '/artifacts/runs/task45_final/formal/main/',
    '/artifacts/runs/task45_final/formal/variant/',
    '/artifacts/runs/task45_final/formal/progress.json',
    '/artifacts/runs/task45_final/technical_interruptions/',
    '/artifacts/runs/task45_v2/development/',
    '/artifacts/runs/task45_v2/diagnosis/',
    '/artifacts/runs/task45_v2/delivery/review/',
    '/artifacts/runs/task45_v2/delivery/video_review/',
    '/artifacts/runs/task45_v2/formal/**/iterations/',
    '/artifacts/runs/task45_v2/formal/**/input_checkpoint.mat',
    '/artifacts/runs/task45_v2/*_log.txt',
    '/artifacts/runs/task45_v2/freeze_attempt_1_audit_call_error.txt',
    '/artifacts/runs/task45_v3/development/',
    '/artifacts/runs/task45_v3/*_log.txt',
    '/artifacts/runs/task45_v3/worker_*_progress.json',
    '/artifacts/runs/task45_v3/development_progress.json',
    '/artifacts/runs/task45_v3/formal/**/iterations/',
    '/artifacts/runs/task45_v3/formal/**/input_checkpoint.mat',
    '/artifacts/runs/task45_v3/delivery/review/',
    '/artifacts/runs/task45_v3/delivery/video_review/',
]


def main():
    git_dir = Path(subprocess.check_output(
        ['git', 'rev-parse', '--absolute-git-dir'], cwd=ROOT
    ).decode('utf-8').strip())
    target = git_dir / 'info' / 'exclude'
    original = target.read_text(encoding='utf-8') if target.exists() else ''
    if BEGIN in original:
        before, rest = original.split(BEGIN, 1)
        assert END in rest, 'Incomplete managed block; inspect manually.'
        _, after = rest.split(END, 1)
        original = before.rstrip() + '\n' + after.lstrip('\r\n')
    block = BEGIN + '\n' + '\n'.join(PATTERNS) + '\n' + END + '\n'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(original.rstrip() + '\n\n' + block, encoding='utf-8')
    print(f'Configured {len(PATTERNS)} local archive rules in {target}')
    print('No experiment files were moved or deleted; tracked changes stay visible.')


if __name__ == '__main__':
    main()
