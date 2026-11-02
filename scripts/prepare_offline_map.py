"""Build a bounded offline map from a Geofabrik extract, not online map tiles.

Run with .tools/offline-map-python/bin/python (osmium installed locally).
The separate official catalog must be a validated worker catalog snapshot.
"""
import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

BOUNDS = [127.088, 37.505, 127.112, 37.522]  # west, south, east, north


def inside(lon, lat):
    return BOUNDS[0] <= lon <= BOUNDS[2] and BOUNDS[1] <= lat <= BOUNDS[3]


def main():
    import osmium
    parser = argparse.ArgumentParser()
    parser.add_argument('pbf', type=Path)
    parser.add_argument('catalog', type=Path)
    parser.add_argument('--output', type=Path, default=Path('assets/offline_maps'))
    args = parser.parse_args()
    features = []

    class Extract(osmium.SimpleHandler):
        def way(self, way):
            tags = dict(way.tags)
            kind = ('road' if 'highway' in tags else 'building' if 'building' in tags
                    else None)
            if kind is None:
                return
            points = [[round(n.lon, 6), round(n.lat, 6)] for n in way.nodes if n.location.valid()]
            if len(points) < 2 or max(p[0] for p in points) < BOUNDS[0] or min(p[0] for p in points) > BOUNDS[2] or max(p[1] for p in points) < BOUNDS[1] or min(p[1] for p in points) > BOUNDS[3]:
                return
            features.append({'id': str(way.id), 'kind': kind, 'type': tags.get('highway', ''),
                             'name': tags.get('name:ko', tags.get('name', '')), 'points': points})

        def area(self, area):
            tags = dict(area.tags)
            kind = 'water' if tags.get('natural') == 'water' else 'park' if tags.get('leisure') == 'park' else None
            if kind is None:
                return
            for outer in area.outer_rings():
                points = [[round(n.lon, 6), round(n.lat, 6)] for n in outer if n.location.valid()]
                if not points or max(p[0] for p in points) < BOUNDS[0] or min(p[0] for p in points) > BOUNDS[2] or max(p[1] for p in points) < BOUNDS[1] or min(p[1] for p in points) > BOUNDS[3]:
                    continue
                holes = [[[round(n.lon, 6), round(n.lat, 6)] for n in ring if n.location.valid()] for ring in area.inner_rings(outer)]
                features.append({'id': f'area-{area.id}', 'kind': kind, 'type': '',
                                 'name': tags.get('name:ko', tags.get('name', '')),
                                 'points': points, 'holes': holes})

    Extract().apply_file(str(args.pbf), locations=True, idx='flex_mem')
    if not features:
        raise ValueError('No map geometry; refusing empty map')
    # Map and public facility layers remain separate, with distinct sources.
    catalog = json.loads(args.catalog.read_text())
    if catalog.get('status') != 'verified' or catalog.get('areaCode') != '11710' or not catalog.get('retrievedAt'):
        raise ValueError('Expected verified Songpa catalog')
    catalog['items'] = [s for s in catalog['items'] if inside(s['longitude'], s['latitude'])]
    if not catalog['items']:
        raise ValueError('No official facilities in bounds')
    catalog['coverage'] = '잠실역 주변 동봉 지도 범위'
    # Regional totals do not describe this bounded subset.
    catalog.pop('officialCount', None)
    catalog['skippedCount'] = 0
    args.output.mkdir(parents=True, exist_ok=True)
    result = {'schemaVersion': 1, 'bounds': BOUNDS, 'preparedAt': datetime.now(timezone.utc).isoformat(),
              'source': '© OpenStreetMap contributors · Geofabrik', 'license': 'ODbL 1.0',
              'sourceUrl': 'https://download.geofabrik.de/asia/south-korea-261101.osm.pbf',
              'pbfSha256': hashlib.file_digest(args.pbf.open('rb'), 'sha256').hexdigest(),
              'features': features}
    for name, data in [('jamsil-map.json', result), ('jamsil-shelters.json', catalog)]:
        (args.output / name).write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')))
    print(f'{len(features)} map features, {len(catalog["items"])} official facilities')


if __name__ == '__main__':
    main()
