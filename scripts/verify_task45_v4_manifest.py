"""Read-only V4 Git inventory verification; --full requires the raw archive."""
from pathlib import Path
import argparse,csv,hashlib,json
ROOT=Path(__file__).resolve().parents[1]
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--full',action='store_true');args=parser.parse_args()
    name='TASK45_V4_FILES_SHA256.csv' if args.full else 'TASK45_V4_GIT_FILES_SHA256.csv'
    with (ROOT/'docs'/name).open(encoding='utf-8-sig',newline='') as f:rows=list(csv.DictReader(f))
    missing=[];changed=[]
    for row in rows:
        p=ROOT/row['path'];assert p.resolve().is_relative_to(ROOT.resolve())
        if not p.is_file():missing.append(row['path']);continue
        data=p.read_bytes()
        if row['hashMode']=='markdown-lf':data=data.replace(b'\r\n',b'\n')
        else:assert row['hashMode']=='exact-bytes'
        if len(data)!=int(row['bytes']) or hashlib.sha256(data).hexdigest()!=row['sha256']:changed.append(row['path'])
    out={'passed':not missing and not changed,'checkedFiles':len(rows),'missing':missing,'changed':changed}
    print(json.dumps(out,indent=2));raise SystemExit(0 if out['passed'] else 1)
if __name__=='__main__':main()
