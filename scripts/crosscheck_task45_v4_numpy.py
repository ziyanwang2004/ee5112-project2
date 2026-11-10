"""Recompute V4 tool direction and path metrics using independent NumPy PoE.

Uses archived Task 3 screws/home transform plus the 0.20 m mount. This checks
the saved nominal dense profiles, not mesh collision or continuous safety.
"""
from pathlib import Path
import json
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
RELEASE = ROOT / 'artifacts/runs/task45_v4'


def main():
    base = ROOT / 'artifacts/runs/final_r2023b/Task3'
    screws = np.loadtxt(base / 'space_screws.csv', delimiter=',', skiprows=1)[:, 1:7]
    home = np.loadtxt(base / 'M_end_effector.csv', delimiter=',', skiprows=1)
    records = []
    for path in sorted((RELEASE / 'formal').glob('**/summary.json')):
        row = json.loads(path.read_text())
        nodes = np.loadtxt(path.parent / 'trajectory.csv', delimiter=',', skiprows=1)
        profile = np.loadtxt(path.parent / 'dense_validation.csv', delimiter=',', skiprows=1)
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
        tilt_error = float(np.max(np.abs(tilt-profile[:, 3])))
        length_error = abs(float(np.linalg.norm(np.diff(positions, axis=0), axis=1).sum())-row['toolPathLength'])
        height_error = abs(float(positions[:, 2].min())-row['minToolHeight'])
        assert tilt_error < 1e-8 and length_error < 1e-9 and height_error < 1e-10, (row['variant'], row['seed'])
        if row['success']:
            assert tilt.max() <= 5+1e-8 and positions[:, 2].min() >= 0
        records.append({'variant': row['variant'], 'seed': row['seed'], 'states': len(q),
                        'maxTiltError_deg': tilt_error, 'toolLengthError_m': length_error,
                        'minHeightError_m': height_error})
    assert len(records) == 40
    assert {(r['variant'], r['seed']) for r in records} == {(v, s) for v in ['baseline', 'anytime', 'tangent', 'combined'] for s in range(5600, 5610)}
    receipt = {'passed': True, 'paths': 40, 'states': sum(r['states'] for r in records),
               'maxTiltError_deg': max(r['maxTiltError_deg'] for r in records),
               'maxToolLengthError_m': max(r['toolLengthError_m'] for r in records),
               'maxMinHeightError_m': max(r['minHeightError_m'] for r in records),
               'scope': 'Independent NumPy FK/tilt/tool metrics at saved nominal dense states; mesh collision and finer validation remain separate MATLAB checks.',
               'records': records}
    (RELEASE / 'numpy_fk_crosscheck.json').write_text(json.dumps(receipt, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({k: v for k, v in receipt.items() if k != 'records'}, indent=2))


if __name__ == '__main__':
    main()
