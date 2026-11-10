"""Record completed visual review, bound to the final artifacts' hashes."""
from pathlib import Path
import hashlib
import json
ROOT=Path(__file__).resolve().parents[1]
FINAL=ROOT/'artifacts/runs/task45_v2'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
pages=sorted((FINAL/'delivery/review').glob('task45_v2_*.png'))
assert len(pages)==8
figures=sorted((FINAL/'demos/exports').glob('*/*.png'))
assert len(figures)==8
figures+=sorted((FINAL/'diagnosis').glob('*.png')); assert len(figures)==10
video_review=[FINAL/'delivery/video_review'/scene/name for scene in ['main','variant']
              for name in ['paired_motion_001.png','paired_motion_075.png','paired_motion_150.png']]
assert all(p.exists() for p in video_review)
records=lambda paths:[{'path':p.relative_to(ROOT).as_posix(),'sha256':sha(p)} for p in paths]
receipt={'passed':True,'clientDate':'2026-11-09','pdfPagesReviewed':8,
         'reviewScope':'All report and slide pages, source figures, representative paired video frames; changed plots and slide headers rechecked after layout repair.',
         'pdfPages':records(pages),'figures':records(figures),'pairedVideoFrameSamples':records(video_review),
         'finalFiles':records([FINAL/'delivery/task45_v2_report.pdf',FINAL/'delivery/task45_v2_slides.pdf',FINAL/'delivery/task45_v2_slides.pptx']),
         'repairs':['Native table headers line-wrapped','Diagnosis figure title margins','Summary figures retain axes labels and separate clearance legend text'],
         'planningSourceOrTrajectoryEdits':False}
(FINAL/'visual_qa.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
print('Visual review receipt recorded for 8 PDF pages and 10 source figures.')
