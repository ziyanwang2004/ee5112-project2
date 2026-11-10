"""Build the V3 addendum only after independent audits and final exports pass.

Uses the existing PowerPoint COM workflow authorized for this project.
Never edits the frozen MATLAB implementation or previous releases.
"""
from pathlib import Path
from statistics import median
from xml.sax.saxutils import escape
import json

ROOT = Path(__file__).resolve().parents[1]
RELEASE = ROOT / 'artifacts/runs/task45_v3'
OUT = RELEASE / 'delivery'
EXPORT = RELEASE / 'demos/exports/workcell'


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def as_list(value):
    return value if isinstance(value, list) else [value]


def collect():
    study = read(RELEASE / 'formal/study_summary.json')
    audit = read(RELEASE / 'formal_audit.json')
    demo_audit = read(RELEASE / 'demo_audit.json')
    fine = read(RELEASE / 'fine_validation.json')
    frozen = read(RELEASE / 'frozen_config.json')
    rows = [read(p) for p in sorted((RELEASE / 'formal').glob('**/summary.json'))]
    assert len(rows) == study['totalRuns'] == audit['runs'] == 40
    assert audit['passed'] and demo_audit['passed'] and demo_audit['runs'] == 2
    assert fine['passed'] and fine['jointStep'] == .00625
    assert read(RELEASE / 'numpy_fk_crosscheck.json')['passed']
    assert fine['checkedSuccessfulPaths'] == sum(r['success'] for r in rows)
    groups = {}
    for task, mode in [(4, 'none'), (5, 'projected')]:
        selected = [r for r in rows if r['task'] == task]
        verified = [r for r in fine['details'] if r['task'] == task]
        assert len(selected) == 20 and sorted(r['seed'] for r in selected) == list(range(5400, 5420))
        successful = [r for r in selected if r['success']]
        groups[task] = {
            'task': task, 'mode': mode, 'n': len(selected),
            'successes': len(successful),
            'medianTime': median(r['plannerSeconds'] for r in selected),
            'worstTilt': max((r['maxOrientationDeg'] for r in verified), default=None),
            'minGap': min((r['minVoxelClearance'] for r in verified), default=None),
            'minHeight': min((r['minToolHeight'] for r in verified), default=None),
            'minMeshGap': min((r['minMeshClearance'] for r in successful), default=None),
        }
    assert len(list(EXPORT.glob('*.avi'))) == 3
    for name in ['initial_and_planned', 'paired_metrics', 'task4_summary', 'task5_summary']:
        assert (EXPORT / (name + '.png')).is_file() and (EXPORT / (name + '.fig')).is_file()
    pairs = as_list(study['paired'])[0]
    return {'study': study, 'audit': audit, 'demoAudit': demo_audit, 'fine': fine,
            'frozen': frozen, 'rows': rows, 'groups': groups, 'pairs': pairs}


def table_rows(data):
    table = [['Condition', 'Success', 'Median time\n(s)', 'Worst tilt\n(deg)',
              'Min gap\n(mm)', 'Min tool z\n(mm)']]
    for task in [4, 5]:
        g = data['groups'][task]
        table.append([f'Task {task}', f"{g['successes']}/{g['n']}", f"{g['medianTime']:.2f}",
                      f"{g['worstTilt']:.3f}", f"{1000*g['minGap']:.2f}", f"{1000*g['minHeight']:.1f}"])
    return table


def write_markdown(data):
    a, b = data['groups'][4], data['groups'][5]
    audit, pairs = data['audit'], data['pairs']
    lines = [
        '# V3 mounted-workcell results', '',
        'This is a separate third scene with new upright endpoints. V1 and V2 remain unchanged. '
        'All 40 formal runs use reserved seeds 5400-5419; development uses 5300-5302. '
        'No holdout retuning or reference-path initialization was used.', '',
        '| Condition | Success | Median planner time (s) | Worst tilt (deg) | Minimum proxy gap (mm) | Minimum tool height (mm) |',
        '| --- | ---: | ---: | ---: | ---: | ---: |',
    ]
    for row in table_rows(data)[1:]:
        lines.append('| ' + ' | '.join(row) + ' |')
    lines += [
        '', 'The success denominator includes every formal run. Timings include failures if any. '
        'Tilt, proxy gap and height above are extrema over successful paths at the extra 0.00625 rad check. '
        'There were no failed formal runs in this study.', '',
        '## Scene and mounting contact', '',
        'A fixed 0.18 x 0.18 x 0.20 m pedestal raises the UR5 base to world z=0.20 m. '
        'The table top is z=0; its forbidden volume spans the full sub-table voxel workspace. '
        'A central rack, two equipment boxes and a rear guard define the transfer region. '
        'Only the fixed pedestal/table contact is permitted. Every UR5 link and the tool '
        'remain subject to world and self-collision checks. The pedestal is included in '
        'the actual robot self-collision model and optimization self proxy.', '',
        'The common straight initialization has 92/181 colliding world states at 0.0125 rad '
        'sampling and no self collisions. Both endpoints pass. The geometric existence '
        'witness is kept separate and never supplied to the planner.', '',
        '## Planner and acceptance', '',
        'Both conditions retain V2 self-collision costs and in-loop actual mesh rejection. '
        'Task 5 adds lambda=1000 orientation cost and the PoE direction projector. '
        'Tool y must align with world +z; yaw is free. The selected first development '
        'profile uses 61 waypoints, 64 rollouts, noise 0.55 rad, 200 iterations per restart, '
        'up to 3 restarts and a 300 s target checked between iterations, including trace writes. '
        'The last iteration may exceed that target. Two workers split seeds by parity and '
        'alternate A/B order. Runtime is descriptive for this execution setup.', '',
        'Acceptance preserves exact endpoints and joint limits, requires 35 mm conservative '
        'UR5 sphere clearance, zero unpermitted actual world collisions, zero actual self '
        'collisions and tool above the table. Task 5 additionally requires tilt <=5 degrees. '
        'All successful formal paths also pass 0.00625 rad joint-increment validation. '
        'This is discrete validation, not a continuous collision proof.', '',
        '## Pairing and scope', '',
        f"Common successful pairs: n={pairs['n']}. The median paired planner-time difference "
        f"Task 5 minus Task 4 is {pairs['pairedTimeDifference']['median']:.2f} s. "
        'No comparison of differently weighted objective totals is used to claim performance.', '',
        f"For a condition with 20/20 successes, the exact two-sided 95% binomial lower bound "
        f"is {100*.025**(1/20):.2f}%, under independent Bernoulli trials in this fixed scene. "
        'The paired conditions and earlier scenes are not pooled into a universal reliability estimate.', '',
        'The earlier V2 scenes lacked a ground obstacle: 7/20 projected formal paths put '
        'the tool below base z=0. V3 directly addresses that scene-design limitation with '
        'an explicit installation and table. Different endpoints and seeds prevent a causal '
        'cross-version speed or quality claim. There is still no payload geometry, dynamics '
        'or execution-time model.', '',
        '## Independent evidence', '',
        f"The formal audit independently reconstructs the robot and scene, checks all 40 final "
        f"paths and replays {audit['replayedCheckpoints']} optimizer checkpoints. "
        f"The two demonstrations replay {data['demoAudit']['replayedCheckpoints']} checkpoints. "
        'Fine per-state CSV profiles are under `verification/fine_profiles/`. '
        'All prior release checksums remain independently checkable.', '',
        'A separate NumPy Rodrigues/PoE calculation using the original Task 3 screws '
        'and a 0.20 m mounting translation matches all 46,798 fine states: maximum '
        'tool-position difference 1.70e-15 m and tilt difference 2.00e-13 degrees. '
        'This cross-check concerns FK and orientation; it is not another collision checker.', '',
        f"Frozen MATLAB source fingerprint: `{data['frozen']['metadata']['sourceFingerprint']}`. "
        'A Git checkpoint occurred while formal workers were running. Each run preserves '
        'its actual commit; `git_checkpoint.json` documents the transition without a MATLAB '
        'source or parameter change.', '',
        '## Reproduction and contribution', '',
        'From the repository root in a fresh MATLAB session:', '',
        '```matlab', "addpath('scripts')", "show_project_demo('all','v3')",
        "% Fresh planning into a new output directory:",
        "r = run_task45_v3('all',5300,newRunRoot);",
        'audit = verify_task45_v3(newRunRoot);', '```', '',
        'Member C adds the new scene, mount model/contact policy, table-height acceptance, '
        'held-out paired study, fine validation, replay and delivery materials. '
        'The Task 1-3 PoE, sphere envelopes and STOMP stages are reused; the V2 constraint '
        'and self-collision mechanism are retained.', '',
        '[Protocol](TASK45_V3_PROTOCOL.md) | '
        '[Report](../artifacts/runs/task45_v3/delivery/task45_v3_report.pdf) | '
        '[Slides](../artifacts/runs/task45_v3/delivery/task45_v3_slides.pptx)', '',
    ]
    (ROOT / 'docs/TASK45_V3_RESULTS.md').write_text('\n'.join(lines), encoding='utf-8')
    index = [
        '# Task 4-5 V3：桌面安装场景', '',
        f"新场景正式实验：Task 4 **{a['successes']}/20**，Task 5 **{b['successes']}/20**。"
        '正式种子 5400-5419，开发种子 5300-5302；两组采用同一端点、碰撞初始化和基础预算。', '',
        f"额外 0.00625 rad 加密复核中，Task 5 最大倾角 **{b['worstTilt']:.3f}°**，"
        f"最小保守间距 **{1000*b['minGap']:.2f} mm**，工具距桌面最小高度 **{1000*b['minHeight']:.1f} mm**。", '',
        '机器人通过固定底座安装在桌面上；只允许固定底座接触桌面，所有 UR5 连杆和工具均参与碰撞检查。'
        '这解决了原场景没有地面限制的不足。V1/V2 历史记录继续保留。', '',
        '```matlab', "addpath('scripts')", "show_project_demo('all','v3')", '```', '',
        '[完整结果与边界](docs/TASK45_V3_RESULTS.md) · '
        '[英文报告](artifacts/runs/task45_v3/delivery/task45_v3_report.pdf) · '
        '[可编辑展示](artifacts/runs/task45_v3/delivery/task45_v3_slides.pptx) · '
        '[中文备注](artifacts/runs/task45_v3/delivery/task45_v3_speaker_notes_zh.md)', '',
        '[完整项目演示指南](docs/PROJECT_DEMO_GUIDE_ZH.md) · '
        '[Git 快照与本地原始档案](GIT_SNAPSHOT.md)', '',
        '结果只对应已记录的场景与种子；验证是离散加密检查，尚不包含载荷、动力学或实机执行。', '',
    ]
    (ROOT / 'README_TASK45_V3.md').write_text('\n'.join(index), encoding='utf-8')


def report(data):
    from reportlab.lib import colors
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Image, Table, TableStyle, PageBreak
    from PIL import Image as PILImage
    styles = getSampleStyleSheet()
    styles.add(ParagraphStyle('BodySmall', parent=styles['BodyText'], fontSize=10, leading=14, spaceAfter=8))
    story = []

    def p(content, style='BodySmall'):
        story.append(Paragraph(content, styles[style]))

    def picture(name, width=532):
        path = EXPORT / name
        with PILImage.open(path) as image:
            height = width * image.height / image.width
        story.append(Image(str(path), width=width, height=height))
        story.append(Spacer(1, 8))

    p('Task 4-5: mounted-workcell evaluation', 'Title')
    p('V3 addendum / EE5112 Project 2 / 9 November 2026', 'Heading2')
    p('A third scene tests the existing V2 planner with a physical mounting arrangement, '
      'an explicit table and a new endpoint pair. The fixed pedestal raises the UR5 base '
      '0.20 m above the table. A central rack, two equipment boxes and a rear guard obstruct the transfer.')
    picture('initial_and_planned.png')
    p('The straight joint-space initialization collides at 92/181 checked states. '
      'Task 4 and Task 5 share this initialization. The geometric feasibility witness '
      'is separate from every optimizer initialization and restart.')
    p('Mounting and collision scope', 'Heading2')
    p('The table top is world z=0. The only permitted world contact is the fixed '
      'pedestal/table pair. No UR5 link or tool is exempt. The pedestal participates '
      'in actual self-collision checks and the optimization self proxy; every original '
      'UR5 sphere still requires 35 mm conservative world clearance.')
    p('New endpoints (rad): start [-1.10, -1.05, 1.35, -0.30, -pi/2, 0]; '
      'goal [1.05, -0.75, 1.10, -0.35, -pi/2, 0]. Both endpoints are upright and pass collision checks.')
    p('The saved scene box array drives the voxel field, actual collision objects and rendering. '
      'The sub-table forbidden volume covers the full voxel workspace below z=0.')

    story.append(PageBreak())
    p('Reserved-seed formal results', 'Title')
    p('Development seeds 5300-5302 pass 6/6 and select the first profile. Formal '
      'seeds 5400-5419 are reserved until freezing: 20 seeds x 2 conditions = 40 runs. '
      'All runs enter the denominator. There are no failed formal runs in this study.')
    entries = [[Paragraph(escape(str(x)).replace('\n', '<br/>'), styles['BodySmall']) for x in row]
               for row in table_rows(data)]
    table = Table(entries, colWidths=[73, 56, 98, 100, 101, 104], repeatRows=1)
    table.setStyle(TableStyle([('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#edf2f6')),
                              ('VALIGN', (0, 0), (-1, -1), 'TOP'),
                              ('LINEBELOW', (0, 0), (-1, 0), .7, colors.grey),
                              ('BOTTOMPADDING', (0, 0), (-1, -1), 9)]))
    story.append(table)
    story.append(Spacer(1, 8))
    p('Tilt, gap and height are extrema over successful formal paths in the additional '
      '0.00625 rad verification. Planner time is the median of all 20 runs per condition '
      'and includes trace writes. Conditions share the same two-worker execution setup.')
    p('Constraint and acceptance', 'Heading2')
    p('Both groups use the V2 self-collision penalty and in-loop actual mesh rejection. '
      'Task 5 adds J_ori = 1000 sum ||R(q)e_y - e_z||_1 Delta s and the PoE direction '
      'projector. The tool y axis follows world +z while yaw remains free. Feasible '
      'candidates take priority over infeasible lower-cost candidates.')
    p('Both groups preserve exact endpoints and joint limits, require 35 mm proxy '
      'clearance, zero unpermitted world/self collisions and tool above the table. '
      'Task 5 also requires maximum tilt &lt;=5 degrees. Final validation uses '
      '0.0125 rad joint increments; every successful formal path also passes 0.00625 rad.')
    p('Common successful pairs', 'Heading2')
    pair = data['pairs']
    p(f"n={pair['n']}; median paired planner time (Task 5 minus Task 4) "
      f"{pair['pairedTimeDifference']['median']:.2f} s. Different weighted objective totals "
      'are not used as a quality comparison.')
    p(f"For 20/20 successes, the exact two-sided 95% binomial lower bound is "
      f"{100*.025**(1/20):.2f}% assuming independent Bernoulli trials in this fixed scene. "
      'This does not establish general reliability, and paired conditions are not pooled.')
    p('Member C adds the workcell, mount/contact policy, table-height gate, formal '
      'paired study and evidence. The team PoE, sphere envelopes and STOMP stages '
      'are reused. V1/V2 records remain intact.')

    story.append(PageBreak())
    p('Evidence, scope and reproduction', 'Title')
    picture('paired_metrics.png', 470)
    p('Demonstration seed 5300. Blue: Task 4; green: Task 5. The table and '
      'orientation gates are shown against normalized path progress. Each objective '
      'curve is divided by its own initial value. Progress is not execution time.')
    p(f"The independent audit recreates the mounted model and checks all 40 formal paths, "
      f"including {data['audit']['replayedCheckpoints']} optimizer checkpoint replays. "
      f"The two demonstrations add {data['demoAudit']['replayedCheckpoints']} replayed checkpoints. "
      'A separate NumPy FK cross-check also matches all 46,798 fine states '
      '(position difference &lt;2e-15 m); actual collision checks remain in MATLAB.')
    p('V2 had no floor: 7/20 projected formal paths placed the tool below base z=0. '
      'V3 addresses that modeling limitation. Changed endpoints and seeds prevent '
      'causal cross-version performance claims. Checks remain discrete; payload '
      'geometry, dynamics and real robot execution are outside this study.')
    p("MATLAB replay: addpath('scripts'); show_project_demo('all','v3'). "
      'Fresh planning: run_task45_v3(...); independent verification: verify_task45_v3(runRoot). '
      'See README_TASK45_V3.md and docs/TASK45_V3_RESULTS.md for configuration and archive scope.')

    def footer(canvas, doc):
        canvas.setFont('Helvetica', 8)
        canvas.setFillColor(colors.grey)
        canvas.drawString(40, 24, 'EE5112 Project 2 / V3 mounted-workcell study / discrete validation')
        canvas.drawRightString(572, 24, str(doc.page))

    SimpleDocTemplate(str(OUT / 'task45_v3_report.pdf'), pagesize=(612, 792),
                      leftMargin=40, rightMargin=40, topMargin=32, bottomMargin=40
                      ).build(story, onFirstPage=footer, onLaterPages=footer)


def slides(data):
    import win32com.client
    from PIL import Image
    target = OUT / 'task45_v3_slides.pptx'
    assert not target.exists(), 'Refuse to overwrite an existing V3 deck.'
    app = win32com.client.DispatchEx('PowerPoint.Application')
    deck = app.Presentations.Add(False)
    deck.PageSetup.SlideWidth = 960
    deck.PageSetup.SlideHeight = 540
    navy = 0x4F3216
    notes = []

    def text(z, content, x, y, w, h, size=21, bold=False, color=navy):
        shape = z.Shapes.AddTextbox(1, x, y, w, h)
        frame = shape.TextFrame
        frame.MarginLeft = frame.MarginRight = frame.MarginTop = frame.MarginBottom = 0
        frame.WordWrap = True
        tr = frame.TextRange
        tr.Text = content
        tr.Font.Name = 'Arial'
        tr.Font.Size = size
        tr.Font.Bold = bold
        tr.Font.Color.RGB = color
        return shape

    def slide(title):
        z = deck.Slides.Add(deck.Slides.Count + 1, 12)
        z.Background.Fill.ForeColor.RGB = 0xFFFFFF
        text(z, title, 40, 25, 880, 65, 32, True)
        return z

    def pic(z, name, x, y, w):
        path = EXPORT / name
        with Image.open(path) as im:
            h = w * im.height / im.width
        z.Shapes.AddPicture(str(path), False, True, x, y, w, h)

    def note(z, content, sources):
        notes.append(content)
        z.NotesPage.Shapes.Placeholders(2).TextFrame.TextRange.Text = content + '\n\nSources: ' + sources

    try:
        z = slide('UR5 transfer above a table')
        pic(z, 'initial_and_planned.png', 35, 110, 890)
        text(z, 'A fixed pedestal, table and five shared obstacle volumes', 40, 425, 880, 40)
        text(z, 'New upright endpoints; the common straight initialization collides at 92/181 states', 40, 480, 880, 40, 18)
        note(z, '这是额外的第三套场景，目的是解决原场景没有地面限制、部分工具轨迹低于基座的问题。'
             'UR5 通过 20 厘米高的固定底座安装在 z=0 的桌面，桌面及其下方是禁入空间。'
             '两组使用相同的新端点和关节直线初始化，直线有 92/181 个实际碰撞状态。'
             '证明几何可行性的参考路径没有进入优化器。',
             'docs/TASK45_V3_PROTOCOL.md; geometry_probe.json; demos/exports/workcell/initial_and_planned.fig')

        z = slide('Upright orientation and collision acceptance')
        text(z, 'Task 4: self-aware STOMP\nTask 5: same planner + orientation penalty and PoE projection', 40, 110, 880, 85, 25, True)
        text(z, 'Tool y follows world +z; yaw remains free\nOrientation weight 1000; maximum accepted tilt 5 degrees', 40, 235, 880, 75)
        text(z, 'Both: exact endpoints, limits, 35 mm proxy gap,\nzero unpermitted world collisions and zero self collisions', 40, 345, 880, 65)
        text(z, 'Only the fixed pedestal may contact the table. Every UR5 link and tool is checked.', 40, 465, 880, 50, 19)
        note(z, '这里保留 V2 的自碰撞罚项和候选实际网格筛选。Task 5 增加方向罚项和投影，'
             '工具 y 轴对齐世界正 z，偏航自由。最终姿态门槛仍是 5 度，碰撞保守间距仍是 35 毫米。'
             '唯一的接触例外是固定底座与桌面；不能把运动连杆或工具排除出碰撞检查。'
             '全部成功正式路径还通过了 0.00625 rad 的额外离散加密复核。',
             'upgrades/task45_v3/matlab/+memberC/validatePath.m; +memberB/checkMatlabPath.m; fine_validation.json')

        z = slide('Reserved-seed workcell results')
        rows = table_rows(data)
        shape = z.Shapes.AddTable(len(rows), 6, 40, 125, 880, 190)
        for j, width in enumerate([110, 90, 160, 160, 170, 190], 1):
            shape.Table.Columns(j).Width = width
        for i, row in enumerate(rows, 1):
            for j, value in enumerate(row, 1):
                cell = shape.Table.Cell(i, j).Shape
                cell.TextFrame.MarginLeft = cell.TextFrame.MarginRight = 8
                tr = cell.TextFrame.TextRange
                tr.Text = value
                tr.Font.Name = 'Arial'
                tr.Font.Size = 18
                tr.Font.Bold = i == 1
                tr.Font.Color.RGB = navy
                cell.Fill.Solid()
                cell.Fill.ForeColor.RGB = 0xF3F3F3 if i % 2 == 0 else 0xFFFFFF
        text(z, '20 held-out seeds, 40 runs, 20 common successful pairs\nExtrema use the additional 0.00625 rad check', 40, 360, 880, 75)
        text(z, 'Fixed scene and finite seeds; this is not a general reliability guarantee', 40, 480, 880, 35, 18)
        note(z, '正式种子为 5400 到 5419，开发只使用 5300 到 5302。'
             '没有根据正式结果再调参。两组各 20 次，所有正式运行进入统计。'
             '表中的倾角、间距和工具高度是额外加密检查中所有成功路径的最坏值；耗时是全部运行的中位数。'
             '20/20 只说明这套场景和这批种子的表现，不能说任何障碍场景都可靠。'
             '两进程共享机器，耗时只作本执行方式下的描述。',
             'formal/all_runs.csv; formal/study_summary.json; fine_validation.json; formal_audit.json')

        z = slide('Paired demonstration and study limits')
        pic(z, 'paired_metrics.png', 30, 115, 570)
        b = data['groups'][5]
        text(z, f"Task 5 worst formal tilt\n{b['worstTilt']:.3f} degrees\n\nAll formal tools stay\nabove the table", 635, 125, 285, 185, 22)
        text(z, 'Discrete checks\nNo payload or dynamics\nProgress is not execution time', 635, 365, 285, 110, 20)
        note(z, '左图演示种子是开发阶段确定的 5300，蓝色为 Task 4，绿色为 Task 5。'
             '方向误差、距桌面高度和保守间距可按路径进度对照；不同总代价不直接比较。'
             '这项优化补上了安装与桌面约束，但没有增加杯子或载荷几何，也不包含动力学和实机执行。'
             '我们复用队友的 PoE、球包络和 STOMP 阶段，新增场景、底座接触规则、桌面验收及独立证据。'
             '原 V1 和 V2 的结果继续保留。',
             'demos/exports/workcell/paired_metrics.fig; docs/TASK45_V3_RESULTS.md; formal_audit.json')
        assert deck.Slides.Count == 4
        deck.SaveAs(str(target), 24)
        deck.SaveAs(str(OUT / 'task45_v3_slides.pdf'), 32)
        (OUT / 'task45_v3_speaker_notes_zh.md').write_text(
            '\n\n'.join(f'## Slide {i}\n\n{n}' for i, n in enumerate(notes, 1)), encoding='utf-8')
        deck.Close()
        deck = None
        check = app.Presentations.Open(str(target), True, False, False)
        assert check.Slides.Count == 4
        check.Close()
    finally:
        if deck is not None:
            deck.Close()
        if app.Presentations.Count == 0:
            app.Quit()


def main():
    data = collect()
    OUT.mkdir(exist_ok=True)
    write_markdown(data)
    report(data)
    slides(data)
    (OUT / 'delivery_numbers.json').write_text(json.dumps(
        {'groups': data['groups'], 'formalReplays': data['audit']['replayedCheckpoints'],
         'demoReplays': data['demoAudit']['replayedCheckpoints'], 'fineJointStep': .00625},
        indent=2) + '\n', encoding='utf-8')
    print('Created V3 report, four editable slides and Chinese notes:', OUT)


if __name__ == '__main__':
    main()
