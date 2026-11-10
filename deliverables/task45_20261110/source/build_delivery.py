"""Build an evidence-based course presentation without editing frozen releases.

PowerPoint COM is the user-authorized fallback for unavailable artifact-tool.
Figures are original scientific evidence. Tables/charts/text remain native.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import html
import json
import re
import shutil
import subprocess
from pathlib import Path
from statistics import median

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parents[1]
PRIVATE = ROOT / 'artifacts/local_runs/task45_presentation_20261110'
V3 = ROOT / 'artifacts/runs/task45_v3'
V4 = ROOT / 'artifacts/runs/task45_v4'
V5 = ROOT / 'artifacts/runs/task45_v5'
EXPORT = V3 / 'demos/exports/workcell'
BLUE = (24, 100, 184)
GREEN = (0, 143, 93)
NAVY = (22, 45, 73)
GRAY = (82, 96, 111)
RED = (181, 52, 44)


def read(p):
    return json.loads(p.read_text(encoding='utf-8-sig'))


def write_json(p, data):
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def rgb(c):
    return c[0] + 256*c[1] + 65536*c[2]


def collect():
    fine = read(V3/'fine_validation.json')
    rows3 = [read(p) for p in sorted((V3/'formal').glob('**/summary.json'))]
    rows5 = [read(p) for p in sorted((V5/'formal').glob('**/summary.json'))]
    assert len(rows3) == 40 and all(r['success'] for r in rows3)
    assert len(rows5) == 75 and sum(r['success'] for r in rows5) == 71
    assert fine['passed'] and read(V5/'formal_audit.json')['passed']
    g3 = {}
    for task in [4, 5]:
        r = [x for x in rows3 if x['task'] == task]
        f = [x for x in fine['details'] if x['task'] == task]
        g3[str(task)] = dict(n=len(r), successes=sum(x['success'] for x in r),
            medianTime=median(x['plannerSeconds'] for x in r),
            worstTilt=max(x['maxOrientationDeg'] for x in f),
            minGap=min(x['minVoxelClearance'] for x in f)*1000,
            minHeight=min(x['minToolHeight'] for x in f)*1000)
    arms = ['ambient','energy_control','fixed50','fixed75','adaptive']
    g5 = []
    for arm in arms:
        r = [x for x in rows5 if x['variant'] == arm]
        g5.append(dict(arm=arm, n=len(r), successes=sum(x['success'] for x in r),
            medianTime=median(x['plannerSeconds'] for x in r),
            medianQ=median(x['finalQuality'] for x in r if x['success']),
            byScene={s:sum(x['success'] for x in r if x['scenario']==s) for s in ['workcell','endpoints','layout']}))
    failed = [dict(scenario=r['scenario'],arm=r['variant'],seed=r['seed'],
        failures=r['failures'],gapMm=1000*r['minVoxelClearance'],tilt=r['maxOrientationDeg'],
        seconds=r['plannerSeconds']) for r in rows5 if not r['success']]
    assert all(f['failures'] == ['proxy_margin'] and f['tilt'] < 1 for f in failed)
    result = dict(baseCommit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        v3=g3,v5=g5,failures=failed,
        v3FormalReplay=read(V3/'formal_audit.json')['replayedCheckpoints'],
        v5FormalReplay=read(V5/'study_summary.json')['replayedCheckpoints'])
    (OUT/'evidence').mkdir(exist_ok=True)
    write_json(OUT/'evidence/numbers.json',result)
    return result


def assets():
    import cv2
    import imageio_ffmpeg
    sources=[]
    for folder in ['media','evidence']:
        (OUT/folder).mkdir(exist_ok=True)
    for name in ['initial_and_planned.png','paired_metrics.png','paired_metrics.fig','initial_and_planned.fig']:
        src=EXPORT/name; dst=OUT/'evidence'/name
        shutil.copy2(src,dst)
        sources.append(dict(source=str(src.relative_to(ROOT)),output=str(dst.relative_to(OUT)),sha256=sha(src)))
    for release, names in [(V3,['formal/study_summary.json','fine_validation.json']),
                           (V4,['study_summary.json']), (V5,['study_summary.json'])]:
        for name in names:
            src=release/name; dst=OUT/'evidence'/f'{release.name}_{Path(name).name}'
            shutil.copy2(src,dst)
            sources.append(dict(source=str(src.relative_to(ROOT)),output=str(dst.relative_to(OUT)),sha256=sha(src)))
    for task in [4,5]:
        src=V3/f'demos/workcell/Task{task}/seed_5300/dense_validation.csv'
        dst=OUT/'evidence'/f'task{task}_demo_dense.csv'
        shutil.copy2(src,dst)
        sources.append(dict(source=str(src.relative_to(ROOT)),output=str(dst.relative_to(OUT)),sha256=sha(src)))
    ffmpeg=imageio_ffmpeg.get_ffmpeg_exe()
    video_receipts=[]
    for stem in ['task4_motion','task5_motion','paired_motion']:
        src=EXPORT/f'{stem}.avi'; dst=OUT/'media'/f'{stem}.mp4'
        if not dst.exists():
            subprocess.run([ffmpeg,'-hide_banner','-loglevel','error','-n','-i',str(src),
                '-map','0:v:0','-an','-vf','pad=ceil(iw/2)*2:ceil(ih/2)*2',
                '-c:v','libx264','-preset','medium','-crf','18','-pix_fmt','yuv420p',
                '-movflags','+faststart',str(dst)],check=True)
        cap=cv2.VideoCapture(str(dst)); frames=[]; count=0
        fps=cap.get(cv2.CAP_PROP_FPS)
        width=int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)); height=int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        while True:
            ok,frame=cap.read()
            if not ok: break
            count+=1
            if count in [1,75,150]:
                assert frame.var()>1
                path=PRIVATE/f'{stem}_{count:03d}.png'
                cv2.imwrite(str(path),frame)
                frames.append(str(path))
                if count==75:
                    # Unaltered experiment frame for the native video poster.
                    cv2.imwrite(str(OUT/'evidence'/f'{stem}_poster.png'),frame)
        cap.release()
        assert count==150 and abs(fps-15)<1e-8,(stem,count,fps)
        video_receipts.append(dict(name=stem,frames=count,fps=fps,width=width,height=height,
            seconds=count/fps,sha256=sha(dst),sourceSha256=sha(src),allFramesDecoded=True))
        sources.append(dict(source=str(src.relative_to(ROOT)),output=str(dst.relative_to(OUT)),
            sha256=sha(src),conversion='H.264 CRF18; yuv420p; pad one bottom row; original 150 frames at 15 fps'))
    write_json(OUT/'evidence/source_assets.json',sources)
    write_json(PRIVATE/'video_qa.json',dict(passed=True,videos=video_receipts))


def pdf_manuscripts():
    from reportlab.lib import colors
    from reportlab.lib.enums import TA_LEFT
    from reportlab.lib.styles import ParagraphStyle
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.cidfonts import UnicodeCIDFont
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, KeepTogether
    # Standard CJK CID font is searchable and avoids rasterizing the manuscript.
    pdfmetrics.registerFont(UnicodeCIDFont('STSong-Light'))
    for stem in ['speaker_script_zh_en','project_understanding_zh','task45_report_section_en']:
        zh=stem!='task45_report_section_en'
        font='STSong-Light' if zh else 'Helvetica'
        body=ParagraphStyle('body',fontName=font,fontSize=10.5 if zh else 10,
            leading=17 if zh else 14,spaceAfter=7,wordWrap='CJK' if zh else None,
            textColor=colors.HexColor('#253c50'),alignment=TA_LEFT)
        styles={0:body}
        for level,size,leading in [(1,21,28),(2,15,22),(3,12,18)]:
            styles[level]=ParagraphStyle(f'h{level}',parent=body,fontSize=size,leading=leading,
                spaceBefore=13 if level>1 else 0,spaceAfter=10,keepWithNext=True,
                textColor=colors.HexColor('#16314f'))
        story=[];lines=(OUT/f'{stem}.md').read_text(encoding='utf-8').splitlines();i=0
        def clean(s):
            s=s.translate({0x2011:45,0x2013:45,0x2014:45,0x2212:45})
            s=html.escape(s)
            s=re.sub(r'\*\*(.+?)\*\*',r'<b>\1</b>',s)
            s=re.sub(r'`([^`]+)`',r'\1',s)
            return s
        while i<len(lines):
            line=lines[i].strip()
            if not line: i+=1;continue
            if line.startswith('```'):
                code=[];i+=1
                while i<len(lines) and not lines[i].startswith('```'):
                    code.append(lines[i]);i+=1
                # Use paragraph line breaks for portable CJK/code rendering.
                st=ParagraphStyle('code',parent=body,fontSize=9,leading=13,
                    backColor=colors.HexColor('#f2f5f7'),leftIndent=9,rightIndent=9,
                    borderPadding=6,spaceBefore=3,spaceAfter=9)
                for row in code:
                    story.append(Paragraph(clean(row).replace(' ','&#160;'),st))
                i+=1;continue
            if line.startswith('|'):
                rows=[]
                while i<len(lines) and lines[i].strip().startswith('|'):
                    cells=[x.strip() for x in lines[i].strip().strip('|').split('|')]
                    if not all(re.fullmatch(r'[:\- ]+',x) for x in cells): rows.append(cells)
                    i+=1
                n=len(rows[0]);width=491/n
                small=ParagraphStyle('table',parent=body,fontSize=8.5,leading=12,spaceAfter=0)
                data=[[Paragraph(clean(x),small) for x in r] for r in rows]
                t=Table(data,colWidths=[width]*n,repeatRows=1,hAlign='LEFT')
                t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),colors.HexColor('#e9eff5')),
                    ('VALIGN',(0,0),(-1,-1),'TOP'),('TOPPADDING',(0,0),(-1,-1),7),
                    ('BOTTOMPADDING',(0,0),(-1,-1),7),('LINEBELOW',(0,0),(-1,0),.5,colors.HexColor('#a9b6c3')),
                    ('LINEBELOW',(0,1),(-1,-1),.25,colors.HexColor('#d8dfe5'))]))
                story.append(KeepTogether([t,Spacer(1,9)]));continue
            m=re.match(r'^(#{1,3})\s+(.+)',line)
            if m: story.append(Paragraph(clean(m.group(2)),styles[len(m.group(1))]));i+=1;continue
            if re.fullmatch(r'\*\*[^*]+\*\*',line):
                label=ParagraphStyle('label',parent=body,keepWithNext=True)
                story.append(Paragraph(clean(line),label));i+=1;continue
            story.append(Paragraph(clean(line),body));i+=1
        def footer(canvas,doc):
            canvas.saveState();canvas.setFont('Helvetica',8);canvas.setFillColor(colors.HexColor('#68798b'))
            canvas.drawString(52,28,'EE5112 Project 2 / Task 4-5 / 10 Nov 2026')
            canvas.drawRightString(543,28,str(doc.page));canvas.restoreState()
        doc=SimpleDocTemplate(str(OUT/f'{stem}.pdf'),pagesize=(595.276,841.89),
            rightMargin=52,leftMargin=52,topMargin=48,bottomMargin=48,
            title=lines[0].lstrip('# '),author='EE5112 Project 2')
        doc.build(story,onFirstPage=footer,onLaterPages=footer)


class Deck:
    def __init__(self,app):
        self.app=app;self.p=app.Presentations.Add(False)
        self.p.PageSetup.SlideWidth=960;self.p.PageSetup.SlideHeight=540
        self.notes=[];self.geometry=[];self.media=[];self.charts=[]

    def text(self,s,content,x,y,w,h,size=23,bold=False,color=NAVY,name=None):
        shape=s.Shapes.AddTextbox(1,x,y,w,h)
        if name:shape.Name=name
        f=shape.TextFrame;f.MarginLeft=f.MarginRight=f.MarginTop=f.MarginBottom=0
        f.WordWrap=True
        tr=f.TextRange;tr.Text=content;tr.Font.Name='Arial';tr.Font.NameFarEast='Microsoft YaHei'
        tr.Font.Size=size;tr.Font.Bold=-1 if bold else 0;tr.Font.Color.RGB=rgb(color)
        tr.ParagraphFormat.SpaceAfter=8
        return shape

    def slide(self,title):
        s=self.p.Slides.Add(self.p.Slides.Count+1,12)
        s.FollowMasterBackground=False;s.Background.Fill.ForeColor.RGB=rgb((255,255,255))
        self.text(s,title,40,28,880,65,32,True,name='slide_title')
        page=self.text(s,str(s.SlideIndex),880,505,40,25,12,color=GRAY)
        page.TextFrame.WordWrap=False
        return s

    def note(self,s,zh,source):
        s.NotesPage.Shapes.Placeholders(2).TextFrame.TextRange.Text=zh+'\n\nSources: '+source
        self.notes.append(dict(slide=s.SlideIndex,title=s.Shapes.Item('slide_title').TextFrame.TextRange.Text,
            chinese=zh,source=source))

    def picture(self,s,path,x,y,w,h):
        from PIL import Image
        with Image.open(path) as im: iw,ih=im.size
        scale=min(w/iw,h/ih);ww=iw*scale;hh=ih*scale
        return s.Shapes.AddPicture(str(path),False,True,x+(w-ww)/2,y+(h-hh)/2,ww,hh)

    def video(self,s,stem,x,y,w,h):
        import cv2
        path=OUT/'media'/f'{stem}.mp4';cap=cv2.VideoCapture(str(path))
        iw=cap.get(3);ih=cap.get(4);cap.release()
        scale=min(w/iw,h/ih);ww=iw*scale;hh=ih*scale
        sh=s.Shapes.AddMediaObject2(str(path),False,True,x+(w-ww)/2,y+(h-hh)/2,ww,hh)
        sh.Name=f'embedded_{stem}'
        sh.MediaFormat.SetDisplayPictureFromFile(str(OUT/'evidence'/f'{stem}_poster.png'))
        sh.AnimationSettings.PlaySettings.PlayOnEntry=False
        sh.AnimationSettings.PlaySettings.HideWhileNotPlaying=False
        sh.AnimationSettings.PlaySettings.RewindMovie=True
        self.media.append(dict(slide=s.SlideIndex,shapeId=sh.Id,stem=stem,lengthMs=sh.MediaFormat.Length))
        return sh

    def table(self,s,rows,x,y,w,h,widths=None,size=20):
        sh=s.Shapes.AddTable(len(rows),len(rows[0]),x,y,w,h);t=sh.Table
        if widths:
            for j,weight in enumerate(widths,1):t.Columns(j).Width=w*weight/sum(widths)
        for i,row in enumerate(rows,1):
            for j,val in enumerate(row,1):
                cell=t.Cell(i,j);tr=cell.Shape.TextFrame.TextRange;tr.Text=str(val)
                tr.Font.Name='Arial';tr.Font.Size=size;tr.Font.Color.RGB=rgb(NAVY)
                tr.Font.Bold=-1 if i==1 else 0
                cell.Shape.TextFrame.MarginLeft=9;cell.Shape.TextFrame.MarginRight=7
                cell.Shape.TextFrame.MarginTop=8;cell.Shape.TextFrame.MarginBottom=5
                cell.Shape.Fill.ForeColor.RGB=rgb((234,240,246) if i==1 else (255,255,255))
                for border in [1,2,3,4]:cell.Borders.Item(border).ForeColor.RGB=rgb((214,222,230))
        return sh

    def curve(self,s,column,title,ytitle,x,y,w,h):
        # Native Office chart and workbook are inserted after COM has closed the draft.
        sh=self.text(s,'',x,y,w,h,18,name='native_chart_'+column)
        self.charts.append(dict(slide=s.SlideIndex,shapeId=sh.Id,column=column,title=title,
            ytitle=ytitle,x=x,y=y,w=w,h=h))
        return sh


def build_slides(numbers):
    import win32com.client
    app=win32com.client.DispatchEx('PowerPoint.Application');deck=Deck(app);d=deck
    english=(OUT/'speaker_script_zh_en.md').read_text(encoding='utf-8')
    main_notes=re.findall(r'\*\*English script\*\*\s+(.+?)(?=\n\n\*\*)',english,re.S)
    try:
        s=d.slide('Task 4: a mounted UR5 workcell')
        d.picture(s,OUT/'evidence/initial_and_planned.png',32,115,896,280)
        d.text(s,'92 / 181',42,422,220,55,40,True,color=RED)
        d.text(s,'initial states collide\nSame endpoints and straight initialization for both tasks',285,417,625,72,22)
        d.note(s,'主讲约35秒。'+main_notes[0]+'\n中文：展示非平凡初值。五个环境体积包括桌面；安装底座属于机器人模型。参考路径仅用于可行性证明。',
            'docs/TASK45_V3_RESULTS.md; artifacts/runs/task45_v3/geometry_probe.json; demos/exports/workcell/initial_and_planned.fig')

        s=d.slide('Task 5: upright tool direction')
        d.text(s,'Tool y aligns with world +z\nYaw remains free',40,118,450,72,25,True,color=GREEN)
        d.text(s,'Direction penalty, lambda = 1000\nDamped Jacobian projection\nSelf-collision cost and rejection',40,228,450,135,23)
        d.text(s,'Maximum accepted tilt: 5 degrees\nConservative clearance: 35 mm',40,395,480,70,22)
        d.video(s,'task5_motion',540,108,370,370)
        d.text(s,'Click video to play / 10 s',558,481,345,25,16,color=GRAY)
        d.note(s,'主讲约45秒，包含10秒视频。'+main_notes[1]+'\n中文：单击视频。投影不保证碰撞可行，端点、限位、世界和自碰撞仍需独立验收。5度和35毫米为自定标准。',
            'upgrades/task45_v3/matlab/+memberC/projectTrajectory.m; directionJacobian.m; validatePath.m; V3 demo Task5 seed5300')

        s=d.slide('Same problem, different tool orientation')
        d.video(s,'paired_motion',40,104,880,348)
        d.text(s,'Demo maximum tilt: 120.29 degrees (Task 4) / 0.930 degrees (Task 5)',40,468,880,30,21,True)
        d.text(s,'Seed 5300. Normalized path progress, without an execution-time model.',40,506,840,20,15,color=GRAY)
        d.note(s,'主讲约35秒，包含10秒视频。'+main_notes[2]+'\n中文：演示种子5300在开发阶段确定。这里的最大角不是正式样本最坏值。两边的播放进度同步不代表机器人执行速度。',
            'artifacts/runs/task45_v3/demos/workcell/Task4/seed_5300/summary.json; Task5/seed_5300/summary.json; paired_motion.avi')

        s=d.slide('Held-out results and contribution')
        rows=[['Condition','Success','Median time\n(s)','Worst tilt\n(deg)','Min proxy gap\n(mm)']]
        for task in [4,5]:
            g=numbers['v3'][str(task)]
            rows.append([f'Task {task}',f"{g['successes']}/{g['n']}",f"{g['medianTime']:.2f}",f"{g['worstTilt']:.3f}",f"{g['minGap']:.2f}"])
        d.table(s,rows,40,120,880,175,[1.0,.8,1,1,1.2],20)
        d.text(s,'20 paired seeds. Every successful path also passes the 0.00625 rad check.',40,322,880,55,21,True)
        d.text(s,'My contribution: scene, upright projection, self-collision handling,\npaired experiments and independent verification.',40,397,880,65,22)
        d.text(s,'V4/V5 extensions in backup slides. Discrete geometry checks; no payload dynamics.',40,483,850,33,16,color=GRAY)
        d.note(s,'主讲约45秒。'+main_notes[3]+'\n中文：正式种子5400–5419，开发5300–5302。时间包含写盘，双进程共享机器。Q只在相同定义内比较。额外加密极值用于本表。',
            'V3 formal/study_summary.json; fine_validation.json; formal_audit.json; docs/TASK45_V3_RESULTS.md')

        s=d.slide('Project overview: Tasks 1 to 5')
        rows=[['Task','What changes','Evidence'],['1','Complete KINOVA STOMP','Original scene, collision-free animation'],
            ['2','Replace KINOVA with UR5','UR5 planning under the same framework'],
            ['3','Replace planning FK with PoE','All-body accuracy and timing comparison'],
            ['4','Design a harder UR5 workcell','Colliding initialization and planned route'],
            ['5','Keep the tool direction upright','Same-problem constrained comparison']]
        d.table(s,rows,40,110,880,318,[.45,1.45,1.8],18)
        d.text(s,'Reuse the team baseline. Member C adds Tasks 4–5 and the later ablations.',40,459,880,48,21,True)
        d.note(s,'备份。五项任务的递进关系：功能补全、换机器人、换FK、换复杂场景、加方向约束。具体三人姓名按组内确认填写，不能从函数名推断所有贡献归属。',
            '../EE5112_Project-2_AY26-27.pdf pp.1–2; docs/HANDOFF_MEMBER_C.md; docs/METHODS.md')

        s=d.slide('STOMP iteration in this implementation')
        rows=[['Stage','Operation','Relevant function'],['Sample','Correlated, antithetic perturbations','stompSamples'],
            ['Evaluate','World / self / direction / smoothness','stompTrajCost'],
            ['Weight','Lower local cost gets higher probability','stompUpdateProb'],
            ['Update','Weighted actual noise, then smoothing','stompDTheta / stompUpdateTheta'],
            ['Accept','Limits, projection and feasibility gates','memberC.plan / validatePath']]
        d.table(s,rows,40,108,880,323,[.7,1.7,1.4],18)
        d.text(s,'Optimize internal waypoints. Keep the endpoints fixed. No global-optimality guarantee.',40,457,880,55,20,True)
        d.note(s,'备份。先解释Θ为6×61。采样具有路点相关性，概率逐路点归一化，限位/投影后重新计算实际扰动。候选比验收通过还差一步，不能只凭总代价下降声明成功。',
            'matlab/stompSamples.m; stompUpdateProb.m; stompDTheta.m; stompUpdateTheta.m; upgrades/task45_v3/matlab/+memberC/plan.m')

        s=d.slide('PoE forward kinematics')
        d.text(s,'S = [a; -a cross p]\nT(q) = exp([S1]q1) ... exp([Sn]qn) M',40,115,880,98,28,True)
        rows=[['Check','Saved Task 3 baseline'],['All-body position error','6.65e-16 m over 200 configurations'],
            ['Task 2 vs Task 3 path difference','0 rad in the fixed-seed run'],
            ['Same all-body workload speed ratio','22.85x (original Linux machine)']]
        d.table(s,rows,40,250,880,180,[1.3,1.9],19)
        d.text(s,'Cache screws and prefixes once. Timing depends on machine and workload.',40,463,880,45,21)
        d.note(s,'备份。a与p必须统一到空间坐标；q=0的M不同于非零home。固定body不占活动关节变量。原机器22.85倍，本机Windows27.22倍，不能混用。规划代价PoE链不含getTransform，但独立验证/显示可使用MATLAB模型。',
            'docs/METHODS.md; docs/VALIDATION.md; artifacts/runs/final_r2023b/Task3/fk_accuracy.csv; fk_benchmark.csv')

        s=d.slide('Direction constraint and projection')
        d.text(s,'y(q) = R(q) e_y\nTilt = acos(clamp(y(q).T e_z, -1, 1))',40,115,880,92,27,True)
        d.text(s,'J_y(:,i) = omega_i cross y\ndelta_q = J_y.T (J_y J_y.T + mu^2 I)^(-1) (e_z - y)',40,238,880,90,24)
        rows=[['Projection setting','Value'],['Damping / internal tolerance','0.001 / 1 degree'],
            ['Steps / component update cap','20 / 0.15 rad'],['Final dense tilt tolerance','5 degrees']]
        d.table(s,rows,40,340,880,145,[1.4,1.8],18)
        d.note(s,'备份。单方向通常为2个独立约束，yaw自由。反向时使用确定性正交修正。投影只改内部点，保持限位；失败候选不参与接受。投影后的路径仍需世界/自碰撞检查。',
            'upgrades/task45_v3/matlab/+memberC/directionJacobian.m; projectTrajectory.m; validatePath.m')

        s=d.slide('What changed across the iterations')
        rows=[['Version','Main change','Observed result'],['V1','Penalty + direction projection','Projected Task 5: 0/20, self collisions'],
            ['V2','Self-collision handling, feasible incumbent','Task 5: 20/20 across two cases'],
            ['V3','Mounted table workcell','Task 4 and Task 5: 20/20 each'],
            ['V4','Feasible refinement + tangent sampling','Four arms: 10/10 each'],
            ['V5','Energy control + adaptive ablation','71/75, four margin failures']]
        d.table(s,rows,40,112,880,320,[.5,1.65,1.8],18)
        d.text(s,'Different scenes and seeds prevent causal cross-version speed claims.',40,461,880,45,21,True)
        d.note(s,'备份。V1不是姿态失败而是自碰撞。V3补足桌面与安装合理性。V4/V5的baseline与ambient本身已是Task5约束组。旧版本和失败继续保留。',
            'docs/TASK5_V1_FAILURE_ANALYSIS.md; docs/TASK45_V2_RESULTS.md; TASK45_V3_RESULTS.md; TASK45_V4_RESULTS.md; TASK45_V5_RESULTS.md')

        s=d.slide('V4: refinement and tangent sampling')
        rows=[['Task 5 arm','Success','Median time (s)','Median final Q'],['baseline','10/10','49.96','10.15'],
            ['anytime','10/10','94.94','9.88'],['tangent','10/10','39.88','9.76'],['combined','10/10','89.12','9.39']]
        d.table(s,rows,40,110,880,245,[1.2,.8,1.1,1.1],20)
        d.text(s,'Combined vs baseline: median paired Q reduction 15.36% (n=10)\n7 wins, 3 losses. Median paired extra time: 37.77 s.',40,383,880,75,22,True)
        d.text(s,'Q = joint length + 5 x smoothness + soft 45 mm clearance preference',40,486,880,29,17,color=GRAY)
        d.note(s,'备份。四组都是Task5。anytime只优化自己的可行incumbent，Q严格下降且每次通过验收。75%切空间+25%普通采样仍经过非线性投影。15.36%为十个配对比例中位数，不是两组中位数相除。',
            'docs/TASK45_V4_RESULTS.md; artifacts/runs/task45_v4/study_summary.json; upgrades/task45_v4/matlab/+memberC/qualityCost.m')

        s=d.slide('V5: three cases, five sampling strategies')
        rows=[['Task 5 arm','Workcell','Endpoints','Layout','Time (s)','Final Q']]
        for g in numbers['v5']:
            rows.append([g['arm'],*[f"{g['byScene'][case]}/5" for case in ['workcell','endpoints','layout']],
                f"{g['medianTime']:.2f}",f"{g['medianQ']:.2f}"])
        d.table(s,rows,40,114,880,276,[1.55,1,1,1,1,1],18)
        d.text(s,'Fixed75: 15/15. Adaptive: 13/15. Keep adaptive experimental.',40,416,880,38,24,True)
        d.text(s,'Time uses all runs. Q uses successes. Adaptive vs fixed75: 4.60% paired Q reduction, n=13.',40,476,880,44,17,color=GRAY)
        d.note(s,'备份。冻结后5800–5804，每场景每组5次。Q只对共同成功配对比较。adaptive与fixed50的对照才隔离反馈，二者refinement都固定50%。n=5很小，不能确立普遍可靠性排名。',
            'docs/TASK45_V5_RESULTS.md; artifacts/runs/task45_v5/study_summary.json; formal/**/summary.json')

        s=d.slide('Four V5 failures miss the clearance gate')
        rows=[['Case / arm / seed','Proxy gap (mm)','Tilt (deg)'],
            ['workcell / ambient / 5800','30.13','0.152'],['workcell / adaptive / 5801','30.42','0.511'],
            ['endpoints / fixed50 / 5800','34.22','0.083'],['endpoints / adaptive / 5801','33.53','0.858']]
        d.table(s,rows,40,110,880,235,[2.2,1,1],19)
        d.text(s,'Required conservative gap: 35 mm. All four tilts are below 1 degree.',40,372,880,47,22,True,color=RED)
        d.text(s,'Soft-cost feedback can disagree with dense feasibility.\nThis is a plausible mechanism, without causal proof from these runs.',40,441,880,65,21)
        d.note(s,'备份。直接失败分类均proxy_margin，与V1的self_collision不同。有限预算/局部非凸搜索是机制背景，不能声称控制器震荡已被证明导致失败，也不能把保守余量失败直接说成实际撞障碍。',
            'docs/TASK45_V5_RESULTS.md; V5 formalFailures; formal_audit.json')

        s=d.slide('Energy control isolates a sampling effect')
        rows=[['Sampler','Pre RMS (rad)','Post RMS (rad)','Corrections / point'],
            ['ambient','0.3761','0.3417','2.6578'],['energy control','0.3371','0.3051','2.3019'],
            ['fixed75','0.3371','0.3273','0.7119']]
        d.table(s,rows,40,115,880,202,[1.15,1,1,1.35],19)
        d.text(s,'Fixed75 vs control: median correction reduction 68.04%',40,351,880,45,25,True,color=GREEN)
        d.text(s,'Match scalar input norm before nonlinear projection.\n30 paired batches reuse five seeds over six central paths.\nFormal planning shows no consistent Q advantage over the energy control.',40,420,880,91,20)
        d.note(s,'备份。这不是等协方差/投影后等方差。最大标量能量差3.55e-14 rad²。修正步数少不自动等于整体规划更快或更优。正式fixed75相对energy_control配对Q中位数-0.31%，7胜8负。',
            'docs/TASK45_V5_METHODS_ZH.md; V5 sampling_ablation.json; sampling_ablation_audit.json; study_summary.json')

        s=d.slide('Demo profiles from the saved dense paths')
        d.curve(s,'orientation_deg','Tool tilt','Tilt (deg)',28,114,448,338)
        d.curve(s,'voxel_gap_m','Conservative clearance','Gap (mm)',483,114,448,338)
        d.text(s,'Development seed 5300. Native charts retain the full saved CSV data.',40,478,880,33,18,color=GRAY)
        d.note(s,'备份。这里是演示路径的nominal dense CSV，正式表使用额外fine check。原始数据完整保存在图表内嵌工作簿，横轴为归一化路径进度。红线分别为5度/35毫米门槛。',
            'artifacts/runs/task45_v3/demos/workcell/Task4/seed_5300/dense_validation.csv; Task5/seed_5300/dense_validation.csv')

        s=d.slide('Task 4 standalone motion')
        d.video(s,'task4_motion',45,110,405,370)
        d.text(s,'World and self-collision checks pass.\nTool orientation remains free.\nDemo maximum tilt: 120.29 degrees.',498,165,412,160,24)
        d.text(s,'Click video / 10 s\nSame seed, endpoints and workcell as the main comparison.',498,390,412,85,20,color=GRAY)
        d.note(s,'备份。单独播放Task4。通过碰撞验收并不代表保持直立。该图不含执行时间或杯子模型。',
            'V3 demos/workcell/Task4/seed_5300/summary.json; task4_motion.avi')

        s=d.slide('Evidence, contribution and remaining limits')
        rows=[['Evidence','Scope'],['V3 formal / demo replay','40 paths, 804 checkpoints / 2 paths, 20 checkpoints'],
            ['V4 formal replay','40 paths, 1365 checkpoints'],['V5 formal replay','75 paths, 3005 checkpoints'],
            ['Finer geometric check','Successful final paths at 0.00625 rad joint increments']]
        d.table(s,rows,40,111,880,242,[1.1,2.2],18)
        d.text(s,'Member C: workcell, upright and self-collision extensions,\ncontrolled experiments, independent verification and delivery.',40,383,880,65,22,True)
        d.text(s,'Discrete checks only. No payload geometry, dynamics, hardware execution or global guarantee.',40,477,880,42,18,color=GRAY)
        d.note(s,'备份。NumPy验证FK而非碰撞。Git compact正式数据只支持最终路径复核，完整formal随机记录在本机。保留所有失败和旧版本。下一步优先完成全组报告/贡献/总时长整合，不再启动算法版本。',
            'V3/V4/V5 formal_audit.json; fine_validation.json; README_TASK45_V5.md; docs/TASK45_V5_RESULTS.md')

        assert d.p.Slides.Count==16
        # Hidden appendix is accessible by slide number in the desktop slideshow.
        for i in range(5,17):d.p.Slides(i).SlideShowTransition.Hidden=True
        full=OUT/'task45_full.pptx';main=OUT/'task45_main.pptx'
        assert not full.exists() and not main.exists(),'Use a new output for a revision.'
        draft=PRIVATE/'draft_full.pptx';draftmain=PRIVATE/'draft_main.pptx'
        d.p.SaveAs(str(draft),24)
        # Copy, rather than alter the full deck, to make the four-slide integration file.
        d.p.SaveCopyAs(str(draftmain),24)
        write_json(PRIVATE/'powerpoint_creation.json',dict(slides=16,mainSlides=4,media=d.media,notes=d.notes))
        d.p.Close()
        from native_charts import inject
        inject(draft,full,OUT,d.charts)
        fp=app.Presentations.Open(str(full),True,False,False)
        # SaveAs PDF follows slide visibility. Reveal only in this read-only copy.
        for i in range(5,17):fp.Slides(i).SlideShowTransition.Hidden=False
        fp.SaveAs(str(OUT/'task45_full.pdf'),32)
        render=PRIVATE/'slides';render.mkdir(exist_ok=True)
        fp.Export(str(render),'PNG',1600,900)
        fp.Saved=True;fp.Close()
        m=app.Presentations.Open(str(draftmain),False,False,False)
        for i in range(m.Slides.Count,4,-1):m.Slides(i).Delete()
        m.SaveAs(str(main),24);m.SaveAs(str(OUT/'task45_main.pdf'),32);m.Close()
        # PowerPoint read-back, text bounds, table and chart editability.
        checks=[]
        for path,expected in [(full,16),(main,4)]:
            p=app.Presentations.Open(str(path),True,False,False)
            assert p.Slides.Count==expected
            issues=[];tables=charts=videos=0
            for si in range(1,p.Slides.Count+1):
                slide=p.Slides(si)
                for sh in slide.Shapes:
                    if sh.HasTable:tables+=1
                    if sh.HasChart:charts+=1
                    if sh.Type==16:videos+=1
                    if sh.HasTextFrame and sh.TextFrame.HasText:
                        tr=sh.TextFrame.TextRange
                        if tr.BoundHeight>sh.Height+2 or tr.BoundWidth>sh.Width+2:
                            issues.append(dict(slide=si,shape=sh.Name,text=tr.Text[:80],
                                bound=[tr.BoundWidth,tr.BoundHeight],box=[sh.Width,sh.Height]))
            checks.append(dict(file=path.name,slides=expected,tables=tables,charts=charts,videos=videos,textFitIssues=issues))
            p.Close()
        write_json(PRIVATE/'powerpoint_readback.json',dict(passed=not any(x['textFitIssues'] for x in checks),decks=checks))
    finally:
        if app.Presentations.Count==0:app.Quit()


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--phase',choices=['all','assets','pdf','slides'],default='all')
    args=parser.parse_args();PRIVATE.mkdir(parents=True,exist_ok=True)
    if args.phase in ['all','assets']:
        data=collect();assets()
    if args.phase in ['all','pdf']:pdf_manuscripts()
    if args.phase in ['all','slides']:
        data=collect();build_slides(data)
    print('Presentation material build finished:',args.phase,OUT)


if __name__=='__main__':main()
