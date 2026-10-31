#!/usr/bin/env python3
"""Import a manually verified official CSV. No fetching, credentials or geocoding.

Only explicit WGS84 latitude/longitude is accepted. Never guess a projected CRS.
See DATA_SOURCES.md for the required review and normalized CSV schema.
"""
import argparse
import csv
import hashlib
import io
import json
import math
from datetime import date, datetime, timezone
from pathlib import Path

SOURCE = 'https://www.data.go.kr/data/15021098/standard.do'
FIELDS = {'id', 'name', 'address', 'latitude', 'longitude', 'updatedAt', 'status'}


def convert(raw: bytes, coverage: str) -> dict:
    reader = csv.DictReader(io.StringIO(raw.decode('utf-8-sig')))
    if not FIELDS.issubset(reader.fieldnames or []):
        raise ValueError('필수 열: ' + ', '.join(sorted(FIELDS)))
    items, ids = [], set()
    for line, row in enumerate(reader, 2):
        # Exclude explicitly released facilities; reject unknown status.
        if row['status'] == 'released':
            continue
        if row['status'] != 'designated':
            raise ValueError(f'{line}행: 지정 상태 확인 필요')
        item = {key: row[key].strip() for key in FIELDS}
        if any(not item[key] for key in FIELDS):
            raise ValueError(f'{line}행: 필수 정보 누락')
        lat, lon = float(item['latitude']), float(item['longitude'])
        if not (math.isfinite(lat) and math.isfinite(lon) and 33 <= lat <= 39.5 and 124 <= lon <= 132):
            raise ValueError(f'{line}행: WGS84 대한민국 좌표 아님 (투영좌표 자동변환 안 함)')
        updated = date.fromisoformat(item['updatedAt'])
        if updated > date.today():
            raise ValueError(f'{line}행: 미래 갱신일')
        if item['id'] in ids:
            raise ValueError(f'{line}행: 중복 ID')
        ids.add(item['id'])
        item.update(latitude=lat, longitude=lon)
        items.append(item)
    if not items:
        raise ValueError('검증된 지정 시설이 0개입니다. 기존 자료를 교체하지 않습니다.')
    return dict(schemaVersion=1, sourceName='행정안전부 · 전국민방위대피시설표준데이터',
                sourceUrl=SOURCE, retrievedAt=datetime.now(timezone.utc).date().isoformat(),
                coverage=coverage, status='verified', inputSha256=hashlib.sha256(raw).hexdigest(), items=items)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('csv', type=Path)
    parser.add_argument('--coverage', required=True, help='실제 자료의 지역·범위')
    parser.add_argument('--confirmed-official', action='store_true', help='공식 원본/지정상태/CRS/갱신일 수동 검증 완료')
    parser.add_argument('--output', type=Path, default=Path('assets/shelters.json'))
    args = parser.parse_args()
    if not args.confirmed_official:
        parser.error('공식 원본과 좌표·상태를 검증한 후 --confirmed-official을 지정하세요')
    result = convert(args.csv.read_bytes(), args.coverage)
    # Only replace after the entire input validates; atomic write in same directory.
    temp = args.output.with_suffix('.tmp')
    temp.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    temp.replace(args.output)
    print(f'{len(result["items"])}개 시설 변환. 원본 SHA256: {result["inputSha256"]}')


if __name__ == '__main__':
    main()
