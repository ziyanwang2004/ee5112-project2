"""Read-only OOXML structure and relationship checks for the native deck."""
import json
import posixpath
import zipfile
from pathlib import Path
from urllib.parse import unquote
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
FINAL=ROOT/'artifacts/runs/task45_final'
P='http://schemas.openxmlformats.org/presentationml/2006/main'
A='http://schemas.openxmlformats.org/drawingml/2006/main'


def main():
    relationships=0; parsed=0; tables=0
    with zipfile.ZipFile(FINAL/'delivery/task45_slides.pptx') as package:
        assert package.testzip() is None
        names=set(package.namelist())
        slides=sorted(n for n in names if n.startswith('ppt/slides/slide') and n.endswith('.xml') and '/_rels/' not in n)
        assert len(slides)==4
        for name in names:
            if name.endswith(('.xml','.rels')):
                node=ET.fromstring(package.read(name)); parsed+=1
                if name.endswith('.rels'):
                    base='' if name=='_rels/.rels' else name.rsplit('/_rels/',1)[0]
                    for relation in node:
                        if relation.attrib.get('TargetMode')=='External': continue
                        target=unquote(relation.attrib['Target']).split('#',1)[0]
                        resolved=target.lstrip('/') if target.startswith('/') else posixpath.normpath(posixpath.join(base,target))
                        assert resolved in names,(name,resolved)
                        relationships+=1
        for name in slides:
            tables+=len(ET.fromstring(package.read(name)).findall('.//{'+A+'}tbl'))
        assert tables>=1
        notes=[n for n in names if n.startswith('ppt/notesSlides/notesSlide') and n.endswith('.xml') and '/_rels/' not in n]
        assert len(notes)==4
        for name in notes:
            text=''.join(ET.fromstring(package.read(name)).itertext())
            assert 'Sources:' in text and any('\u4e00'<=c<='\u9fff' for c in text)
    result={'passed':True,'nativePowerPointDeck':True,'slides':4,'editableTables':tables,
            'chineseSpeakerNotePages':4,'parsedXMLParts':parsed,'internalRelationshipsChecked':relationships,'zipCRCValid':True}
    (FINAL/'package_qa.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,indent=2))


if __name__=='__main__': main()
