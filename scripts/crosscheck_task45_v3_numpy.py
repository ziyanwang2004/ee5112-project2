"""Independently check mounted-tool FK/tilt against all fine-profile CSV states.

Uses the original Task 3 screw/M exports, a 0.20 m mounting translation and
NumPy Rodrigues exponentials. This is not an independent collision checker.
"""
from pathlib import Path
import json
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
RELEASE = ROOT / 'artifacts/runs/task45_v3'


def main():
    base = ROOT / 'artifacts/runs/final_r2023b/Task3'
    screws = np.loadtxt(base / 'space_screws.csv', delimiter=',', skiprows=1)[:, 1:7]
    home = np.loadtxt(base / 'M_end_effector.csv', delimiter=',', skiprows=1)
    records = []
    for path in sorted((RELEASE / 'verification/fine_profiles').glob('*.csv')):
        task_text, _, seed_text = path.stem.partition('_seed_')
        task, seed = int(task_text[-1]), int(seed_text)
        trajectory = RELEASE / 'formal/workcell' / f'Task{task}' / f'seed_{seed}' / 'trajectory.csv'
        nodes = np.loadtxt(trajectory, delimiter=',', skiprows=1)
        profile = np.loadtxt(path, delimiter=',', skiprows=1)
        q = np.column_stack([np.interp(profile[:, 0], np.linspace(0, 1, len(nodes)), nodes[:, j]) for j in range(6)])
        transforms = np.broadcast_to(np.eye(4), (len(q), 4, 4)).copy()
        for j, screw in enumerate(screws):
            x, y, z = screw[:3]
            w = np.array([[0., -z, y], [z, 0., -x], [-y, x, 0.]])
            w2 = w @ w
            angle = q[:, j]
            sine, cosine = np.sin(angle), np.cos(angle)
            step = np.broadcast_to(np.eye(4), transforms.shape).copy()
            step[:, :3, :3] = np.eye(3) + sine[:, None, None]*w + (1-cosine[:, None, None])*w2
            v = screw[3:]
            step[:, :3, 3] = angle[:, None]*v + (1-cosine[:, None])*(w @ v) + (angle-sine)[:, None]*(w2 @ v)
            transforms = transforms @ step
        transforms = transforms @ home
        transforms[:, 2, 3] += .20
        positions = transforms[:, :3, 3]
        tilt = np.degrees(np.arctan2(np.linalg.norm(transforms[:, :2, 1], axis=1), transforms[:, 2, 1]))
        position_error = float(np.max(np.abs(positions-profile[:, 1:4])))
        tilt_error = float(np.max(np.abs(tilt-profile[:, 4])))
        assert position_error < 1e-10 and tilt_error < 1e-8, (task, seed, position_error, tilt_error)
        assert np.all(positions[:, 2] > 0)
        records.append({'task': task, 'seed': seed, 'states': len(q),
                        'maxPositionError_m': position_error, 'maxTiltError_deg': tilt_error})
    assert len(records) == 40
    receipt = {'passed': True, 'paths': len(records), 'states': sum(r['states'] for r in records),
               'maxPositionError_m': max(r['maxPositionError_m'] for r in records),
               'maxTiltError_deg': max(r['maxTiltError_deg'] for r in records),
               'scope': 'Independent NumPy mounted-tool FK and direction calculation; actual collision verification remains the separate MATLAB audit.',
               'records': records}
    (RELEASE / 'numpy_fk_crosscheck.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: v for k, v in receipt.items() if k != 'records'}, indent=2))


if __name__ == '__main__':
    main()
