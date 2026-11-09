"""Read-only file verification of the V3 Git handoff or complete local archive."""
from pathlib import Path
import argparse
import csv
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--full', action='store_true', help='Require the complete local raw archive.')
    args = parser.parse_args()
    filename = 'TASK45_V3_FILES_SHA256.csv' if args.full else 'TASK45_V3_GIT_FILES_SHA256.csv'
    with (ROOT / 'docs' / filename).open(encoding='utf-8-sig', newline='') as stream:
        rows = list(csv.DictReader(stream))
    missing, changed = [], []
    for row in rows:
        path = ROOT / row['path']
        assert path.resolve().is_relative_to(ROOT.resolve()), 'Manifest path escapes the repository.'
        if not path.is_file():
            missing.append(row['path'])
            continue
        content = path.read_bytes()
        if row['hashMode'] == 'markdown-lf':
            content = content.replace(b'\r\n', b'\n')
        else:
            assert row['hashMode'] == 'exact-bytes'
        if len(content) != int(row['bytes']) or hashlib.sha256(content).hexdigest() != row['sha256']:
            changed.append(row['path'])
    receipt = {'passed': not missing and not changed, 'manifest': filename,
               'checkedFiles': len(rows), 'missing': missing, 'changed': changed,
               'scope': 'Only Markdown in the Git subset permits CRLF/LF checkout differences; all executable source and data require exact bytes.'}
    print(json.dumps(receipt, indent=2))
    raise SystemExit(0 if receipt['passed'] else 1)


if __name__ == '__main__':
    main()
