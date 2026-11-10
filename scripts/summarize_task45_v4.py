"""Summarize all four held-out arms, including failures and paired sample sizes."""
from pathlib import Path
import csv
import json
from statistics import median

ROOT=Path(__file__).resolve().parents[1]
RELEASE=ROOT/'artifacts/runs/task45_v4'
VARIANTS=['baseline','anytime','tangent','combined']

def stats(values):
    x=sorted(v for v in values if v is not None)
    if not x:return {'n':0,'median':None,'q25':None,'q75':None,'min':None,'max':None}
    def quantile(p):
        u=(len(x)-1)*p;i=int(u);j=min(i+1,len(x)-1)
        return x[i]+(u-i)*(x[j]-x[i])
    return {'n':len(x),'median':median(x),'q25':quantile(.25),'q75':quantile(.75),'min':x[0],'max':x[-1]}

def main():
    audit=json.loads((RELEASE/'formal_audit.json').read_text())
    assert audit['passed'] and audit['runs']==40
    rows=[json.loads(p.read_text()) for p in sorted((RELEASE/'formal').glob('**/summary.json'))]
    assert len(rows)==40
    indexed={(r['variant'],r['seed']):r for r in rows}
    fine={(r['variant'],r['seed']):r for r in audit['fineDetails']}
    groups=[]
    for variant in VARIANTS:
        selected=[r for r in rows if r['variant']==variant]
        assert sorted(r['seed'] for r in selected)==list(range(5600,5610))
        ok=[r for r in selected if r['success']]
        failures={}
        for row in selected:
            for reason in row['failures']:failures[reason]=failures.get(reason,0)+1
        g={'variant':variant,'runs':len(selected),'successes':len(ok),'failures':failures}
        for key in ['plannerSeconds','iterations']:
            g[key+'All']=stats([r[key] for r in selected])
        for key in ['firstFeasibleSeconds','firstFeasibleQuality','finalQuality','jointPathLength',
                    'toolPathLength','smoothness','minVoxelClearance','maxOrientationDeg',
                    'refineAccepted','refineSeconds']:
            g[key+'Successful']=stats([r[key] for r in ok])
        g['withinRunQualityImprovementPercent']=stats([100*(r['firstFeasibleQuality']-r['finalQuality'])/r['firstFeasibleQuality'] for r in ok])
        g['withinRunJointLengthReductionPercent']=stats([100*(fine[variant,r['seed']]['firstJointLength']-fine[variant,r['seed']]['finalJointLength'])/fine[variant,r['seed']]['firstJointLength'] for r in ok])
        g['withinRunSmoothnessReductionPercent']=stats([100*(fine[variant,r['seed']]['firstSmoothness']-fine[variant,r['seed']]['finalSmoothness'])/fine[variant,r['seed']]['firstSmoothness'] for r in ok if fine[variant,r['seed']]['firstSmoothness']>1e-12])
        g['fineMaxTiltSuccessful']=stats([fine[variant,r['seed']]['maxTilt'] for r in ok])
        g['fineMinGapSuccessful']=stats([fine[variant,r['seed']]['minGap'] for r in ok])
        g['fineMinToolHeightSuccessful']=stats([fine[variant,r['seed']]['minHeight'] for r in ok])
        for key in ['meanProjectionCorrectionsPerWaypoint','actualNoiseRms','projectionSeconds','tangentSeconds']:
            g[key+'All']=stats([fine[variant,r['seed']]['searchSampling'][key] for r in selected])
        groups.append(g)
    pairs=[]
    for a,b in [('baseline','anytime'),('baseline','tangent'),('tangent','combined'),('anytime','combined'),('baseline','combined')]:
        seeds=[s for s in range(5600,5610) if indexed[a,s]['success'] and indexed[b,s]['success']]
        item={'a':a,'b':b,'commonSuccessfulSeeds':seeds,'n':len(seeds),'differenceBminusA':{}}
        for key in ['firstFeasibleSeconds','plannerSeconds','finalQuality','jointPathLength','toolPathLength','smoothness','minVoxelClearance','maxOrientationDeg']:
            item['differenceBminusA'][key]=stats([indexed[b,s][key]-indexed[a,s][key] for s in seeds])
        item['pairedQualityImprovementPercent']=stats([100*(indexed[a,s]['finalQuality']-indexed[b,s]['finalQuality'])/indexed[a,s]['finalQuality'] for s in seeds])
        item['qualityWinsTiesLossesB']={
            'wins':sum(indexed[b,s]['finalQuality']<indexed[a,s]['finalQuality']-1e-9 for s in seeds),
            'ties':sum(abs(indexed[b,s]['finalQuality']-indexed[a,s]['finalQuality'])<=1e-9 for s in seeds),
            'losses':sum(indexed[b,s]['finalQuality']>indexed[a,s]['finalQuality']+1e-9 for s in seeds)}
        if (a,b) in [('baseline','anytime'),('tangent','combined')]:
            item['sameFirstSolutionQuality']=all(abs(indexed[a,s]['firstFeasibleQuality']-indexed[b,s]['firstFeasibleQuality'])<1e-9 for s in seeds)
        item['projectionCorrectionReductionPercent']=stats([
            100*(fine[a,s]['searchSampling']['meanProjectionCorrectionsPerWaypoint']-fine[b,s]['searchSampling']['meanProjectionCorrectionsPerWaypoint'])/fine[a,s]['searchSampling']['meanProjectionCorrectionsPerWaypoint']
            for s in seeds if fine[a,s]['searchSampling']['meanProjectionCorrectionsPerWaypoint']>1e-12])
        pairs.append(item)
    worse=[]
    for seed in range(5600,5610):
        a,b=indexed['baseline',seed],indexed['combined',seed]
        if not(a['success'] and b['success']) or b['finalQuality']<=a['finalQuality']+1e-9:continue
        length=b['jointPathLength']-a['jointPathLength'];smooth=5*(b['smoothness']-a['smoothness'])
        delta=b['finalQuality']-a['finalQuality']
        worse.append({'seed':seed,'qualityIncreasePercent':100*delta/a['finalQuality'],
                      'jointLengthContribution':length,'smoothnessContribution':smooth,
                      'clearanceContribution':delta-length-smooth})
    summary={'formalRuns':40,'groups':groups,'paired':pairs,'combinedWorseThanBaseline':worse,'auditCheckpoints':audit['replayedCheckpoints'],
             'scope':'One fixed mounted workcell; shared two-worker execution; descriptive paired comparisons; all failures retained.'}
    (RELEASE/'study_summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
    columns=list(rows[0])
    with (RELEASE/'all_runs.csv').open('w',encoding='utf-8',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=columns);writer.writeheader()
        for row in rows:writer.writerow({k:json.dumps(v) if isinstance(v,list) else v for k,v in row.items()})
    lines=['# V4 algorithm results','','All 40 reserved-seed runs and all failures are included.',
           '', '| Arm | Success | Median total planner time (s) | Median first feasible time, successes (s) | Median final quality, successes | Median within-run quality reduction (%) |',
           '| --- | ---: | ---: | ---: | ---: | ---: |']
    def fmt(x):return '-' if x is None else f'{x:.2f}'
    for g in groups:
        lines.append(f"| {g['variant']} | {g['successes']}/10 | {fmt(g['plannerSecondsAll']['median'])} | {fmt(g['firstFeasibleSecondsSuccessful']['median'])} | {fmt(g['finalQualitySuccessful']['median'])} | {fmt(g['withinRunQualityImprovementPercent']['median'])} |")
    development=json.loads((RELEASE/'development_audit.json').read_text())
    assert development['passed'] and development['runs']==12
    failed=[r for r in development['details'] if not r['planningSuccess']]
    lines+=['',f"Separate development audit: {development['successfulRuns']}/12 runs succeeded. Development failures were retained:",'']
    for r in failed:
        parts=r['folder'].replace('\\','/').split('/')
        lines.append(f"- {parts[-4]}, {parts[-1]}: {', '.join(r['failures'])}.")
    lines+=['','## Finer acceptance check','',
            '| Arm | Lowest conservative clearance (mm) | Largest tilt (deg) | Lowest tool height (mm) |',
            '| --- | ---: | ---: | ---: |']
    for g in groups:
        gap=g['fineMinGapSuccessful']['min'];height=g['fineMinToolHeightSuccessful']['min']
        lines.append(f"| {g['variant']} | {fmt(None if gap is None else 1000*gap)} | {fmt(g['fineMaxTiltSuccessful']['max'])} | {fmt(None if height is None else 1000*height)} |")
    lines+=['','Secondary score = joint length + 5*smoothness + soft 45 mm clearance preference. '
            'Lower score is better only under this shared definition. It is distinct from the primary search objective.',
            '', 'Quality summaries use successful runs and comparisons below use common successful seeds only.', '']
    for p in pairs:
        w=p['qualityWinsTiesLossesB']
        lines.append(f"- {p['a']} -> {p['b']}: n={p['n']}; median paired quality reduction {fmt(p['pairedQualityImprovementPercent']['median'])}% (B wins/ties/losses {w['wins']}/{w['ties']}/{w['losses']}); median paired total-time difference {fmt(p['differenceBminusA']['plannerSeconds']['median'])} s.")
    lines+=['','## Refinement components','']
    for g in groups:
        if g['variant'] in ['anytime','combined']:
            lines.append(f"- {g['variant']}: within-run median joint-length reduction {fmt(g['withinRunJointLengthReductionPercent']['median'])}%; smoothness reduction {fmt(g['withinRunSmoothnessReductionPercent']['median'])}%. Negative means an increase; components can trade off under the fixed score.")
    lines+=['','## Tangent sampling diagnostics','',
            '| Arm | Median correction steps / sampled waypoint | Median actual disturbance RMS (rad) |',
            '| --- | ---: | ---: |']
    for g in groups:
        lines.append(f"| {g['variant']} | {fmt(g['meanProjectionCorrectionsPerWaypointAll']['median'])} | {fmt(g['actualNoiseRmsAll']['median'])} |")
    for p in pairs:
        if (p['a'],p['b']) in [('baseline','tangent'),('anytime','combined')]:
            lines.append(f"\n{p['a']} -> {p['b']}: n={p['n']}; median paired reduction in correction steps per sampled waypoint {fmt(p['projectionCorrectionReductionPercent']['median'])}%.")
    lines+=['','## Cases where combined has a higher score than baseline','',
            '| Seed | Score increase (%) | Joint-length contribution | 5*smoothness contribution | Clearance contribution |',
            '| --- | ---: | ---: | ---: | ---: |']
    for r in worse:
        lines.append(f"| {r['seed']} | {fmt(r['qualityIncreasePercent'])} | {r['jointLengthContribution']:.4f} | {r['smoothnessContribution']:.4f} | {r['clearanceContribution']:.4f} |")
    lines+=['','Tangent sampling can find a different first feasible path. Refinement guarantees improvement '
            'relative to its own incumbent; it does not guarantee beating the ambient-search baseline. '
            'The component differences above explain the score increase without discarding these seeds.']
    lines+=['','The four arms isolate refinement and tangent sampling. Refinement is additional computation within the '
            'same 300 s target, with a 45 s refinement target and at most 20 iterations. '
            'Budgets are checked between iterations, so a final iteration can overrun the time target. '
            'The 0.10 rad update cap applies before nonlinear orientation correction. '
            'Compare first-feasible time separately from total time. '
            'Every accepted refinement improves its own incumbent score and passes unchanged dense validation. '
            'No universal speed, optimality or reliability claim is made.',
            '', 'Tangent mapping changes effective disturbance magnitude as well as direction. '
            'Actual disturbances are retained and summarized; this four-arm study has no additional variance-matched ambient ablation.',
            '', f"Independent audit: {audit['runs']} paths, {audit['replayedCheckpoints']} search/refinement checkpoints; finer final validation at 0.00625 rad.",
            '', 'Independent NumPy checks additionally reproduce tool tilt, tool-path length and minimum height '
            'at every saved nominal dense state. They do not independently check mesh collision.',
            '', '[Protocol](TASK45_V4_PROTOCOL.md). V1/V2/V3 source and evidence remain preserved.', '']
    (ROOT/'docs/TASK45_V4_RESULTS.md').write_text('\n'.join(lines),encoding='utf-8')
    index=['# Task 4-5 V4: anytime refinement and tangent-aware sampling','',
           'V4 implements both algorithm changes in an isolated source tree. V1/V2/V3 remain preserved.',
           '', '| Variant | Refinement | Tangent mixture | Formal Task 5 success |',
           '| --- | --- | --- | ---: |']
    for g in groups:
        index.append(f"| {g['variant']} | {'yes' if g['variant'] in ['anytime','combined'] else 'no'} | {'75%' if g['variant'] in ['tangent','combined'] else 'no'} | {g['successes']}/10 |")
    index+=['', 'Formal seeds are 5600-5609 on the fixed mounted workcell, separate from development 5500-5502. '
            'Refinement reduces a fixed secondary score while preserving all feasibility gates. '
            'It uses additional computation within the same total target; successful implementation alone does not establish a universal speed or quality improvement.',
            '', '```matlab', "addpath('scripts')", "show_task45_v4('combined')", "show_task45_v4('anytime')", "show_task45_v4('benchmark')", '```',
            '', 'Read-only replay of the four shipped demonstrations (fresh MATLAB session):', '',
            '```matlab', "addpath('scripts')", "audit = verify_task45_v4(fullfile(pwd,'artifacts','runs','task45_v4','demos'));", '```',
            '', 'Fresh planning and complete replay, in a fresh MATLAB R2023b session:', '',
            '```matlab', "addpath('scripts')", "newRunRoot = fullfile(pwd,'artifacts','local_runs','my_task45_v4_run');", "r = run_task45_v4('task5','combined',5500,newRunRoot);", 'audit = verify_task45_v4(newRunRoot);', '```',
            '', '[Full results](docs/TASK45_V4_RESULTS.md) | [Protocol](docs/TASK45_V4_PROTOCOL.md) | [Source](upgrades/task45_v4/README.md)',
            '', 'Git handoff verification: `py -3.12 scripts/verify_task45_v4_manifest.py`. '
            'Add `--full` only with the complete local raw archive. Formal raw iteration/refinement checkpoints '
            'and inputs remain local; the four copied development demonstrations include replay inputs.',
            '', 'The ordinary console RESULT iteration count refers to the primary search. '
            'Saved summaries additionally report refinement and total iteration counts. '
            'Primary-search objective and secondary quality score are different quantities.',
            '', 'Wall-clock stopping means fresh planning can finish after a different number of iterations '
            'on another machine. Archived RNG/checkpoints support replay of the saved run.', '']
    (ROOT/'README_TASK45_V4.md').write_text('\n'.join(index),encoding='utf-8')
    print(json.dumps({'runs':40,'groups':[(g['variant'],g['successes']) for g in groups]},indent=2))

if __name__=='__main__':main()
