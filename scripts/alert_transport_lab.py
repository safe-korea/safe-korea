"""Loopback-only synthetic delivery lab. No keys, government calls or push service.

Wire fields mirror the API, but kind/time/region semantics here are synthetic
contracts, NOT an interpretation of unverified government metadata.
"""
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
from urllib.parse import urlsplit, parse_qs
from review_alert_scope import review_record


class SyntheticGate:
    def __init__(self):
        self.seen = set()

    def accept(self, row, region, now):
        if row.get('labSynthetic') is not True or not str(row.get('SN', '')).startswith('lab-'):
            return None
        review = review_record(row)
        if review['route'] != 'civil_defense_review' or 'drill' not in review['hints']:
            return None
        if row.get('RCPTN_RGN_NM') not in (region, '전국') or not region:
            return None
        if any(f != 'drill_context_requires_review' for f in review['review_flags']):
            return None
        try:
            created = datetime.fromisoformat(row['CRT_DT'])
            age = (now - created).total_seconds()
        except (KeyError, ValueError, TypeError):
            return None
        if not 0 <= age <= 120:
            return None
        kinds = [kind for hint, kind in [('air_raid', 'air'), ('watch', 'watch'), ('nuclear', 'nuclear')]
                 if hint in review['hints']]
        identity = row['SN']
        if len(kinds) != 1 or identity in self.seen:
            return None
        self.seen.add(identity)
        return {'id': identity, 'kind': kinds[0], 'testOnly': True,
                'expiresAt': (created + timedelta(seconds=120)).isoformat()}


def fixture(name, now):
    row = {'labSynthetic': True, 'SN': 'lab-' + name, 'DST_SE_NM': '민방공',
           'EMRG_STEP_NM': '위급재난', 'MSG_CN': '[훈련 / 테스트] 공습경보',
           'RCPTN_RGN_NM': '서울특별시', 'CRT_DT': now.isoformat()}
    if name == 'other-region': row['RCPTN_RGN_NM'] = '부산광역시'
    if name == 'stale': row['CRT_DT'] = (now - timedelta(minutes=10)).isoformat()
    if name == 'future': row['CRT_DT'] = (now + timedelta(minutes=10)).isoformat()
    if name == 'weather': row.update(DST_SE_NM='호우', MSG_CN='호우 안내')
    if name == 'release': row['MSG_CN'] = '[훈련 / 테스트] 공습경보 해제'
    return row


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        url = urlsplit(self.path)
        scenario = parse_qs(url.query).get('scenario', ['air'])[0]
        allowed = ('air', 'duplicate', 'other-region', 'stale', 'future', 'weather', 'release')
        if url.path != '/lab/events' or scenario not in allowed:
            self.send_error(404)
            return
        now = datetime.now(timezone.utc)
        gate = SyntheticGate()
        row = fixture(scenario, now)
        # One response models a collection batch, including repeated records.
        rows = [row, row] if scenario == 'duplicate' else [row]
        events = [event for r in rows if (event := gate.accept(r, '서울특별시', now))]
        data = json.dumps({'testOnly': True, 'events': events}).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)


if __name__ == '__main__':
    print('Synthetic lab listening on 127.0.0.1:8799; no government/push connection', flush=True)
    HTTPServer(('127.0.0.1', 8799), Handler).serve_forever()
