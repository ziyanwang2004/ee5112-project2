"""Independently decode all MJPEG AVI frames without MATLAB or extra codecs."""
import io
import json
import struct
from pathlib import Path
from PIL import Image, ImageStat

ROOT=Path(__file__).resolve().parents[1]
FINAL=ROOT/'artifacts/runs/task45_v2'

def inspect(path,review_root=None):
    data=path.read_bytes(); assert data[:4]==b'RIFF' and data[8:12]==b'AVI '
    frames=[]; main=None; stream=None
    def walk(start,end,in_movi=False):
        nonlocal main,stream
        cursor=start
        while cursor+8<=end:
            tag=data[cursor:cursor+4]; size=struct.unpack_from('<I',data,cursor+4)[0]
            first=cursor+8; last=first+size; assert last<=len(data),(path,tag,size)
            if tag in (b'LIST',b'RIFF'):
                kind=data[first:first+4]; walk(first+4,last,in_movi or kind==b'movi')
            elif tag==b'avih': main=data[first:last]
            elif tag==b'strh' and data[first:first+4]==b'vids': stream=data[first:last]
            elif in_movi and tag[2:] in (b'dc',b'db') and tag[:2].isdigit(): frames.append((first,last))
            cursor=last+(size%2)
    walk(12,min(len(data),8+struct.unpack_from('<I',data,4)[0]))
    assert main is not None and stream is not None
    expected=struct.unpack_from('<I',main,16)[0]; width,height=struct.unpack_from('<II',main,32)
    scale,rate=struct.unpack_from('<II',stream,20); fps=rate/scale
    assert expected==150 and len(frames)==150 and abs(fps-15)<1e-12,(path,expected,len(frames),fps)
    selected=[]; review=(FINAL/'delivery/video_review' if review_root is None else review_root)/path.parent.name; review.mkdir(parents=True,exist_ok=True)
    for k,(first,last) in enumerate(frames):
        with Image.open(io.BytesIO(data[first:last])) as image:
            image.load(); assert image.size==(width,height)
            if k in (0,74,149):
                assert max(ImageStat.Stat(image).var)>1,'Blank sampled frame'
                target=review/f'{path.stem}_{k+1:03d}.png'; image.save(target); selected.append(str(target.relative_to(ROOT)))
    return {'path':str(path.relative_to(ROOT)),'frames':len(frames),'fps':fps,'width':width,'height':height,
            'allFramesDecoded':True,'nonblankFrames':[1,75,150],'reviewImages':selected}

def main():
    files=sorted((FINAL/'demos/exports').glob('*/*.avi')); assert len(files)==6
    receipt={'passed':True,'decoder':'Python RIFF parser + Pillow JPEG decoder','videos':[inspect(path) for path in files]}
    (FINAL/'video_qa.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'passed':True,'videos':6,'decodedFrames':sum(v['frames'] for v in receipt['videos'])}))
if __name__=='__main__': main()
