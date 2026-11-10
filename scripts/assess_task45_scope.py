"""Independent PoE diagnostics for the scope of the Task 5 evidence."""
import json
import math
from pathlib import Path
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
base=ROOT/'artifacts/runs/final_r2023b/Task3'
S=np.loadtxt(base/'space_screws.csv',delimiter=',',skiprows=1)[:,1:7]
M=np.loadtxt(base/'M_end_effector.csv',delimiter=',',skiprows=1)
axes=[]
for screw in S:
    x,y,z=screw[:3]; axes.append(np.array([[0.,-z,y],[z,0.,-x],[-y,x,0.]]))
def fk(q):
    transform=np.eye(4)
    for screw,W,t in zip(S,axes,q):
        W2=W@W; E=np.eye(4)
        E[:3,:3]=np.eye(3)+math.sin(t)*W+(1-math.cos(t))*W2
        E[:3,3]=(np.eye(3)*t+(1-math.cos(t))*W+(t-math.sin(t))*W2)@screw[3:]
        transform=transform@E
    return transform@M
records=[]; max_length_difference=0.; max_angle_difference=0.
for path in sorted((ROOT/'artifacts/runs/task45_v2/formal').glob('*/Task5/seed_*/trajectory.csv')):
    Q=np.loadtxt(path,delimiter=',',skiprows=1); dense=[Q[0]]
    for a,b in zip(Q[:-1],Q[1:]):
        steps=max(1,math.ceil(float(np.max(np.abs(b-a)))/.0125))
        dense.extend(a+(b-a)*i/steps for i in range(1,steps+1))
    transforms=[fk(q) for q in dense]; positions=np.array([T[:3,3] for T in transforms])
    angles=[math.degrees(math.acos(float(np.clip(T[2,1],-1,1)))) for T in transforms]
    length=float(np.linalg.norm(np.diff(positions,axis=0),axis=1).sum())
    summary=json.loads((path.parent/'summary.json').read_text(encoding='utf-8'))
    max_length_difference=max(max_length_difference,abs(length-summary['toolPathLength']))
    max_angle_difference=max(max_angle_difference,abs(max(angles)-summary['maxOrientationDeg']))
    records.append({'scene':path.parts[-4],'seed':int(path.parent.name.split('_')[1]),
        'minToolZ_m':float(positions[:,2].min()),'toolPathLength_m':length})
assert len(records)==20 and max_length_difference<1e-8 and max_angle_difference<1e-5
result={'scope':'Read-only independent numeric PoE on saved final paths; base-frame z=0 is a diagnostic plane, not an obstacle in the current scene.',
        'paths':len(records),'pathsWithToolBelowBaseZ0':int(sum(r['minToolZ_m']<0 for r in records)),
        'minimumToolZ_m':min(r['minToolZ_m'] for r in records),
        'crossCheckMaxToolLengthDifference_m':max_length_difference,
        'crossCheckMaxTiltDifference_deg':max_angle_difference,
        'binomial10of10ExactTwoSided95LowerBound':.025**.1,
        'binomialModelAssumption':'Independent Bernoulli trials for one fixed scene; not a generalization bound over scenes.',
        'records':records}
out=ROOT/'artifacts/audits/task45_assessment_20261109'; out.mkdir(parents=True,exist_ok=True)
(out/'scope_diagnostics.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in result.items() if k!='records'},indent=2))
