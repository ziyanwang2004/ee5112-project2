"""Build V2 course materials from independently audited data. V1 stays read-only."""
from pathlib import Path
import json
from xml.sax.saxutils import escape

ROOT=Path(__file__).resolve().parents[1]
FINAL=ROOT/'artifacts/runs/task45_v2'
OUT=FINAL/'delivery'
def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def fmt(x,n=2): return '-' if x is None else f'{x:.{n}f}'
def group_label(name):
    scene,mode=name.rsplit('_',1)
    return scene+' / '+{'none':'Task 4','projected':'Task 5','penalty':'penalty only'}[mode]

def main():
    frozen=read(FINAL/'frozen_config.json'); study=read(FINAL/'formal/study_summary.json')
    audit=read(FINAL/'formal/independent_audit.json'); demo_audit=read(FINAL/'demos/independent_audit.json')
    assert audit['passed'] and audit['runs']==50 and demo_audit['passed'] and demo_audit['runs']==4
    assert study['totalRuns']==50
    demos=[read(p) for p in sorted((FINAL/'demos').glob('**/summary.json'))]; assert len(demos)==4 and all(d['success'] for d in demos)
    rows=[read(p) for p in (FINAL/'formal').glob('**/summary.json')]
    active=[r for r in rows if r['mode']=='projected']; assert len(active)==20
    diag={'upright':sum(r['maxOrientationDeg']<=5+1e-8 for r in active),
          'selfFailures':sum('self_collision' in r['failures'] for r in active),
          'success':sum(r['success'] for r in active)}
    OUT.mkdir(exist_ok=True)
    md=markdown(frozen,study,audit,diag)
    (ROOT/'docs/TASK45_V2_RESULTS.md').write_text(md,encoding='utf-8')
    index=['# Task 4-5 V2 结果与复现','','旧版 README 和 V1 证据保持冻结。最新结果从此页进入。','',
        '| 场景 / 条件 | 正式成功数 |','| --- | ---: |']
    for group in study['groups']: index.append(f"| {group_label(group['name'])} | {group['successes']}/{group['n']} |")
    index+=['','正式种子为 5200–5209，开发种子不进入上述统计。所有正式失败均计入分母。penalty only 是去掉姿态投影、保留 λ=1000 罚项的消融组。',
        '', '[英文报告](artifacts/runs/task45_v2/delivery/task45_v2_report.pdf) · [可编辑展示材料](artifacts/runs/task45_v2/delivery/task45_v2_slides.pptx) · [展示材料 PDF](artifacts/runs/task45_v2/delivery/task45_v2_slides.pdf)',
        '', '[V1 失败原因](docs/TASK5_V1_FAILURE_ANALYSIS.md) · [完整结果与统计口径](docs/TASK45_V2_RESULTS.md) · [源代码与复现说明](upgrades/task45_v2/README.md)',
        '', '```powershell', '& \'D:\\Program Files\\MATLAB\\bin\\matlab.exe\' -batch "addpath scripts; r=run_task45_v2(\'all\',\'all\',5150,false,\'D:\\new_empty_run_root\'); audit=verify_task45_v2(\'D:\\new_empty_run_root\');"', '```',
        '', '完整 50 次重跑使用 `addpath scripts; run_task45_v2_benchmark(newRunRoot)`，必须提供新的输出目录。原始正式研究使用两进程；该入口顺序运行，因此运行时间仅在同一执行方式内比较。',
        '', '动画和可编辑 FIG 位于 `artifacts/runs/task45_v2/demos/exports/`。检查属于离散加密验证，动画横轴为路径进度。','']
    (ROOT/'README_TASK45_V2.md').write_text('\n'.join(index),encoding='utf-8')
    analysis_path=ROOT/'docs/TASK5_V1_FAILURE_ANALYSIS.md'
    analysis=analysis_path.read_text(encoding='utf-8').split('\n## Fresh formal repair validation')[0]
    analysis+=f"\n## Fresh formal repair validation\n\nV2 projected Task 5 passes **{diag['success']}/20** fresh formal cases. All {len(active)} cases are retained, including any failures. The upright check passes {diag['upright']}/20 and the self-collision gate fails {diag['selfFailures']}/20.\n\nThe independent formal audit covers {audit['runs']} runs and {audit['replayedCheckpoints']} fully replayed optimizer checkpoints. Full A/B and ablation counts are in [V2 results](TASK45_V2_RESULTS.md).\n\n![Representative V1 collision and a V2 path state](../artifacts/runs/task45_v2/diagnosis/self_collision_comparison.png)\n"
    analysis_path.write_text(analysis,encoding='utf-8')
    report(frozen,study,audit,demos,diag)
    slides(frozen,study,demos,diag)
    print('V2 materials created:',OUT)

def markdown(f,s,a,diag):
    lines=['# Task 4-5 V2 results','','V1 remains frozen at `artifacts/runs/task45_final/`. V2 is a separate study.',
        '',f"V2 uses new formal seeds 5200-5209. All {s['totalRuns']} completed cases, including failures, enter statistics.",
        '', '| Scene / mode | Success | Median planner time (s) | Median max tilt, successes (deg) | Median gap, successes (mm) |',
        '| --- | ---: | ---: | ---: | ---: |']
    for g in s['groups']:
        gap=g['minVoxelSuccessful']['median']
        lines.append(f"| {group_label(g['name'])} | {g['successes']}/{g['n']} | {fmt(g['plannerSecondsAll']['median'])} | {fmt(g['maxTiltSuccessful']['median'])} | {fmt(None if gap is None else gap*1000)} |")
    lines+=['',f"Projected Task 5: {diag['success']}/20 full success, {diag['upright']}/20 upright, {diag['selfFailures']}/20 self-collision failures.",
        '', '## Method and validation', '',
        'Both conditions use the same self-collision penalty and in-loop actual mesh rejection. Task 5 adds the orientation penalty and PoE direction projection. The final acceptance conditions remain unchanged.',
        '', 'The added costs are `J_self = 60000 sum_t sum_(i,j) max(0, tau_ij - d_ij(q_t))^2 Delta s` and `J_ori = 1000 sum_t ||R(q_t)e_y - e_z||_1 Delta s`. Here d is the enclosing-capsule gap, and tau is min(0.005 m, d(qStart), d(qGoal)) for each non-parent pair. The projector uses a 1 degree internal target, damping 1e-3, at most 20 steps per waypoint and a 0.15 rad component step cap.',
        '', 'The 300 s planner target is checked between iterations and includes trace writes. A final iteration can extend past the target. Actual elapsed times, including these small overruns, enter the statistics.',
        '', 'The capsule target for a body pair is the smaller of 5 mm and its two fixed-endpoint capsule gaps. Some enclosing capsules overlap at actual collision-free endpoints. This soft target prevents impossible proxy targets and never relaxes actual mesh checks.',
        '', 'Restart seeds use seed + 100000*(restart-1). The selected nominal seed ranges do not reuse the same restart seed. Two local MATLAB worker processes divide the fixed seeds by parity. No significance test or cross-version speed claim is made.',
        '',f"Independent audit: {a['runs']} formal runs, {a['replayedCheckpoints']} replayed checkpoints, {a['recomputedCosts']} independently recomputed costs.",
        '',f"Source fingerprint: `{f['metadata']['sourceFingerprint']}`. Base commit: `{f['metadata']['commit']}`. The fingerprint identifies the uncommitted source used for this study.",
        '', '## Paired results','']
    for p in s['paired']:
        lines.append(f"{p['scenario']}: n={p['n']} common successful seeds {p['commonSuccessfulSeeds']}. Median paired time difference B minus A: {fmt(p['pairedTimeDifference']['median'])} s. Median max tilt A/B: {fmt(p['unconstrainedMaxTilt']['median'])}/{fmt(p['constrainedMaxTilt']['median'])} deg.")
    lines+=['','## Failures','']
    for g in s['groups']:
        failures=', '.join(f'{k}={v}' for k,v in g['failureCounts'].items() if v) or 'none'
        lines.append(f"- {g['name']}: {failures}.")
    lines+=['','Failure labels may overlap. Quality comparisons use common successful seeds only. Different weighted objective totals are not a performance comparison.',
        '', '## Evidence and scope','',
        'The incomplete capsule-only development pilot is retained with a cancellation receipt and source snapshot. It was abandoned before freezing and is excluded from the fresh formal study. Every completed formal failure remains in the denominator.',
        '', 'V1 failure causes and representative body pairs: `docs/TASK5_V1_FAILURE_ANALYSIS.md`. V2 frozen parameters and exact driver hashes: `artifacts/runs/task45_v2/frozen_config.json`.',
        '', 'Checks are discrete interpolated collision checks at a per-joint step of 0.0125 rad. There is no continuous collision guarantee, payload, dynamics model or physical timing model. Animations use normalized path progress.',
        '', 'Reproduce individual runs with `addpath scripts; run_task45_v2(...)`; revalidate read-only with `verify_task45_v2(runRoot)`. The preserved source snapshot and complete raw inputs, random states, actual projected disturbances and accepted updates are under the V2 release directory.','']
    return '\n'.join(lines)

def report(f,s,a,demos,diag):
    from reportlab.platypus import SimpleDocTemplate,Paragraph,Spacer,PageBreak,Table,TableStyle,Image
    from reportlab.lib.styles import getSampleStyleSheet,ParagraphStyle
    from reportlab.lib import colors
    from PIL import Image as PILImage
    styles=getSampleStyleSheet(); styles.add(ParagraphStyle(name='TextV2',fontName='Helvetica',fontSize=10,leading=13,spaceAfter=8))
    story=[]
    def p(text,style='TextV2'): story.append(Paragraph(text,styles[style]))
    def table(data,widths):
        t=Table([[Paragraph(escape(str(v)),styles['TextV2']) for v in row] for row in data],colWidths=widths,hAlign='LEFT')
        t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),colors.HexColor('#e8eef5')),('VALIGN',(0,0),(-1,-1),'TOP'),('LINEBELOW',(0,0),(-1,0),.6,colors.grey),('BOTTOMPADDING',(0,0),(-1,-1),4)])); story.append(t); story.append(Spacer(1,8))
    def picture(path,width=522):
        with PILImage.open(path) as im: w,h=im.size
        story.append(Image(str(path),width=width,height=width*h/w))
    p('UR5 multi-obstacle transfer and upright motion','Title')
    p('Task 4-5 V2 implementation, fresh-seed evaluation and failure diagnosis','Heading2')
    p('The main scene contains three staggered boxes. The variant moves both side pillars inward by 40 mm and raises the right pillar. Both tasks use the same upright endpoints and colliding straight joint interpolation. The PoE model, sphere envelopes and original STOMP stages come from Tasks 1-3. No feasible witness path initializes the optimizer.')
    p('Why V1 Task 5 failed','Heading2')
    p('All 20 V1 projected formal paths satisfy orientation (maximum tilt 0.462-0.963 degrees) and the conservative world margin (38.34-69.18 mm). Every path self-collides. Representative mesh checks identify forearm/wrist intersections and, in some runs, base/arm and shoulder/arm intersections. The original objective omits self-collision. Direction projection cannot resolve geometry, and cost-only acceptance discards candidates before feasibility testing. Adjacent V1 seeds also reuse restart streams.')
    p('V2 method','Heading2')
    p('A capsule penalty guides separation of non-parent body pairs in both conditions. Public collision visualization supplies the installed meshes. Enclosing capsules can overlap where meshes are separated, so pair targets are capped at the fixed-endpoint capsule gaps. Actual mesh self-collision rejection now operates inside candidate selection. Promising fully feasible proposals take priority even when their cost increases. Task 5 additionally uses the L1 tool-y direction penalty and unchanged damped PoE projection.')
    param=f['parameters']
    table([['Waypoints / rollouts','Iterations / restarts','Self / orientation weight','Budget / noise'],[f"{param['nWaypoints']} / {param['nRollouts']}",f"{param['maxIterations']} / {param['maxRestarts']}",f"{param['selfWeight']} / {param['orientationWeight']}",f"{param['maxWallSeconds']} s / {param['noiseStd']} rad"]],[115,115,155,137])
    p('The planner checks its time target between iterations, including trace writes. A final iteration can finish slightly after 300 s. Statistics retain actual elapsed times.')
    p('Acceptance requires fixed endpoints, joint limits, at least 35 mm conservative world clearance, zero actual world and self collisions, and maximum tilt at most 5 degrees for Task 5. Final interpolated checks limit every joint increment to 0.0125 rad. These are discrete checks.')
    p('Development uses seeds 5150-5152. Formal seeds 5200-5209 were reserved until freezing. Restart streams use a stride of 100000. Two local workers split the formal seeds by parity. The incomplete capsule-only pilot is preserved separately as abandoned development work.')
    story.append(PageBreak()); p('Fresh formal results','Title')
    p('All 50 completed nominal cases enter the statistics: 40 paired scene/task runs and 10 main-scene penalty-only ablations. Runtime summaries include completed failures. Quality summaries use successful runs only.')
    data=[['Scene / mode','Success','Time median (s)','Max tilt (deg)','Gap (mm)']]
    for g in s['groups']:
        gap=g['minVoxelSuccessful']['median']; data.append([group_label(g['name']),f"{g['successes']}/{g['n']}",fmt(g['plannerSecondsAll']['median']),fmt(g['maxTiltSuccessful']['median']),fmt(None if gap is None else 1000*gap)])
    table(data,[159,57,110,106,90])
    p(f"Projected Task 5: <b>{diag['success']}/20</b> full success, {diag['upright']}/20 meet the upright check and {diag['selfFailures']}/20 fail self-collision checks. V1's projected result remains preserved at 0/20. These are descriptive counts on different fixed seed sets.")
    p('Common successful pairs','Heading2')
    for pair in s['paired']:
        p(f"<b>{pair['scenario']}</b>: n={pair['n']}. Median maximum tilt A/B: {fmt(pair['unconstrainedMaxTilt']['median'])}/{fmt(pair['constrainedMaxTilt']['median'])} degrees. Median paired planner time B minus A: {fmt(pair['pairedTimeDifference']['median'])} s.")
    p('Failure labels','Heading2')
    for g in s['groups']:
        labels=', '.join(f'{k}={v}' for k,v in g['failureCounts'].items() if v) or 'none'
        p(f"<b>{escape(g['name'])}</b>: {escape(labels)}.")
    p('Labels can overlap. Different weighted objective totals are not used to claim better performance. Two workers share this machine, so no cross-version runtime inference or significance claim is made.')
    p('Independent evidence','Heading2')
    p(f"Fresh mesh/clearance validation and complete random-sample/update replay passed for {a['runs']} formal runs ({a['replayedCheckpoints']} checkpoints). The audit also recomputed {a['recomputedCosts']} objective values and checked in-loop safety receipts. Four demonstration runs passed a separate audit. V1's 6458-file manifest still matches byte for byte.")
    for scene in ['main','variant']:
        story.append(PageBreak()); p(f'{scene.capitalize()} scene: paired demonstration','Title')
        picture(FINAL/f'demos/exports/{scene}/paired_comparison.png')
        p('Tool-y arrows show uprightness along normalized path progress. The angular gate is 5 degrees and the conservative clearance gate is 35 mm. Each cost curve is normalized to its own initial objective.')
        for d in demos:
            if d['scenario']==scene:
                p(f"Task {d['task']}, seed {d['seed']}: minimum conservative clearance {1000*d['minVoxelClearance']:.2f} mm, actual mesh world gap {1000*d['minMeshClearance']:.2f} mm, maximum tilt {d['maxOrientationDeg']:.3f} degrees. All {d['denseStates']} dense states pass world and self checks.")
        if scene=='variant':
            p('Contribution and limits','Heading2')
            p('Member C adds the scenes, direction mechanism, self-aware acceptance, independent audits, paired studies and delivery materials. The project still uses a finite seed sample and discrete collision checks. No payload, dynamics or continuous collision guarantee is modeled. Animation progress is not physical time.')
    def footer(canvas,doc):
        canvas.setFont('Helvetica',8); canvas.setFillColor(colors.grey)
        canvas.drawString(40,24,'EE5112 Project 2 / Task 4-5 V2 / frozen configuration, saved paths and independent audits')
        canvas.drawRightString(572,24,str(doc.page))
    SimpleDocTemplate(str(OUT/'task45_v2_report.pdf'),pagesize=(612,792),leftMargin=40,rightMargin=40,topMargin=35,bottomMargin=40).build(story,onFirstPage=footer,onLaterPages=footer)

def slides(f,s,demos,diag):
    import win32com.client
    from PIL import Image
    target=OUT/'task45_v2_slides.pptx'; assert not target.exists(),'Refuse to overwrite the final deck.'
    app=win32com.client.DispatchEx('PowerPoint.Application'); previous_count=app.Presentations.Count
    deck=app.Presentations.Add(False); deck.PageSetup.SlideWidth=960; deck.PageSetup.SlideHeight=540
    notes=[]; navy=0x4F3216
    def text(slide,content,x,y,w,h,size=21,bold=False,color=navy):
        shape=slide.Shapes.AddTextbox(1,x,y,w,h); shape.TextFrame.MarginLeft=0; shape.TextFrame.MarginRight=0; shape.TextFrame.MarginTop=0; shape.TextFrame.MarginBottom=0; shape.TextFrame.WordWrap=True
        r=shape.TextFrame.TextRange; r.Text=content; r.Font.Name='Arial'; r.Font.Size=size; r.Font.Bold=bold; r.Font.Color.RGB=color
        return shape
    def slide(title):
        z=deck.Slides.Add(deck.Slides.Count+1,12); z.Background.Fill.ForeColor.RGB=0xFFFFFF; text(z,title,40,25,880,65,32,True); return z
    def pic(z,path,x,y,w):
        with Image.open(path) as im: iw,ih=im.size
        z.Shapes.AddPicture(str(path),False,True,x,y,w,w*ih/iw)
    def note(z,content,sources):
        notes.append(content); z.NotesPage.Shapes.Placeholders(2).TextFrame.TextRange.Text=content+'\n\nSources: '+sources
    try:
        z=slide('UR5 multi-obstacle transfer')
        pic(z,FINAL/'demos/exports/main/initial_and_planned.png',35,110,890)
        text(z,'Same upright endpoints and colliding linear initialization',40,430,880,40)
        text(z,'Variant: side pillars move inward 40 mm and the right pillar becomes taller',40,480,880,40,18,color=0x555555)
        note(z,'主场景包含中央方块和两根错列立柱，变体压缩侧向空间。两组端点、初始化、场景和计算预算相同。参考可行路径只用于场景设计，没有作为规划器的初始化或输出。Task 4 允许倾斜，Task 5 要求工具 y 轴直立。','V2 demos/*/*/seed_*/input_checkpoint.mat; frozen_config.json')
        z=slide('Self-collision handling in V2')
        text(z,'V1: all 20 projected paths were upright, but all self-collided',40,105,880,60,23,True)
        text(z,'Tool y aligned with world +z, with yaw free.\nV1 omitted self-collision from its objective.',40,195,880,60)
        text(z,'V2: self-collision penalty and actual mesh rejection during updates',40,280,880,60,23,True)
        text(z,'Feasible candidates take priority over lower cost.\nTask 5 retains the PoE direction projection and orientation penalty.',40,365,880,65)
        text(z,'Final gates: tilt <= 5 deg, proxy gap >= 35 mm, zero world and self collisions',40,475,880,45,18,color=0x555555)
        note(z,'V1 正式实验 0/20 的直接原因是自碰撞，不是直立误差超限。原代价缺少自碰撞，投影只能控制方向。V2 在两组中同时加入自碰撞软代价和实际网格筛选，并允许可行候选以较高代价被接受。胶囊可能保守重叠，软目标按端点间距校准，最终网格验收条件完全不变。重启种子间隔改为十万，避免原版相邻种子复用随机流。','docs/TASK5_V1_FAILURE_ANALYSIS.md; upgrades/task45_v2/matlab/+memberC/plan.m; stompTrajCost.m')
        z=slide('Fresh formal results')
        data=[['Scene / mode','Success','Median time\n(s)','Median max tilt\n(deg)']]
        for g in s['groups']: data.append([group_label(g['name']),f"{g['successes']}/{g['n']}",fmt(g['plannerSecondsAll']['median']),fmt(g['maxTiltSuccessful']['median'])])
        shape=z.Shapes.AddTable(len(data),4,40,115,880,255)
        for j,w in enumerate([280,110,225,265],1): shape.Table.Columns(j).Width=w
        for i,row in enumerate(data,1):
            for j,value in enumerate(row,1):
                cell=shape.Table.Cell(i,j).Shape; r=cell.TextFrame.TextRange; r.Text=value; r.Font.Name='Arial'; r.Font.Size=18; r.Font.Bold=(i==1); r.Font.Color.RGB=navy
                cell.Fill.Solid(); cell.Fill.ForeColor.RGB=0xF3F3F3 if i%2==0 else 0xFFFFFF
        pairs=', '.join(f"{p['scenario']} n={p['n']}" for p in s['paired'])
        text(z,f"Common successful pairs: {pairs}\nTask 5 upright: {diag['upright']}/20. Self-collision failures: {diag['selfFailures']}/20.",40,400,880,65,20)
        text(z,'Fresh seeds 5200-5209. All failures counted. Time includes failures, tilt uses successes.',40,485,880,40,18,color=0x555555)
        note(z,'这页只展示冻结后使用全新种子的正式结果。所有失败都进入成功率和耗时统计，倾角质量列只统计成功路径。两套场景的配对质量比较只使用共同成功种子，并显示样本数。V1 与 V2 用的是不同种子集，因此只报告描述性的成功数变化，不宣称跨版本显著性或速度提升。','formal/study_summary.json; formal/all_runs.csv; formal/independent_audit.json')
        z=slide('Member C contribution and limits')
        pic(z,FINAL/'demos/exports/variant/paired_comparison.png',30,115,480)
        text(z,'Added\nScenes, upright constraint, self-aware updates, fresh-seed study and replay',550,115,370,125,21)
        text(z,'Reused\nTask 1-3 PoE model, sphere envelopes and STOMP stages',550,270,370,90,21)
        text(z,'Limits\nDiscrete checks, finite seeds, no payload or dynamics',550,390,370,90,21)
        text(z,'Run: addpath scripts; run_task45_v2(...)     Verify: verify_task45_v2(runRoot)',40,495,880,30,17,color=0x555555)
        note(z,'我们的贡献是 Task 4-5 多障碍场景、直立约束、自碰撞感知更新、独立复核、正式配对实验和交付材料。队友的 PoE、球包络及原 STOMP 阶段继续复用。验证属于加密离散检查，不是连续碰撞证明。动画展示路径进度，不代表机械臂执行时间，也没有杯子载荷或动力学模型。原 V1 失败数据保留，新的成功结果没有覆盖旧证据。','V2 demos/exports/variant/paired_comparison.fig; formal/independent_audit.json; docs/TASK45_V2_RESULTS.md')
        assert deck.Slides.Count==4; deck.SaveAs(str(target),24); deck.SaveAs(str(OUT/'task45_v2_slides.pdf'),32)
        (OUT/'task45_v2_speaker_notes_zh.md').write_text('\n\n'.join(f'## Slide {i}\n\n{n}' for i,n in enumerate(notes,1)),encoding='utf-8')
        deck.Close(); deck=None
        check=app.Presentations.Open(str(target),True,False,False); assert check.Slides.Count==4; check.Close()
    finally:
        if deck is not None: deck.Close()
        if previous_count==0 and app.Presentations.Count==0: app.Quit()

if __name__=='__main__': main()
