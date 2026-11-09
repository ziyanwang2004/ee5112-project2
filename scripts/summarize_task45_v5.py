"""Describe every formal case; paired comparisons require joint fine success."""
from pathlib import Path
import csv,json,math
from statistics import median
ROOT=Path(__file__).resolve().parents[1]
RELEASE=ROOT/'artifacts/runs/task45_v5'
CASES=['workcell','endpoints','layout']
ARMS=['ambient','energy_control','fixed50','fixed75','adaptive']

def read(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def joint_shape(folder,row):
    with (folder/'trajectory.csv').open(encoding='utf-8-sig',newline='') as f:
        q=[[float(r[f'q{j}_rad']) for j in range(1,7)] for r in csv.DictReader(f)]
    assert len(q)==row['nWaypoints']
    changes=[max(abs(q[i+1][j]-q[i][j]) for i in range(len(q)-1)) for j in range(6)]
    roughness=[.5*sum((q[i+2][j]-2*q[i+1][j]+q[i][j])**2 for i in range(len(q)-2)) for j in range(6)]
    length=sum(math.sqrt(sum((q[i+1][j]-q[i][j])**2 for j in range(6))) for i in range(len(q)-1))
    assert abs(sum(roughness)-row['smoothness'])<1e-8 and abs(length-row['jointPathLength'])<1e-8
    dominant=max(range(6),key=lambda j:roughness[j])
    return dict(scenario=row['scenario'],variant=row['variant'],seed=row['seed'],
        maxAdjacentChangeRadPerJoint=changes,smoothnessPerJoint=roughness,maxAdjacentChangeRad=max(changes),
        dominantSmoothnessJoint=dominant+1,dominantSmoothnessFraction=roughness[dominant]/max(sum(roughness),1e-15))
def stats(values):
    x=sorted(v for v in values if v is not None and math.isfinite(v))
    if not x:return dict(n=0,median=None,q25=None,q75=None,min=None,max=None)
    def q(p):
        u=(len(x)-1)*p;i=int(u);return x[i]+(u-i)*(x[min(i+1,len(x)-1)]-x[i])
    return dict(n=len(x),median=median(x),q25=q(.25),q75=q(.75),min=x[0],max=x[-1])
def fmt(x):return '-' if x is None else f'{x:.2f}'

def main():
    audit=read(RELEASE/'formal_audit.json');assert audit['passed'] and audit['runs']==75
    frozen=read(RELEASE/'frozen_config.json');assert audit['sourceFingerprint']==frozen['metadata']['sourceFingerprint']
    assert all(r['summaryAndTrajectoryMatched'] for r in audit['fineDetails'])
    fine={(r['scenario'],r['variant'],r['seed']):r for r in audit['fineDetails']}
    rows=[];shapes=[]
    for p in sorted((RELEASE/'formal').glob('**/summary.json')):
        r=read(p);v=fine[r['scenario'],r['variant'],r['seed']]
        assert r['sourceFingerprint']==audit['sourceFingerprint']
        r['nominalSuccess']=r['success'];r['success']=v['studySuccess'];r['fineFailures']=v['failures']
        if r['nominalSuccess'] and not r['success']:r['failures']+=['fine_'+s for s in v['failures']]
        r['fineMinGap']=v['minGap'];r['fineMaxTilt']=v['maxTilt'];r['fineMinToolHeight']=v['minHeight']
        r['meanTangentOrScaledFraction']=v['searchSampling']['meanFraction']
        r['controllerChanges']=v['searchSampling']['controllerChanges']
        shape=joint_shape(p.parent,r);shapes.append(shape)
        for name in ['maxAdjacentChangeRad','dominantSmoothnessJoint','dominantSmoothnessFraction']:r[name]=shape[name]
        rows.append(r)
    index={(r['scenario'],r['variant'],r['seed']):r for r in rows}
    assert set(index)=={(c,a,s) for c in CASES for a in ARMS for s in range(5800,5805)} and len(rows)==75
    groups=[]
    for case in CASES+['all_cases']:
        for arm in ARMS:
            selected=[r for r in rows if r['variant']==arm and (case=='all_cases' or r['scenario']==case)]
            ok=[r for r in selected if r['success']];failures={}
            for r in selected:
                for reason in r['failures']:failures[reason]=failures.get(reason,0)+1
            g=dict(scenario=case,variant=arm,runs=len(selected),successes=len(ok),failures=failures)
            for key in ['plannerSeconds','totalSeconds','searchIterations','iterations','controllerChanges','meanTangentOrScaledFraction']:
                g[key+'All']=stats([r[key] for r in selected])
            for key in ['firstFeasibleSeconds','firstFeasibleQuality','finalQuality','jointPathLength','smoothness','toolPathLength','fineMinGap','fineMaxTilt','fineMinToolHeight','refineSeconds']:
                g[key+'Successful']=stats([r[key] for r in ok])
            g['withinRunQualityReductionPercent']=stats([100*(r['firstFeasibleQuality']-r['finalQuality'])/r['firstFeasibleQuality'] for r in ok])
            g['withinRunJointLengthReductionPercent']=stats([100*(fine[r['scenario'],arm,r['seed']]['firstJointLength']-r['jointPathLength'])/fine[r['scenario'],arm,r['seed']]['firstJointLength'] for r in ok])
            g['withinRunSmoothnessReductionPercent']=stats([100*(fine[r['scenario'],arm,r['seed']]['firstSmoothness']-r['smoothness'])/fine[r['scenario'],arm,r['seed']]['firstSmoothness'] for r in ok if fine[r['scenario'],arm,r['seed']]['firstSmoothness']>1e-12])
            for key in ['meanProjectionCorrectionsPerWaypoint','preProjectionRms','postProjectionRms','meanFraction','maxEnergyMatchError']:
                g[key+'All']=stats([fine[r['scenario'],arm,r['seed']]['searchSampling'][key] for r in selected])
            groups.append(g)
    pairs=[]
    for case in CASES+['all_cases']:
        for a,b in [('ambient','fixed75'),('energy_control','fixed75'),('fixed50','adaptive'),('fixed75','adaptive')]:
            keys=[(c,s) for c in CASES if case=='all_cases' or c==case for s in range(5800,5805)
                  if index[c,a,s]['success'] and index[c,b,s]['success']]
            p=dict(scenario=case,a=a,b=b,n=len(keys),commonSuccessfulPairs=[dict(scenario=c,seed=s) for c,s in keys])
            for key in ['firstFeasibleQuality','finalQuality']:
                delta=[100*(index[c,a,s][key]-index[c,b,s][key])/index[c,a,s][key] for c,s in keys]
                p[key+'ReductionPercent']=stats(delta)
                p[key+'WinsTiesLossesB']=dict(wins=sum(d>1e-9 for d in delta),ties=sum(abs(d)<=1e-9 for d in delta),losses=sum(d< -1e-9 for d in delta))
            for key in ['firstFeasibleSeconds','plannerSeconds']:
                p[key+'DifferenceBminusA']=stats([index[c,b,s][key]-index[c,a,s][key] for c,s in keys])
            pairs.append(p)
    probe=read(RELEASE/'sampling_ablation.json');assert probe['passed']
    probes={(r['scenario'],r['path'],r['seed'],r['variant']):r for r in probe['details']}
    probe_summary=[]
    for arm in ['ambient','energy_control','fixed75']:
        selected=[r for r in probe['details'] if r['variant']==arm]
        probe_summary.append(dict(variant=arm,**{k:stats([r[k] for r in selected]) for k in ['projectionCorrectionsPerWaypoint','preProjectionRms','postProjectionRms','validSamples']}))
    reduction=[]
    for c in CASES:
        for path in ['linear','witness']:
            for seed in range(5760,5765):
                a=probes[c,path,seed,'energy_control']['projectionCorrectionsPerWaypoint'];b=probes[c,path,seed,'fixed75']['projectionCorrectionsPerWaypoint']
                if a>0:reduction.append(100*(a-b)/a)
    development=read(RELEASE/'development_audit.json');assert development['passed'] and development['runs']==30
    dev_failures=[dict(scenario=r['scenario'],variant=r['variant'],seed=r['seed'],failures=r['failures']) for r in development['fineDetails'] if not r['studySuccess']]
    outliers=[{k:r[k] for k in ['scenario','variant','seed','firstFeasibleQuality','finalQuality','jointPathLength','smoothness','plannerSeconds',
                             'maxAdjacentChangeRad','dominantSmoothnessJoint','dominantSmoothnessFraction']}
              for r in sorted([r for r in rows if r['success']],key=lambda r:r['finalQuality'],reverse=True)[:5]]
    failed=[{k:r[k] for k in ['scenario','variant','seed','failures','plannerSeconds','fineMinGap','fineMaxTilt','meanTangentOrScaledFraction','controllerChanges']} for r in rows if not r['success']]
    summary=dict(formalRuns=75,successes=sum(r['success'] for r in rows),groups=groups,paired=pairs,
                 sourceFingerprint=audit['sourceFingerprint'],formalFailures=failed,highestScoreSuccessfulPaths=outliers,
                 developmentRuns=30,developmentSuccesses=development['fineSuccessfulRuns'],developmentFailures=dev_failures,
                 fixedStateGroups=probe_summary,fixedStateCorrectionReductionVsEnergyControlPercent=stats(reduction),
                 replayedCheckpoints=audit['replayedCheckpoints'],scope='Three fixed cases; five reserved seeds/case. Pooled numbers are descriptive, not universal reliability.')
    (RELEASE/'study_summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
    (RELEASE/'joint_path_diagnostics.json').write_text(json.dumps(dict(passed=True,paths=75,sourceFingerprint=audit['sourceFingerprint'],
        scope='Independent joint length and second-difference recomputation from trajectory CSV. Adjacent waypoint changes are geometric quantities, not speeds.',records=shapes),indent=2)+'\n',encoding='utf-8')
    with (RELEASE/'all_runs.csv').open('w',encoding='utf-8',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=list(rows[0]));writer.writeheader()
        for r in rows:writer.writerow({k:json.dumps(v) if isinstance(v,list) else v for k,v in r.items()})
    lines=['# V5 adaptive sampling and energy-control results','',
           'All 75 reserved-seed cases are retained. Study success requires nominal success and the independent 0.00625 rad final check.',
           '', 'Q = joint path length + 5*smoothness + the fixed soft 45 mm clearance preference. Lower Q is better under this definition; individual components can trade off. First Q measures the primary-search output before refinement.',
           '', '| Scenario | Arm | Success | Median total planner time (s), all runs | Median first quality, successes | Median final quality, successes |',
           '| --- | --- | ---: | ---: | ---: | ---: |']
    for g in groups:
        if g['scenario']=='all_cases':continue
        lines.append(f"| {g['scenario']} | {g['variant']} | {g['successes']}/{g['runs']} | {fmt(g['plannerSecondsAll']['median'])} | {fmt(g['firstFeasibleQualitySuccessful']['median'])} | {fmt(g['finalQualitySuccessful']['median'])} |")
    lines+=['','## Overall trade-off','', 'These are descriptive counts over three cases with five seeds each. Quality is conditional on success.', '',
            '| Arm | Fine success | Median total time (s), all cases | Median final Q, successes |',
            '| --- | ---: | ---: | ---: |']
    for g in groups:
        if g['scenario']=='all_cases':
            lines.append(f"| {g['variant']} | {g['successes']}/{g['runs']} | {fmt(g['plannerSecondsAll']['median'])} | {fmt(g['finalQualitySuccessful']['median'])} |")
    aggregate={g['variant']:g for g in groups if g['scenario']=='all_cases'}
    lines+=['','## Finer acceptance of successful paths','',
            '| Arm | Lowest conservative gap (mm) | Largest tilt (deg) | Lowest tool height (mm) |',
            '| --- | ---: | ---: | ---: |']
    for arm in ARMS:
        g=aggregate[arm]
        lines.append(f"| {arm} | {1000*g['fineMinGapSuccessful']['min']:.2f} | {g['fineMaxTiltSuccessful']['max']:.3f} | {1000*g['fineMinToolHeightSuccessful']['min']:.2f} |")
    lines+=['','All 71 successful final paths pass the actual world/self-collision checks at 0.00625 rad joint increments. These remain discrete checks, not a continuous or physical execution guarantee.']
    if aggregate['adaptive']['successes']<aggregate['fixed75']['successes']:
        lines+=['', 'The adaptive strategy is not promoted as the default: it has fewer fine successes than fixed75 in this study. '
                'Conditional quality gains cannot compensate for missing paths without an explicit application trade-off. '
                'Keep fixed75 as the established comparison baseline and retain adaptive as an experimental option. '
                'This small study does not prove a universal reliability ranking.']
    else:
        lines+=['','No universal strategy winner follows from this small fixed-case study. Success, time and conditional quality must be considered together.']
    lines+=['','## Retained formal failures','']
    for r in failed:
        lines.append(f"- {r['scenario']} / {r['variant']} / seed {r['seed']}: {', '.join(r['failures'])}; planner time {r['plannerSeconds']:.2f} s; fine gap {1000*r['fineMinGap']:.2f} mm; tilt {r['fineMaxTilt']:.3f} deg.")
        if r['variant']=='adaptive':
            lines.append(f"  Applied mean tangent fraction {r['meanTangentOrScaledFraction']:.3f}, with {r['controllerChanges']} changes between consecutive iterations within restarts.")
    lines+=['', 'The feedback controller ranks rollout objective values, not final dense feasibility. '
            'A lower soft objective does not ensure crossing the hard 35 mm threshold. '
            'This is a mechanism-level limitation and a possible explanation for the adaptive failures, not a demonstrated causal attribution from this study.']
    lines+=['','## Highest-score successful paths','',
            'The five largest final Q values among successful paths are retained below, including long or rough feasible paths.', '',
            '| Scenario / arm / seed | First Q | Final Q | Joint length (rad) | Smoothness |',
            '| --- | ---: | ---: | ---: | ---: |']
    for r in outliers:
        lines.append(f"| {r['scenario']} / {r['variant']} / {r['seed']} | {r['firstFeasibleQuality']:.2f} | {r['finalQuality']:.2f} | {r['jointPathLength']:.2f} | {r['smoothness']:.2f} |")
    if outliers:
        r=outliers[0]
        lines+=['',f"The largest-score successful path has a maximum adjacent waypoint change of {r['maxAdjacentChangeRad']:.3f} rad. "
                f"Joint {r['dominantSmoothnessJoint']} contributes {100*r['dominantSmoothnessFraction']:.1f}% of its second-difference smoothness term. "
                'This motivates local path repair or additional search as future work. It is not a measured speed or acceleration, since no execution timing is modeled.']
    lines+=['',f"Separate development study: {development['fineSuccessfulRuns']}/30 fine successes. Retained development failures:",'']
    for r in dev_failures:lines.append(f"- {r['scenario']} / {r['variant']} / seed {r['seed']}: {', '.join(r['failures'])}.")
    lines+=['','## Paired contrasts','', 'Positive percentages mean the second arm has a lower fixed secondary score. Only common successful case/seed pairs enter quality comparisons.', '',
            '| Scenario | Contrast | n | Median first-score reduction (%) | Median final-score reduction (%) | Final wins/ties/losses |',
            '| --- | --- | ---: | ---: | ---: | --- |']
    for p in pairs:
        w=p['finalQualityWinsTiesLossesB']
        lines.append(f"| {p['scenario']} | {p['a']} to {p['b']} | {p['n']} | {fmt(p['firstFeasibleQualityReductionPercent']['median'])} | {fmt(p['finalQualityReductionPercent']['median'])} | {w['wins']}/{w['ties']}/{w['losses']} |")
    lines+=['','## Matched-input-energy diagnostic','',
            f"Thirty fixed-state paired batches / 90 sampler calls. Maximum absolute pre-projection energy mismatch: {probe['maxPreProjectionEnergyAbsoluteDifference']:.3g} rad^2.",
            '', '| Sampler | Median pre-projection RMS (rad) | Median post-projection RMS (rad) | Median corrections / sampled waypoint |',
            '| --- | ---: | ---: | ---: |']
    for g in probe_summary:lines.append(f"| {g['variant']} | {g['preProjectionRms']['median']:.4f} | {g['postProjectionRms']['median']:.4f} | {g['projectionCorrectionsPerWaypoint']['median']:.4f} |")
    lines+=['',f"Fixed75 vs energy control: median paired projection-correction reduction {fmt(stats(reduction)['median'])}% (n={len(reduction)}).",
            '', 'The same five Gaussian innovation streams are reused across six central paths. The 30 paired batches are not 30 independent seeds, and overlapping plotted values are expected. These upright central paths share similar direction-constraint structure, limiting generalization to arbitrary central orientations.',
            '', 'This control matches scalar squared norm after limits and before nonlinear projection. It does not match covariance or post-projection variance. The probes use linear and geometric-witness central paths solely for sampling diagnostics. Neither witness nor probe output initializes the planner.',
            '', '## Controller and interpretation','']
    for g in groups:
        if g['scenario']!='all_cases' and g['variant']=='adaptive':
            lines.append(f"- {g['scenario']}: median mean search fraction {fmt(g['meanFractionAll']['median'])}; median fraction changes {fmt(g['controllerChangesAll']['median'])}.")
    lines+=['', 'Adaptive vs fixed50 isolates primary-search feedback; both refine at fixed50. Fixed75 vs energy control contrasts directions at matched input energy. All arms use the same primary objective, safety gates and refinement score.',
            '', 'Refinement is guaranteed to improve its own feasible incumbent, not another sampler\'s first path. Both first and final scores are reported. Runtime includes writes and is descriptive for shared two-worker execution; the energy control includes counterfactual-projector work.',
            '', 'No V4 formal seeds were reused for tuning. Five seeds per case are a small sample. No cross-version causal speed/quality claim or continuous collision guarantee is made.',
            '', f"Independent formal audit: {audit['runs']} paths, {audit['replayedCheckpoints']} sampling/update checkpoints, final step 0.00625 rad.",
            '', '[Protocol](TASK45_V5_PROTOCOL.md). All prior releases remain preserved.', '']
    (ROOT/'docs/TASK45_V5_RESULTS.md').write_text('\n'.join(lines),encoding='utf-8')
    index_lines=['# V5: adaptive STOMP sampling and input-energy ablation','',
                 'Experimental comparison of five sampling strategies on three mounted-workcell cases. V1-V4 remain frozen.',
                 '', '[Results](docs/TASK45_V5_RESULTS.md) | [Protocol](docs/TASK45_V5_PROTOCOL.md) | [Chinese method explanation](docs/TASK45_V5_METHODS_ZH.md)',
                 '', 'All five benchmark arms are Task 5 strategies with the upright constraint enabled. '
                 'The course Task 4-versus-Task 5 unconstrained/constrained demonstration remains in '
                 '[V3](README_TASK45_V3.md); use `show_project_demo(\'all\',\'v3\')` from scripts.',
                 '', 'From the repository root:', '', '```matlab', "addpath('scripts')", "show_task45_v5('benchmark')", "show_task45_v5('energy')", "show_task45_v5('demo')", '```',
                 '', 'Fresh planning in a fresh MATLAB R2023b session:', '', '```matlab', "addpath('scripts')", "newRunRoot = fullfile(pwd,'artifacts','local_runs','my_v5_run');", "r = run_task45_v5('task5','endpoints','adaptive',5700,newRunRoot);", 'audit = verify_task45_v5(newRunRoot);', '```',
                 '', 'Shipped development demonstrations contain complete replay inputs. Formal raw input/iteration/refinement archives remain local; formal trajectories, dense profiles, frozen settings and audit receipts are in Git.',
                 '', 'Full saved sampling/update replay of the two shipped demonstrations:', '', '```matlab',
                 "audit = verify_task45_v5(fullfile(pwd,'artifacts','runs','task45_v5','demos'));", '```',
                 '', 'Fresh final-path validation of the compact Git formal results, without raw rollout files:', '',
                 '```matlab', "addpath('scripts')", "audit = verify_task45_v5_paths(fullfile(pwd,'artifacts','runs','task45_v5','formal'));", '```',
                 '', 'This reconstructs geometry and checks nominal/finer path acceptance. Full random-sample/update replay is separate and uses the shipped demonstrations or the complete local raw archive.',
                 '', '`py -3.12 scripts/verify_task45_v5_manifest.py` verifies the Git inventory. Add `--full` only with the complete local raw archive.',
                 '', 'Wall-clock stopping can change fresh iteration counts across machines. Replay checks saved RNG and actual projected perturbations. Energy matching is before nonlinear projection, not post-projection variance matching.', '']
    index_lines[4:4]=['',f"Formal fine successes: adaptive {aggregate['adaptive']['successes']}/15; fixed75 {aggregate['fixed75']['successes']}/15; energy control {aggregate['energy_control']['successes']}/15. "
                     'Read per-case outcomes and conditional paired comparisons before choosing a strategy. '
                     'V5 is an experimental study, not an automatic replacement for the established course demonstration.', '']
    (ROOT/'README_TASK45_V5.md').write_text('\n'.join(index_lines),encoding='utf-8')
    print(json.dumps(dict(runs=75,successes=summary['successes'],perArm=[(g['variant'],g['successes']) for g in groups if g['scenario']=='all_cases']),indent=2))
if __name__=='__main__':main()
