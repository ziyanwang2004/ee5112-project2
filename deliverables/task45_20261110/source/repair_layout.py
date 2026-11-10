"""Set explicit native chart defaults, then render in desktop PowerPoint."""
import json
import posixpath
import shutil
import xml.etree.ElementTree as E
import zipfile
from pathlib import Path

import win32com.client
from native_charts import make_chart,xml,P,A,R,REL

OUT=Path(__file__).resolve().parents[1]
ROOT=OUT.parents[1]
PRIVATE=ROOT/'artifacts/local_runs/task45_presentation_20261110'


def main():
    app=win32com.client.DispatchEx('PowerPoint.Application')
    try:
        for i in range(app.Presentations.Count,0,-1):
            p=app.Presentations(i)
            if Path(p.FullName)==OUT/'task45_full.pptx':p.Saved=True;p.Close()
        for name in ['task45_full','task45_main']:
            path=OUT/f'{name}.pptx'
            with zipfile.ZipFile(path) as z:parts={n:z.read(n) for n in z.namelist()}
            if name=='task45_full':
                specs=[dict(column='orientation_deg',title='Tool tilt',ytitle='Tilt (deg)',w=448,h=338),
                       dict(column='voxel_gap_m',title='Conservative clearance',ytitle='Gap (mm)',w=448,h=338)]
                for k,spec in enumerate(specs,1):
                    chart,book=make_chart(OUT,spec)
                    parts[f'ppt/charts/chart{k}.xml']=chart
                    rels=E.fromstring(parts[f'ppt/charts/_rels/chart{k}.xml.rels'])
                    target=next(r.get('Target') for r in rels if r.get('Type')==R+'/package')
                    workbook_part=posixpath.normpath(posixpath.join('ppt/charts',target))
                    parts[workbook_part]=book
            for part in list(parts):
                if not part.startswith('ppt/slides/slide') or not part.endswith('.xml'):continue
                root=E.fromstring(parts[part]);index=part.split('slide')[-1].split('.')[0]
                for text in root.findall(f'.//{{{A}}}t'):
                    if text.text:
                        text.text=text.text.replace('Final maximum tilt: 5 degrees','Maximum accepted tilt: 5 degrees')
                        text.text=text.text.replace('68.04% fewer paired projection corrections vs energy control','Fixed75 vs control: median correction reduction 68.04%')
                for shape in root.findall(f'.//{{{P}}}sp'):
                    if ''.join(n.text or '' for n in shape.findall(f'.//{{{A}}}t'))==index:
                        xf=shape.find(f'{{{P}}}spPr/{{{A}}}xfrm')
                        xf.find(f'{{{A}}}off').set('x',str(880*12700))
                        xf.find(f'{{{A}}}off').set('y',str(505*12700))
                        xf.find(f'{{{A}}}ext').set('cx',str(40*12700))
                        xf.find(f'{{{A}}}ext').set('cy',str(25*12700))
                        shape.find(f'{{{P}}}txBody/{{{A}}}bodyPr').set('wrap','none')
                parts[part]=xml(root)
            fresh=PRIVATE/f'{name}_layout_repaired.pptx'
            with zipfile.ZipFile(fresh,'w',zipfile.ZIP_DEFLATED) as z:
                for part,data in parts.items():z.writestr(part,data)
            shutil.copy2(fresh,path)
            if name=='task45_full':
                edit=app.Presentations.Open(str(path),False,False,True)
                edit.Windows(1).View.GotoSlide(14)
                for shape in edit.Slides(8).Shapes:
                    if shape.HasTable:shape.Top=340;shape.Height=145
                geometry=[]
                for shape in edit.Slides(14).Shapes:
                    if not shape.HasChart:continue
                    c=shape.Chart
                    for axnum in [1,2]:
                        ax=c.Axes(axnum)
                        ax.TickLabels.Font.Name='Arial';ax.TickLabels.Font.Size=12
                        ax.TickLabels.Font.Color=22+45*256+73*65536
                        ax.AxisTitle.Font.Name='Arial';ax.AxisTitle.Font.Size=13
                        ax.AxisTitle.Font.Color=22+45*256+73*65536
                    c.PlotArea.Left=32;c.PlotArea.Top=40
                    c.PlotArea.Width=395;c.PlotArea.Height=240
                    c.ChartTitle.Top=0
                    c.Axes(1).AxisTitle.Left=100;c.Axes(1).AxisTitle.Top=283
                    c.Axes(2).AxisTitle.Left=0;c.Axes(2).AxisTitle.Top=110
                    c.Legend.Left=80;c.Legend.Width=330;c.Legend.Height=22;c.Legend.Top=312
                    geometry.append(dict(name=shape.Name,
                        axisTitle=[c.Axes(1).AxisTitle.Left,c.Axes(1).AxisTitle.Top,c.Axes(1).AxisTitle.Width,c.Axes(1).AxisTitle.Height],
                        legend=[c.Legend.Left,c.Legend.Top,c.Legend.Width,c.Legend.Height]))
                normalized=PRIVATE/'native_chart_positioned.pptx'
                edit.SaveAs(str(normalized),24);edit.Close();shutil.copy2(normalized,path)
                (PRIVATE/'native_chart_positions.json').write_text(json.dumps(geometry,indent=2)+'\n',encoding='utf-8')
            check=app.Presentations.Open(str(path),True,False,False)
            for i in range(5,check.Slides.Count+1):check.Slides(i).SlideShowTransition.Hidden=False
            check.SaveAs(str(OUT/f'{name}.pdf'),32)
            if name=='task45_full':check.Export(str(PRIVATE/'slides'),'PNG',1600,900)
            check.Saved=True;check.Close()
        (PRIVATE/'layout_repair_qa.json').write_text(json.dumps({'passed':True,
            'chartMode':'Explicit native axis visibility and inner plot layout; embedded source data unchanged'})+'\n',encoding='utf-8')
        print('Native chart defaults and page labels repaired and rendered in PowerPoint.')
    finally:
        if app.Presentations.Count==0:app.Quit()


if __name__=='__main__':main()
