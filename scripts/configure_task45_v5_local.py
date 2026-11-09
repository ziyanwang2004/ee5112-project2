from pathlib import Path
import subprocess
root=Path(__file__).resolve().parents[1]
git_dir=Path(subprocess.check_output(['git','rev-parse','--absolute-git-dir'],cwd=root).decode().strip())
p=git_dir/'info/exclude';content=p.read_text(encoding='utf-8');marker='# EE5112 V5 local raw archive'
if marker not in content:
    patterns=['/artifacts/runs/task45_v5/development/','/artifacts/runs/task45_v5/regression/',
        '/artifacts/runs/task45_v5/formal/**/iterations/','/artifacts/runs/task45_v5/formal/**/refinement/',
        '/artifacts/runs/task45_v5/formal/**/input_checkpoint.mat','/artifacts/runs/task45_v5/*_log.txt',
        '/artifacts/runs/task45_v5/*_progress.json','/artifacts/runs/task45_v5/review/']
    p.write_text(content.rstrip()+'\n\n'+marker+'\n'+'\n'.join(patterns)+'\n',encoding='utf-8')
print('V5 raw archives retained locally; no data removed.')
