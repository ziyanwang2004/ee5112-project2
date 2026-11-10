"""Create native Office charts and embedded XLSX evidence without OLE activation."""
import csv
import io
import posixpath
import xml.etree.ElementTree as E
import zipfile
from pathlib import Path

import xlsxwriter

P='http://schemas.openxmlformats.org/presentationml/2006/main'
A='http://schemas.openxmlformats.org/drawingml/2006/main'
C='http://schemas.openxmlformats.org/drawingml/2006/chart'
R='http://schemas.openxmlformats.org/officeDocument/2006/relationships'
REL='http://schemas.openxmlformats.org/package/2006/relationships'
CT='http://schemas.openxmlformats.org/package/2006/content-types'
for prefix,uri in [('p',P),('a',A),('c',C),('r',R)]:E.register_namespace(prefix,uri)


def xml(el):return E.tostring(el,encoding='utf-8',xml_declaration=True)


def make_chart(out,spec):
    arrays=[]
    for task in [4,5]:
        with (out/'evidence'/f'task{task}_demo_dense.csv').open(encoding='utf-8') as f:rows=list(csv.DictReader(f))
        arrays.append([(float(r['path_parameter']),float(r[spec['column']])*(1000 if spec['column'].endswith('_m') else 1)) for r in rows])
    bio=io.BytesIO();book=xlsxwriter.Workbook(bio,{'in_memory':True});sheet=book.add_worksheet('Evidence')
    sheet.write_row(0,0,['Task4 progress','Task4 value','Task5 progress','Task5 value','threshold progress','threshold'])
    for j,arr in enumerate(arrays):
        for i,(s,v) in enumerate(arr,1):sheet.write_row(i,2*j,[s,v])
    threshold=5 if spec['column']=='orientation_deg' else 35
    sheet.write_row(1,4,[0,threshold]);sheet.write_row(2,4,[1,threshold])
    ch=book.add_chart({'type':'scatter','subtype':'straight'})
    for j,(name,color,n) in enumerate([('Task 4','#1864B8',len(arrays[0])),('Task 5','#008F5D',len(arrays[1])),(f'{threshold} '+('deg' if threshold==5 else 'mm'),'#B5342C',2)]):
        options={'name':name,'categories':['Evidence',1,2*j,n,2*j],'values':['Evidence',1,2*j+1,n,2*j+1],
            'line':{'color':color,'width':2 if j<2 else 1},'marker':{'type':'none'}}
        if j==2:options['line']['dash_type']='dash'
        ch.add_series(options)
    ch.set_title({'name':spec['title'],'name_font':{'name':'Arial','size':18,'bold':False}})
    ch.set_x_axis({'name':'Normalized path progress','min':0,'max':1,'major_unit':.2,
        'name_font':{'name':'Arial','size':13},'num_font':{'name':'Arial','size':12},
        'line':{'color':'#8B9AA9'},'major_gridlines':{'visible':False}})
    ch.set_y_axis({'name':spec['ytitle'],'min':0 if threshold==5 else 30,
        'name_font':{'name':'Arial','size':13},'num_font':{'name':'Arial','size':12},
        'line':{'color':'#8B9AA9'},'major_gridlines':{'visible':True,'line':{'color':'#E1E6EB','width':.5}}})
    ch.set_legend({'position':'bottom','font':{'name':'Arial','size':12}})
    ch.set_chartarea({'border':{'none':True},'fill':{'color':'#FFFFFF'}})
    ch.set_plotarea({'border':{'none':True},'fill':{'color':'#FFFFFF'}})
    ch.set_size({'width':spec['w']*4/3,'height':spec['h']*4/3})
    sheet.insert_chart('H2',ch);book.close();xlsx=bio.getvalue()
    with zipfile.ZipFile(io.BytesIO(xlsx)) as z:chart=E.fromstring(z.read('xl/charts/chart1.xml'))
    # PowerPoint needs explicit defaults when importing an Excel chart part.
    for axis in chart.findall(f'.//{{{C}}}valAx'):
        scaling=axis.find(f'{{{C}}}scaling')
        axis.insert(list(axis).index(scaling)+1,E.Element(f'{{{C}}}delete',{'val':'0'}))
        axis.find(f'{{{C}}}tickLblPos').set('val','low')
    layout=chart.find(f'.//{{{C}}}plotArea/{{{C}}}layout')
    manual=E.SubElement(layout,f'{{{C}}}manualLayout')
    E.SubElement(manual,f'{{{C}}}layoutTarget',{'val':'inner'})
    for key in ['xMode','yMode','wMode','hMode']:E.SubElement(manual,f'{{{C}}}{key}',{'val':'factor'})
    for key,value in [('x',.16),('y',.14),('w',.80),('h',.62)]:E.SubElement(manual,f'{{{C}}}{key}',{'val':str(value)})
    external=E.Element(f'{{{C}}}externalData',{f'{{{R}}}id':'rId1'})
    E.SubElement(external,f'{{{C}}}autoUpdate',{'val':'0'})
    printing=chart.find(f'{{{C}}}printSettings')
    if printing is not None:chart.insert(list(chart).index(printing),external)
    else:chart.append(external)
    return xml(chart),xlsx


def inject(draft,final,out,specs):
    with zipfile.ZipFile(draft) as z:parts={n:z.read(n) for n in z.namelist()}
    ct=E.fromstring(parts['[Content_Types].xml'])
    E.SubElement(ct,f'{{{CT}}}Default',{'Extension':'xlsx','ContentType':'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'})
    for k,spec in enumerate(specs,1):
        chart,xlsx=make_chart(out,spec)
        chartpart=f'ppt/charts/chart{k}.xml';bookpart=f'ppt/embeddings/chartdata{k}.xlsx'
        parts[chartpart]=chart;parts[bookpart]=xlsx
        E.SubElement(ct,f'{{{CT}}}Override',{'PartName':'/'+chartpart,'ContentType':'application/vnd.openxmlformats-officedocument.drawingml.chart+xml'})
        rel=E.Element(f'{{{REL}}}Relationships')
        E.SubElement(rel,f'{{{REL}}}Relationship',{'Id':'rId1','Type':R+'/package','Target':f'../embeddings/chartdata{k}.xlsx'})
        parts[f'ppt/charts/_rels/chart{k}.xml.rels']=xml(rel)
        spath=f"ppt/slides/slide{spec['slide']}.xml";rpath=f"ppt/slides/_rels/slide{spec['slide']}.xml.rels"
        s=E.fromstring(parts[spath]);sr=E.fromstring(parts[rpath]);rid='rIdNativeChart'+str(k)
        E.SubElement(sr,f'{{{REL}}}Relationship',{'Id':rid,'Type':R+'/chart','Target':f'../charts/chart{k}.xml'})
        tree=s.find(f'{{{P}}}cSld/{{{P}}}spTree')
        placeholder=next(sh for sh in tree if (sh.find(f'{{{P}}}nvSpPr/{{{P}}}cNvPr') is not None and
            sh.find(f'{{{P}}}nvSpPr/{{{P}}}cNvPr').get('id')==str(spec['shapeId'])))
        frame=E.Element(f'{{{P}}}graphicFrame')
        nv=E.SubElement(frame,f'{{{P}}}nvGraphicFramePr')
        E.SubElement(nv,f'{{{P}}}cNvPr',{'id':str(spec['shapeId']),'name':'native_chart_'+spec['column']})
        E.SubElement(nv,f'{{{P}}}cNvGraphicFramePr');E.SubElement(nv,f'{{{P}}}nvPr')
        xf=E.SubElement(frame,f'{{{P}}}xfrm')
        E.SubElement(xf,f'{{{A}}}off',{'x':str(round(spec['x']*12700)),'y':str(round(spec['y']*12700))})
        E.SubElement(xf,f'{{{A}}}ext',{'cx':str(round(spec['w']*12700)),'cy':str(round(spec['h']*12700))})
        graphic=E.SubElement(frame,f'{{{A}}}graphic');gd=E.SubElement(graphic,f'{{{A}}}graphicData',{'uri':C})
        E.SubElement(gd,f'{{{C}}}chart',{f'{{{R}}}id':rid})
        index=list(tree).index(placeholder);tree.remove(placeholder);tree.insert(index,frame)
        parts[spath]=xml(s);parts[rpath]=xml(sr)
    parts['[Content_Types].xml']=xml(ct)
    assert not final.exists()
    with zipfile.ZipFile(final,'w',zipfile.ZIP_DEFLATED) as z:
        for n,b in parts.items():z.writestr(n,b)
