"""Read-only check of the released V1 manifest; receipt goes into V2 only."""
import csv
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
manifest=ROOT/'docs/TASK45_FILES_SHA256.csv'
def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda:stream.read(1024*1024),b''): h.update(block)
    return h.hexdigest()
assert sha(manifest)=='5b561645169000dd2546c7a2d6663f08291feb5cbe89723477d93a0065088e53'
with manifest.open(encoding='utf-8-sig',newline='') as stream: rows=list(csv.DictReader(stream))
for row in rows:
    path=ROOT/row['path']
    assert path.stat().st_size==int(row['bytes']) and sha(path)==row['sha256'],row['path']
receipt={'passed':True,'v1ManifestSha256':sha(manifest),'verifiedFiles':len(rows),'v1WasReadOnly':True}
original_count=0; crlf=[]
with (ROOT/'docs/FILES_SHA256.csv').open(encoding='utf-8-sig',newline='') as stream:
    for row in csv.DictReader(stream):
        if not row['path'].startswith('artifacts/runs/final_r2023b/'): continue
        path=ROOT/row['path']; original_count+=1
        if sha(path)!=row['sha256']:
            assert path.suffix in {'.csv','.txt','.json','.md'}
            assert hashlib.sha256(path.read_bytes().replace(b'\r\n',b'\n')).hexdigest()==row['sha256'],row['path']
            crlf.append(row['path'])
assert original_count==108
receipt.update(originalTask123FrozenFilesContentUnchanged=original_count,originalCheckoutCRLFOnly=crlf)
out=ROOT/'artifacts/runs/task45_v2/v1_preservation_check.json'
out.write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
print(json.dumps(receipt,indent=2))
