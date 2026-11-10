"""Build the report and four editable slides from frozen experiment evidence.

PowerPoint COM is the user-approved fallback for the unavailable artifact-tool
runtime. No planning or metric calculation is performed here.
"""
from __future__ import annotations
import csv
import json
import sys
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[1]
FINAL = ROOT / 'artifacts/runs/task45_final'


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def fmt(value, places=2):
    return '-' if value is None else f'{value:.{places}f}'


def main():
    frozen = read(FINAL / 'frozen_config.json')
    study = read(FINAL / 'formal/study_summary.json')
    audit = read(FINAL / 'independent_audit.json')
    assert audit['passed'] and study['totalRuns'] in (40, 50)
    groups = {g['name']: g for g in study['groups']}
    mode = frozen['parameters']['constraintMode']
    demos = [read(p) for p in sorted((FINAL / 'demos').glob('**/summary.json'))]
    formal=[read(p) for p in (FINAL/'formal').glob('**/summary.json')]
    constrained=[r for r in formal if r['mode']==mode]
    diagnostics={'n':len(constrained),'upright':sum(r['maxOrientationDeg']<=5+1e-8 for r in constrained),
                 'selfFailures':sum('self_collision' in r['failures'] for r in constrained),
                 'successes':sum(r['success'] for r in constrained)}
    interruptions=[read(p) for p in (FINAL/'technical_interruptions').glob('**/interruption_receipt.json')]
    diagnostics.update(technicalInterruptions=len(interruptions),observedAttempts=study['totalRuns']+len(interruptions),
                       completedCases=study['totalRuns'],completedSuccesses=study['successfulRuns'])
    accounting={'completedNominalCases':study['totalRuns'],'completedSuccesses':study['successfulRuns'],
                'technicalInterruptions':len(interruptions),'observedAttempts':diagnostics['observedAttempts'],
                'interruptedCaseIds':[{'scenario':r['scenario'],'mode':r['mode'],'seed':r['seed'],
                                      'checkpoints':r['checkpointCount'],'archivePath':r['archivePath']} for r in interruptions],
                'interpretation':'Interrupted attempts had no final output. They are retained and counted separately; complete-case and all-attempt fractions are both reported.'}
    (FINAL/'attempt_accounting.json').write_text(json.dumps(accounting,indent=2)+'\n',encoding='utf-8')
    out = FINAL / 'delivery'
    out.mkdir(exist_ok=True)
    content = report_text(frozen, study, audit, demos, groups, mode,diagnostics)
    (ROOT / 'docs/TASK45_RESULTS.md').write_text(content, encoding='utf-8')
    report_pdf(out / 'task45_report.pdf', frozen, study, demos, groups, mode,diagnostics)
    build_slides(out, frozen, study, demos, groups, mode,diagnostics)
    print(f'Delivery created: {out}')


def report_text(frozen, study, audit, demos, groups, mode,diag):
    p = frozen['parameters']
    lines = ['# Task 4-5 results', '',
             f"Frozen mode: **{mode}**, lambda {p['orientationWeight']}, noise {p['noiseStd']} rad; "
             f"{p['nWaypoints']} waypoints, {p['nRollouts']} rollouts, "
             f"{p['maxIterations']} iterations per restart, {p['maxRestarts']} restarts, "
             f"{p['maxWallSeconds']} s planner budget.", '',
             f"Fixed stagnation restart: {p['maxStallIterations']} consecutive rounds with improvement below "
             "1e-7, following at least ten iterations. Diagnostic pilot runs preceding this implementation fix "
             "are preserved separately and excluded from formal inference.", '',
             f"Formal study: {study['totalRuns']} completed nominal cases, seeds 5120-5129. "
             'All completed planning failures are included in denominators. Runtime summaries include completed failures; '
             'quality summaries include successful runs only.', '',
             '| Scene / mode | Success | Planner median (s) | Successful max-tilt median (deg) | Successful min-clearance median (mm) |',
             '| --- | ---: | ---: | ---: | ---: |']
    for g in study['groups']:
        lines.append(f"| {g['name']} | {g['successes']}/{g['n']} | {fmt(g['plannerSecondsAll']['median'])} | "
                     f"{fmt(g['maxTiltSuccessful']['median'])} | {fmt(1000*g['minVoxelSuccessful']['median']) if g['minVoxelSuccessful']['median'] is not None else '-'} |")
    if diag['technicalInterruptions']:
        lines += ['', '### Technical interruption accounting', '',
                  f"The table covers {diag['completedCases']} completed nominal cases, including all completed planning failures. "
                  f"An additional {diag['technicalInterruptions']} interrupted technical attempt is archived, giving {diag['observedAttempts']} observed attempts. "
                  f"Complete-case full success is {diag['completedSuccesses']}/{diag['completedCases']}; observed full-output success across all attempts is "
                  f"{diag['completedSuccesses']}/{diag['observedAttempts']}. The interrupted attempt had no final output and is not classified as a proven optimizer failure.", '',
                  'The interruption occurred during main-scene penalty ablation, seed 5122. Its 288 checkpoint files were preserved with hashes. '
                  'The same nominal seed was repeated from the original colliding initialization with unchanged frozen parameters. '
                  'That condition therefore has ten completed cases plus one interrupted attempt; both complete-case and all-attempt denominators are explicit. '
                  'Runtime statistics use completed cases with measured times; the partial attempt has only a censored lower bound. '
                  'See `attempt_accounting.json`, `recovery_audit.json`, and `technical_interruptions/`.', '']
    state=read(FINAL/'development_evidence/development_state.json')
    base={}
    for path in (FINAL/f'development_evidence/profile_{state["selectedProfile"]}').glob('**/summary.json'):
        row=read(path); base[(row['scenario'],row['seed'])]=row['success']
    with (FINAL/'development_evidence/development_results.csv').open(encoding='utf-8-sig',newline='') as stream:
        trials=[r for r in csv.DictReader(stream) if r['task']=='5']
    keys=list(dict.fromkeys((r['mode'],r['weight']) for r in trials))
    lines += ['', '## Development selection', '',
              'These development seeds (5112-5114) are excluded from formal statistics. Counts below are common A/B successes against the selected Task 4 profile.', '',
              '| Task 5 mode | Weight | Main paired successes | Variant paired successes |',
              '| --- | ---: | ---: | ---: |']
    for trial_mode,weight in keys:
        counts=[]
        for scene in ['main','variant']:
            subset=[r for r in trials if r['mode']==trial_mode and r['weight']==weight and r['scenario']==scene]
            wins=sum(r['success']=='1' and base[(scene,int(r['seed']))] for r in subset)
            counts.append(f'{wins}/{len(subset)}')
        lines.append(f'| {trial_mode} | {weight} | {counts[0]} | {counts[1]} |')
    lines += ['', '## Paired comparison', '']
    for pair in study['paired']:
        if pair['n']==0:
            lines += [f"{pair['scenario']}: n=0 common successful seeds. Paired quality and planning-time comparisons are unavailable.", '']
            continue
        lines += [f"{pair['scenario']}: {pair['n']} common successful seeds {pair['commonSuccessfulSeeds']}. "
                  f"Median maximum tilt: Task 4 {fmt(pair['unconstrainedMaxTilt']['median'])} deg; "
                  f"Task 5 {fmt(pair['constrainedMaxTilt']['median'])} deg. "
                  f"Median paired planning-time difference (B minus A): {fmt(pair['pairedTimeDifference']['median'])} s.", '']
    lines += ['## Demonstrations', '',
              '| Scene | Task | Seed | Minimum conservative gap (mm) | Minimum mesh gap (mm) | Maximum tilt (deg) | Dense states |',
              '| --- | --- | --- | ---: | ---: | ---: | ---: |']
    for d in demos:
        assert d['success']
        lines.append(f"| {d['scenario']} | {d['task']} | {d['seed']} | {1000*d['minVoxelClearance']:.3f} | "
                     f"{1000*d['minMeshClearance']:.3f} | {d['maxOrientationDeg']:.3f} | {d['denseStates']} |")
    lines += ['', '## Failure analysis', '']
    lines += [f"Across all {diag['n']} constrained formal trajectories, including failures, "
              f"{diag['upright']} meet the 5-degree upright check, {diag['selfFailures']} fail self-collision checks, "
              f"and {diag['successes']} pass the complete acceptance gate. Uprightness alone is not planning success.", '']
    for g in study['groups']:
        labels = ', '.join(f'{k}: {v}' for k, v in g['failureCounts'].items() if v)
        lines += [f"{g['name']}: {g['n']-g['successes']} failed runs. " + (labels or 'No failed acceptance gates.') + ' Labels can overlap.', '']
    lines += ['Success requires all acceptance gates, irrespective of objective reduction. '
              'The saved failed trajectory is retained for diagnosis. Optimizer stagnation, finite random exploration, '
              'and the difference between waypoint costs and dense path checks can prevent success within the budget. '
              'The recorded labels identify violated checks; they do not by themselves prove an optimizer failure mechanism.', '',
              'Self collision is an acceptance gate but has no explicit penalty in the reused objective. '
              'Consequently, low obstacle/smoothness cost can coexist with a self collision. '
              'Restarts can explore another branch; acceptance thresholds are unchanged.', '',
              '## Validation and interpretation', '',
              f"The independent read-only audit recomputed acceptance for {audit['runs']} saved runs and replayed "
              f"{audit['replayedCheckpoints']} iteration checkpoints. All audit checks passed. "
              'A correctly recorded unsuccessful experiment passes the integrity audit while remaining a planning failure.', '',
              'Paths were checked with at most .0125 rad change in any joint between dense states. '
              'This is discrete verification. The tool-y direction represents uprightness; no grasped payload, '
              'dynamics, physical trajectory timing, or continuous collision certificate is included. '
              'Ten formal seeds per scene provide a limited empirical sample. Different orientation-weighted '
              'objective totals are not a valid cross-condition performance comparison.', '',
              'The inherited restart convention uses nominal seed + restart - 1. Adjacent nominal runs '
              'can reuse random streams and are not guaranteed statistically independent. Results are '
              'descriptive; no significance tests or independence-based confidence intervals are claimed.', '',
              'The common robot, scenes, endpoints, initialization, sampling settings and budgets were frozen before '
              'formal seeds were used. The constraint mechanism is the A/B intervention. Projection, when selected, '
              'changes the samples after the same raw random draws and adds computation; equal seeds do not imply '
              'identical realized disturbances or equal work per iteration.', '',
              '## Contribution and evidence', '',
              'Member C implemented Task 4-5 scenes, axis-direction cost and optional PoE projection, the unified '
              'acceptance hook, independent validator/replay, paired experiment drivers, and integration figures, '
              'animations, report and slides. The PoE model, conservative robot envelopes and original STOMP '
              'stages are reused from the Task 1-3 handoff.', '',
              'See [method](TASK45_METHODS.md) and [reproduction commands](TASK45_RUNBOOK.md). '
              'Raw formal metrics: `../artifacts/runs/task45_final/formal/all_runs.csv`; '
              'per-run MAT, JSON and dense validation CSV files are stored alongside each run. '
              'Demo media: `../artifacts/runs/task45_final/demos/exports/`. '
              'Each row can be traced to scenario, task and seed.', '',
              f"MATLAB source fingerprint: `{frozen['metadata']['sourceFingerprint']}`. "
              f"Baseline commit: `{frozen['metadata']['commit']}`. The fingerprint covers the new uncommitted MATLAB sources.", '']
    patch_path=FINAL/'provenance/postprocessing_patch.json'
    if patch_path.exists():
        patch=read(patch_path)
        lines += ['## Postprocessing correction', '',
                  'After all 50 planning results were saved, an empty common-success set exposed a MATLAB column-vector iteration bug in aggregation. '
                  'The aggregation loop was corrected and the benchmark guard was updated to accept this exact audited postprocessing fingerprint. '
                  'Original versions of both files were preserved; the other 69 MATLAB source files are unchanged. '
                  'No planning parameters or raw results were changed for this repair. The original experimental fingerprint above remains the identity of every saved formal run.', '',
                  f"Approved postprocessing fingerprint: `{patch['approvedSourceFingerprint']}`. "
                  'See `provenance/postprocessing_patch.json` and `provenance/pre_postprocessing_fix/`.', '']
    return '\n'.join(lines)


def report_pdf(path, frozen, study, demos, groups, mode,diag):
    from reportlab.lib import colors
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib.units import inch
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, Image
    styles = getSampleStyleSheet()
    styles.add(ParagraphStyle(name='BodyTask', parent=styles['BodyText'], fontSize=10, leading=14, spaceAfter=8))
    story = []
    def para(text, style='BodyTask'):
        story.append(Paragraph(text, styles[style]))
    def table(data, widths):
        obj=Table(data,colWidths=widths,repeatRows=1,hAlign='LEFT')
        obj.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),colors.HexColor('#16324f')),('TEXTCOLOR',(0,0),(-1,0),colors.white),
                                ('FONTNAME',(0,0),(-1,0),'Helvetica-Bold'),('FONTSIZE',(0,0),(-1,-1),8),
                                ('BOTTOMPADDING',(0,0),(-1,-1),8),('TOPPADDING',(0,0),(-1,-1),8),
                                ('LINEBELOW',(0,0),(-1,0),.5,colors.grey),('ROWBACKGROUNDS',(0,1),(-1,-1),[colors.whitesmoke,colors.white])]))
        story.append(obj); story.append(Spacer(1,12))
    p=frozen['parameters']
    para('Task 4-5: UR5 transfer with an upright tool', 'Title')
    para('Scene design and planning method','Heading2')
    para('The robot transfers between two fixed, upright joint configurations around three staggered boxes. '
         'The tighter variant shifts both side pillars inward by 40 mm and increases the right pillar height by 40 mm. '
         'Every run starts from the same colliding joint-space line, using the Task 3 PoE backend. '
         'The feasibility witness used in scene design is never supplied to the optimizer.')
    para('Task 4 optimizes obstacle and smoothness cost. Task 5 additionally penalizes the L1 difference '
         'between the tool y axis and world +z. Rotation about the upright axis remains free. '
         f'The selected mode is <b>{mode}</b>, lambda {p["orientationWeight"]}. '
         'Projection, if selected, uses the PoE direction Jacobian and damped least squares; failed projections are rejected.')
    para('Frozen parameters and acceptance','Heading2')
    para(f'{p["nWaypoints"]} waypoints; {p["nRollouts"]} rollouts per round; '
         f'{p["maxIterations"]} iterations per restart; {p["maxRestarts"]} restarts; '
         f'noise {p["noiseStd"]} rad; planner budget {p["maxWallSeconds"]} s. '
         f'A restart is triggered after {p["maxStallIterations"]} rounds without improvement. '
         'The budget includes iteration evidence writes and is checked between iterations. '
         'Development uses seeds 5112-5114 and the predeclared ordered parameter search. '
         'Formal seeds 5120-5129 were excluded from tuning.')
    para('Success requires unchanged endpoints, joint limits, conservative clearance at least 35 mm, '
         'no world or self collision, and (Task 5) maximum tilt at most 5 degrees. '
         'Independent dense checks limit every joint increment to .0125 rad. These are discrete checks. '
         'The optimizer preserves feasible candidates ahead of cheaper infeasible candidates.')
    para('Original Task 1-3 protection','Heading2')
    para('The original frozen results were preserved. Fresh Windows runs passed strict replay and the '
         'new hook preserved Task 1-3 trajectories and acceptance histories bit for bit. '
         'Linux-to-Windows sample roundoff was separately bounded at 8.14e-14, with identical random states.')
    story.append(PageBreak())
    para('Formal results and failure accounting','Title')
    para(f'{study["totalRuns"]} completed nominal cases; two scenes; ten seeds per condition. '
         'Counts and runtime include every completed planning failure. Quality summaries include successful runs only; '
         'technical interruptions are accounted for separately.')
    if diag['technicalInterruptions']:
        para(f'{diag["completedCases"]} completed nominal cases plus {diag["technicalInterruptions"]} archived interrupted attempt. '
             f'Full-output success: {diag["completedSuccesses"]}/{diag["completedCases"]} complete cases, '
             f'{diag["completedSuccesses"]}/{diag["observedAttempts"]} observed attempts. '
             'The interrupted seed 5122 ablation was repeated unchanged; no completed planning failure was removed. '
             'Its partial timing is censored, so the runtime table uses completed cases.')
    data=[['Scene / mode','Success','Median time (s)','Median max tilt (deg)','Median gap (mm)']]
    for g in study['groups']:
        gap=g['minVoxelSuccessful']['median']
        data.append([g['name'],f'{g["successes"]}/{g["n"]}',fmt(g['plannerSecondsAll']['median']),fmt(g['maxTiltSuccessful']['median']),fmt(1000*gap) if gap is not None else '-'])
    table(data,[140,52,90,105,90])
    para('Paired successful seeds','Heading2')
    for pair in study['paired']:
        if pair['n']==0:
            para(f'<b>{pair["scenario"]}</b>: n=0 common successful seeds. No paired quality or planning-time comparison is available.')
            continue
        para(f'<b>{pair["scenario"]}</b>: n={pair["n"]}. Median maximum tilt '
             f'{fmt(pair["unconstrainedMaxTilt"]["median"])} degrees (Task 4) and '
             f'{fmt(pair["constrainedMaxTilt"]["median"])} degrees (Task 5). '
             f'Median paired planning-time difference B minus A: {fmt(pair["pairedTimeDifference"]["median"])} s.')
    para('Failure labels','Heading2')
    para(f'All constrained runs, including failures: {diag["upright"]}/{diag["n"]} meet the upright check; '
         f'{diag["selfFailures"]}/{diag["n"]} fail self-collision checks; {diag["successes"]}/{diag["n"]} pass all acceptance gates.')
    for g in study['groups']:
        labels=', '.join(f'{escape(k)}={v}' for k,v in g['failureCounts'].items() if v) or 'none'
        para(f'<b>{escape(g["name"])}</b>: {labels}.')
    para('Labels can overlap. Failed runs remain saved and counted. Low cost alone is insufficient: '
         'a trajectory can violate dense clearance, self collision, or the orientation threshold. '
         'Recorded failure gates establish what failed; a specific optimizer failure mechanism requires further diagnosis.')
    para('Different weighted objective totals are not compared as performance. Common-seed pairs have the '
         'same raw random conditions; projection changes realized perturbations and computation. '
         'Runtime describes this machine and software configuration.')
    for scene in ['main','variant']:
        story.append(PageBreak())
        para(f'{scene.capitalize()} scene: verified demonstration','Title')
        image=FINAL / f'demos/exports/{scene}/paired_comparison.png'
        assert image.exists()
        from PIL import Image as PILImage
        with PILImage.open(image) as im: w,h=im.size
        story.append(Image(str(image),width=7.1*inch,height=7.1*inch*h/w))
        para('Piecewise linear path progress; arrows show the local tool y axis. '
             'The red clearance line is 35 mm, and the angular gate is 5 degrees. '
             'The cost plot normalizes each condition by its own initial cost.','BodyTask')
        for d in demos:
            if d['scenario']==scene:
                para(f'Task {d["task"]}, seed {d["seed"]}: gap {1000*d["minVoxelClearance"]:.2f} mm, '
                     f'mesh gap {1000*d["minMeshClearance"]:.2f} mm, max tilt {d["maxOrientationDeg"]:.3f} degrees, '
                     f'{d["denseStates"]} dense states.')
        if scene=='variant':
            para('Contribution and limitations','Heading2')
            para('Member C adds scenes, upright cost/projection, unified acceptance, independent verification, '
                 'paired experiments and delivery materials. The Task 1-3 PoE model, envelopes and STOMP '
                 'stages are reused. No payload, dynamics, continuous collision guarantee, or physical timing is modeled.')
    def footer(canvas,doc):
        canvas.setFont('Helvetica',8); canvas.setFillColor(colors.grey)
        canvas.drawString(40,25,'EE5112 Project 2 | Task 4-5 | Sources: frozen config, saved runs, independent audit')
        canvas.drawRightString(572,25,str(doc.page))
    SimpleDocTemplate(str(path),pagesize=(612,792),leftMargin=40,rightMargin=40,topMargin=35,bottomMargin=40).build(story,onFirstPage=footer,onLaterPages=footer)


def build_slides(out,frozen,study,demos,groups,mode,diag):
    import win32com.client
    # User explicitly authorized the installed PowerPoint fallback.
    app=win32com.client.DispatchEx('PowerPoint.Application')
    previous_count=app.Presentations.Count
    deck=app.Presentations.Add(False)
    deck.PageSetup.SlideWidth=960; deck.PageSetup.SlideHeight=540
    navy=0x4F3216; blue=0xAF6B05; grey=0x555555
    notes=[]
    def textbox(slide,text,x,y,w,h,size=20,bold=False,color=navy):
        s=slide.Shapes.AddTextbox(1,x,y,w,h)
        s.TextFrame.MarginLeft=0; s.TextFrame.MarginRight=0
        s.TextFrame.MarginTop=0; s.TextFrame.MarginBottom=0
        s.TextFrame.WordWrap=True
        r=s.TextFrame.TextRange; r.Text=text; r.Font.Name='Arial'; r.Font.Size=size
        r.Font.Bold=bold; r.Font.Color.RGB=color
        return s
    def slide(title):
        s=deck.Slides.Add(deck.Slides.Count+1,12)
        s.Background.Fill.ForeColor.RGB=0xFFFFFF
        textbox(s,title,40,25,880,65,32,True)
        return s
    def picture(s,path,x,y,w):
        from PIL import Image
        with Image.open(path) as im: iw,ih=im.size
        return s.Shapes.AddPicture(str(path),False,True,x,y,w,w*ih/iw)
    def note(s,text,sources):
        notes.append(text)
        s.NotesPage.Shapes.Placeholders(2).TextFrame.TextRange.Text=text+'\n\nSources: '+sources
    try:
        p=frozen['parameters']
        s=slide('UR5 transfer around three obstacles')
        picture(s,FINAL/'demos/exports/main/initial_and_planned.png',35,100,890)
        textbox(s,'Same upright endpoints and colliding linear initialization for both conditions',40,435,880,32,20)
        textbox(s,f'Development demo: seed {frozen["demoSeed"]}; formal results on slide 3\nVariant: side pillars move inward 40 mm; right pillar becomes taller',40,475,880,50,18,color=grey)
        note(s,'这一页说明场景和对照设计。主场景包含中央方块和两侧错列障碍；变体压缩侧向空间。'
             '两组使用完全相同的直立端点，必须从有碰撞的关节线性插值开始。设计时的可行性参考路径没有提供给优化器。',
             'docs/TASK45_METHODS.md; demos/main/*/seed_*/input_checkpoint.mat')
        s=slide('Upright constraint and acceptance')
        textbox(s,'Tool y axis aligned with world +z; free rotation about that axis',40,105,880,55,22)
        textbox(s,'J_ori = lambda sum_t ||R(q_t)e_y - e_z||_1 Delta s',40,180,880,55,24,True,color=blue)
        method='Penalty + PoE Jacobian projection' if mode=='projected' else 'Orientation penalty'
        textbox(s,f'Selected method: {method}; lambda = {p["orientationWeight"]}',40,265,880,45,22)
        textbox(s,'Acceptance: tilt <= 5 deg; conservative clearance >= 35 mm\nFixed endpoints; joint limits; zero world and self collisions',40,335,880,85,22)
        textbox(s,'Dense verification: <= 0.0125 rad per joint step; discrete checks',40,465,880,35,18,color=grey)
        note(s,'姿态要求是工具 y 轴朝向世界正 z，不锁死所有旋转自由度。我们按预定顺序测试罚项权重。'
             f'最终模式是 {mode}。若采用投影，必须说明这是对原 STOMP 的工程扩展：使用 PoE 方向 Jacobian、'
             '阻尼最小二乘和一度内部目标；失败候选被拒绝。成功标签同时受姿态、间距、端点、限位和实际碰撞检查控制。',
             'docs/TASK45_METHODS.md; frozen_config.json; matlab/+memberC/projectTrajectory.m')
        s=slide('Formal success and uprightness')
        rows=[['Scene / condition','Success','Time median (s)','Max tilt median (deg)']]
        for scene_name in ['main','variant']:
            for condition in ['none',mode]:
                g=groups[f'{scene_name}_{condition}']
                rows.append([f'{scene_name} / {"Task 4" if condition=="none" else "Task 5"}',f'{g["successes"]}/{g["n"]}',fmt(g['plannerSecondsAll']['median']),fmt(g['maxTiltSuccessful']['median'])])
        shape=s.Shapes.AddTable(len(rows),4,40,120,880,245)
        widths=[270,120,220,270]
        for j,w in enumerate(widths,1): shape.Table.Columns(j).Width=w
        for i,row in enumerate(rows,1):
            for j,value in enumerate(row,1):
                cell=shape.Table.Cell(i,j).Shape
                cell.TextFrame.TextRange.Text=value
                cell.TextFrame.TextRange.Font.Name='Arial'; cell.TextFrame.TextRange.Font.Size=18
                cell.TextFrame.TextRange.Font.Bold=(i==1)
                cell.TextFrame.TextRange.Font.Color.RGB=navy
                cell.Fill.Solid()
                cell.Fill.ForeColor.RGB=0xF3F3F3 if i%2==0 else 0xFFFFFF
        paired='; '.join(f'{r["scenario"]}: n={r["n"]}' for r in study['paired'])
        context=f'Common successful pairs: {paired}'
        context+=f'\nUpright check: {diag["upright"]}/{diag["n"]} constrained runs'
        if mode=='projected':
            g=groups['main_penalty']; context+=f'; penalty-only ablation: {g["successes"]}/{g["n"]} successful'
        textbox(s,context,40,395,880,60,20)
        footer=f'Seeds 5120-5129; {study["totalRuns"]} complete'
        if diag['technicalInterruptions']: footer+=f' + {diag["technicalInterruptions"]} interrupted'
        footer+='. Time: complete cases; tilt: successes.'
        textbox(s,footer,40,475,880,45,18,color=grey)
        note(s,'这一页只引用正式实验。成功率分母包括失败运行；规划时间中位数也包含失败。'
             '角度中位数仅统计成功运行，因此不能把这列直接当作所有种子的配对比较。'
             '真正配对的质量比较只用共同成功种子，并标明样本数。不同姿态权重的总代价不能直接比较。'
             '完整结果还包含间距、路径长度、平滑度和失败标签，均能追溯到原始 CSV。'
             '如有技术中断，完成的名义运行与全部尝试分母分别列出，中断原记录保留；它不是优化器失败原因的证明。',
             'formal/study_summary.json; formal/all_runs.csv; attempt_accounting.json; docs/TASK45_RESULTS.md')
        s=slide('Member C contribution and limits')
        textbox(s,'Added: obstacle scenes, upright mechanism, unified acceptance\nIndependent replay, paired experiments, figures and animations',40,110,880,90,22)
        textbox(s,'Reused: Task 1-3 PoE model, sphere envelopes and STOMP stages',40,235,880,55,22)
        textbox(s,'Limits: self collision is enforced only at acceptance\nDiscrete checks; finite seed sample; no payload or dynamics\nAnimation progress is a path parameter, not physical time',40,325,880,95,22)
        textbox(s,'Reproduce: run_task45  |  run_task45_benchmark  |  verify_task45',40,465,880,40,18,color=blue)
        note(s,'贡献边界要讲清楚：队友已经完成 PoE、球包络和原始 STOMP 计算阶段；我们新增的是 Task 4-5 场景、'
             '直立机制、统一验收、独立复核、配对实验和交付材料。验证是离散加密检查，不是连续安全证明。'
             '动画没有动力学时间含义，也没有对杯子或其他载荷建模。所有正式失败保留，不能只展示成功演示。',
             'docs/TASK45_METHODS.md; independent_audit.json; demos/exports/export_manifest.json')
        assert deck.Slides.Count==4
        pptx=out/'task45_slides.pptx'; pdf=out/'task45_slides.pdf'
        assert not pptx.exists(),'Choose a new output; do not overwrite an existing deck.'
        deck.SaveAs(str(pptx),24)
        deck.SaveAs(str(pdf),32)
        (out/'task45_speaker_notes_zh.md').write_text('\n\n'.join(f'## Slide {i}\n\n{n}' for i,n in enumerate(notes,1)),encoding='utf-8')
        deck.Close(); deck=None
        check=app.Presentations.Open(str(pptx),True,False,False)
        assert check.Slides.Count==4
        check.Close()
    finally:
        if deck is not None: deck.Close()
        if previous_count==0 and app.Presentations.Count==0: app.Quit()


if __name__=='__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main()
