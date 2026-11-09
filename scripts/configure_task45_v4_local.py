"""Retain V4 raw archives locally while keeping final results visible in Git."""
from pathlib import Path
import subprocess
root=Path(__file__).resolve().parents[1]
git_dir=Path(subprocess.check_output(['git','rev-parse','--absolute-git-dir'],cwd=root).decode().strip())
p=git_dir/'info/exclude';text=p.read_text(encoding='utf-8')
marker='# EE5112 V4 local raw archive'
if marker not in text:
    patterns=['/artifacts/runs/task45_v4/development/','/artifacts/runs/task45_v4/regression/',
              '/artifacts/runs/task45_v4/formal/**/iterations/','/artifacts/runs/task45_v4/formal/**/refinement/',
              '/artifacts/runs/task45_v4/formal/**/input_checkpoint.mat','/artifacts/runs/task45_v4/*_log.txt',
              '/artifacts/runs/task45_v4/*_progress.json','/artifacts/runs/task45_v4/review/']
    p.write_text(text.rstrip()+'\n\n'+marker+'\n'+'\n'.join(patterns)+'\n',encoding='utf-8')
print('V4 local archive rules installed; no experiment data removed.')
