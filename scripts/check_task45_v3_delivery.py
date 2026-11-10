"""Validate and render V3 deliverables; visual approval is recorded separately."""
from pathlib import Path
from urllib.parse import unquote
import importlib.util
import json
import posixpath
import zipfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
RELEASE = ROOT / 'artifacts/runs/task45_v3'
OUT = RELEASE / 'delivery'
A = 'http://schemas.openxmlformats.org/drawingml/2006/main'
P = 'http://schemas.openxmlformats.org/presentationml/2006/main'


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    import fitz
    import win32com.client
    builder = load_module('v3_builder', ROOT / 'scripts/build_task45_v3_delivery.py')
    expected = builder.table_rows(builder.collect())
    tables = 0
    with zipfile.ZipFile(OUT / 'task45_v3_slides.pptx') as z:
        assert z.testzip() is None
        names = set(z.namelist())
        slides = sorted(n for n in names if n.startswith('ppt/slides/slide') and n.endswith('.xml') and '/_rels/' not in n)
        assert len(slides) == 4
        for name in names:
            if not name.endswith(('.xml', '.rels')):
                continue
            node = ET.fromstring(z.read(name))
            if name.endswith('.rels'):
                base = '' if name == '_rels/.rels' else name.rsplit('/_rels/', 1)[0]
                for rel in node:
                    if rel.attrib.get('TargetMode') == 'External':
                        continue
                    target = unquote(rel.attrib['Target']).split('#', 1)[0]
                    resolved = target.lstrip('/') if target.startswith('/') else posixpath.normpath(posixpath.join(base, target))
                    assert resolved in names, (name, resolved)
        for name in slides:
            node = ET.fromstring(z.read(name))
            for table in node.findall('.//{' + A + '}tbl'):
                tables += 1
                values = []
                for row in table.findall('{' + A + '}tr'):
                    values.append(['\n'.join(t.text or '' for t in cell.findall('.//{' + A + '}t'))
                                   for cell in row.findall('{' + A + '}tc')])
                assert values == expected, (values, expected)
        assert tables == 1
        notes = [n for n in names if n.startswith('ppt/notesSlides/notesSlide') and n.endswith('.xml') and '/_rels/' not in n]
        assert len(notes) == 4
        for name in notes:
            content = ''.join(ET.fromstring(z.read(name)).itertext())
            assert 'Sources:' in content and any('\u4e00' <= c <= '\u9fff' for c in content)
    app = win32com.client.DispatchEx('PowerPoint.Application')
    deck = app.Presentations.Open(str(OUT / 'task45_v3_slides.pptx'), True, False, False)
    overflow = []
    try:
        for i in range(1, 5):
            slide = deck.Slides(i)
            for j in range(1, slide.Shapes.Count + 1):
                shape = slide.Shapes(j)
                assert shape.Left >= -1 and shape.Top >= -1
                assert shape.Left + shape.Width <= 961 and shape.Top + shape.Height <= 541
                if shape.HasTextFrame and shape.TextFrame.HasText:
                    tr = shape.TextFrame.TextRange
                    if tr.BoundHeight > shape.Height + 2 or tr.BoundWidth > shape.Width + 3:
                        overflow.append({'slide': i, 'shape': j, 'text': tr.Text})
                if shape.HasTable:
                    for row in range(1, shape.Table.Rows.Count + 1):
                        for col in range(1, shape.Table.Columns.Count + 1):
                            cell = shape.Table.Cell(row, col).Shape
                            if cell.TextFrame.TextRange.BoundHeight > cell.Height + 2:
                                overflow.append({'slide': i, 'tableRow': row, 'tableColumn': col})
    finally:
        deck.Close()
        if app.Presentations.Count == 0:
            app.Quit()
    assert not overflow, overflow

    review = OUT / 'review'
    review.mkdir(exist_ok=True)
    pdfs = []
    for filename, pages in [('task45_v3_report.pdf', 3), ('task45_v3_slides.pdf', 4)]:
        with fitz.open(OUT / filename) as doc:
            assert len(doc) == pages, (filename, len(doc))
            for i, page in enumerate(doc):
                text = page.get_text()
                assert text.strip() and '\ufffd' not in text
                for block in page.get_text('blocks'):
                    assert block[0] >= -1 and block[1] >= -1 and block[2] <= page.rect.width + 1 and block[3] <= page.rect.height + 1
                path = review / f'{Path(filename).stem}_{i+1}.png'
                page.get_pixmap(matrix=fitz.Matrix(1.5, 1.5), alpha=False).save(path)
            pdfs.append({'path': filename, 'pages': pages})
    videos = load_module('v2_video_decoder', ROOT / 'scripts/check_task45_v2_videos.py')
    paths = sorted((RELEASE / 'demos/exports').glob('*/*.avi'))
    assert len(paths) == 3
    video_receipt = {'passed': True, 'decoder': 'Python RIFF parser + Pillow JPEG decoder',
                     'videos': [videos.inspect(path, OUT / 'video_review') for path in paths]}
    (RELEASE / 'video_qa.json').write_text(json.dumps(video_receipt, indent=2) + '\n', encoding='utf-8')
    receipt = {'passed': True, 'pdfs': pdfs, 'slides': 4, 'nativeTables': tables,
               'speakerNotesWithChineseAndSources': 4, 'textOverflow': overflow,
               'allVideoFramesDecoded': 450,
               'scope': 'Structural/layout/data checks; rendered-page visual review recorded separately.'}
    (RELEASE / 'package_qa.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(receipt, indent=2))


if __name__ == '__main__':
    main()
