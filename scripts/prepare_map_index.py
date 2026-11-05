"""Write the bundled size index of published road cells (KB per cell).

Used only to show an accurate download size and to skip cells that do not
exist (sea, borders). Regenerate whenever `.tools/saved-map-packs/v1` changes.
"""
import json
from pathlib import Path

packs = Path('.tools/saved-map-packs/v1')
index = {p.stem: max(1, round(p.stat().st_size / 1024)) for p in sorted(packs.glob('*.json'))}
out = Path('assets/offline_map_index.json')
out.write_text(json.dumps({'schemaVersion': 1, 'sourceDate': '2026-11-01', 'cellsKb': index}, separators=(',', ':')))
print(len(index), 'cells', out.stat().st_size, 'bytes')
