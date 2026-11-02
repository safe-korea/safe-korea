"""One bounded government read -> civil-defense-only signed snapshot. No listener."""
import argparse
import base64
from datetime import datetime, timedelta, timezone
import hmac
import json
import os
from pathlib import Path
import re
import sqlite3
import time
import urllib.error
import urllib.parse
import urllib.request

LIMIT = 2 * 1024 * 1024
ENDPOINT = 'https://www.safetydata.go.kr/V2/api/DSSP-IF-00247'
WORKER = 'https://safe-korea-shelter-api.trovapp.workers.dev'
FIELDS = {'SN', 'CRT_DT', 'MSG_CN', 'RCPTN_RGN_NM', 'EMRG_STEP_NM', 'DST_SE_NM',
          'REG_YMD', 'MDFCN_YMD', 'RCPTN_RGN_ID', 'EMRG_STEP_ID', 'DST_SE_ID'}
FRESHNESS_MS = 120000


def query_start_date(now_ms):
    # The first polls after KST midnight must still include fresh prior-day rows.
    return datetime.fromtimestamp((now_ms - FRESHNESS_MS) / 1000, timezone.utc).astimezone(
        timezone(timedelta(hours=9))).strftime('%Y%m%d')

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args):
        return None


def bounded_read(response):
    if int(response.headers.get('Content-Length', '0')) > LIMIT:
        raise ValueError('size')
    raw = response.read(LIMIT + 1)
    if len(raw) > LIMIT:
        raise ValueError('size')
    return raw


def snapshot(raw, now_ms):
    """All ordinary disaster/personal-message bodies are discarded before export."""
    out = {'protocolVersion': 1, 'collectedAt': now_ms, 'sourceReadAt': now_ms,
           'state': 'source_invalid_response', 'complete': False,
           'recordCount': 0, 'totalCount': 0, 'rows': []}
    try:
        if len(raw) > LIMIT:
            return out
        data = json.loads(raw)
    except (ValueError, UnicodeError):
        code = re.search(rb'<returnReasonCode[^>]*>\s*(?:<!\[CDATA\[)?\s*(\d+)', raw)
        if code:
            code = code.group(1).decode()
            if re.fullmatch(r'01|02|10|11|12|13|20|22|30|31|32|33|34|99', code):
                out['gatewayCode'] = code
                out['state'] = 'source_ip_denied' if code == '32' else 'source_quota' if code == '22' else 'source_auth_error'
        return out
    rows, totals, errors = [], [], []
    def visit(value):
        if isinstance(value, list):
            for item in value:
                visit(item)
        elif isinstance(value, dict):
            if 'SN' in value:
                rows.append(value)
                return
            for name, child in value.items():
                if name == 'totalCount' and not isinstance(child, bool):
                    try:
                        totals.append(int(child))
                    except (ValueError, TypeError):
                        pass
                if name in ('resultCode', 'returnReasonCode') and str(child) not in ('0', '00'):
                    errors.append(str(child))
                visit(child)
    visit(data)
    if errors:
        out['state'] = 'source_auth_error'
        for code in errors:
            if re.fullmatch(r'01|02|10|11|12|13|20|22|30|31|32|33|34|99', code):
                out['gatewayCode'] = code
                out['state'] = 'source_ip_denied' if code == '32' else 'source_quota' if code == '22' else 'source_auth_error'
                break
        return out
    complete = (len(rows) <= 100 and len(totals) == 1 and totals[0] == len(rows)
                and len({str(r['SN']) for r in rows}) == len(rows)
                and all(FIELDS <= r.keys() and all(isinstance(r[f], (str, int))
                    and not isinstance(r[f], bool) and str(r[f]).strip() for f in FIELDS) for r in rows))
    out.update(state='source_observed' if complete else 'source_incomplete',
               complete=complete, recordCount=min(len(rows), 100),
               totalCount=max(totals[0], 0) if totals else 0)
    if complete:
        out['rows'] = [{f: r[f] for f in FIELDS} for r in rows if r['DST_SE_NM'] == '민방공']
    return out


def sign_snapshot(value, secret):
    body = json.dumps(value, ensure_ascii=False, separators=(',', ':')).encode()
    stamp = str(value['collectedAt'])
    signature = base64.urlsafe_b64encode(hmac.digest(secret.encode(), stamp.encode() + b'\n' + body, 'sha256')).decode().rstrip('=')
    return body, {'Content-Type': 'application/json', 'User-Agent': 'safeKor-collector/1.0',
                  'X-SafeKor-Timestamp': stamp, 'X-SafeKor-Signature': signature}


def reserve_budget(connection, now_ms):
    day = datetime.fromtimestamp(now_ms / 1000, timezone.utc).astimezone(timezone(timedelta(hours=9))).date().isoformat()
    connection.execute('CREATE TABLE IF NOT EXISTS budget(day TEXT PRIMARY KEY, count INTEGER NOT NULL)')
    connection.execute('CREATE TABLE IF NOT EXISTS runtime(name TEXT PRIMARY KEY,value INTEGER NOT NULL)')
    connection.commit()
    connection.execute('BEGIN IMMEDIATE')
    blocked = connection.execute("SELECT value FROM runtime WHERE name='next_attempt'").fetchone()
    if blocked and blocked[0] > now_ms:
        connection.rollback()
        return 'source_backoff'
    row = connection.execute('SELECT count FROM budget WHERE day=?', (day,)).fetchone()
    if row and row[0] >= 900:
        connection.rollback()
        return 'daily_budget'
    connection.execute('INSERT INTO budget(day,count) VALUES (?,1) ON CONFLICT(day) DO UPDATE SET count=count+1', (day,))
    connection.commit()
    return None


def run(config_path, reset=False, opener=None):
    os.umask(0o077)
    path = Path(config_path)
    if path.is_symlink() or path.stat().st_mode & 0o077:
        return {'status': 'config_requires_mode_600'}
    config = json.loads(path.read_text())
    key, secret = config.get('serviceKey'), config.get('collectorKey')
    if (not isinstance(key, str) or not key.strip() or not isinstance(secret, str)
            or not re.fullmatch(r'[A-Za-z0-9_-]{43}', secret)):
        return {'status': 'config_invalid'}
    now = int(time.time() * 1000)
    connection = sqlite3.connect(path.parent / 'collector-budget.sqlite', timeout=1)
    if reset:
        connection.execute('CREATE TABLE IF NOT EXISTS runtime(name TEXT PRIMARY KEY,value INTEGER NOT NULL)')
        connection.execute("DELETE FROM runtime WHERE name='next_attempt'")
        connection.commit()
    limited = reserve_budget(connection, now)
    if limited:
        connection.close()
        return {'status': limited}
    connection.execute('DELETE FROM budget WHERE day<?', ((datetime.fromtimestamp(now / 1000, timezone.utc) - timedelta(days=7)).date().isoformat(),))
    connection.commit()
    client = opener or urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
    date = query_start_date(now)
    url = ENDPOINT + '?' + urllib.parse.urlencode({'serviceKey': key.strip(), 'returnType': 'json', 'pageNo': 1, 'numOfRows': 100, 'crtDt': date})
    result = {'protocolVersion': 1, 'collectedAt': now, 'sourceReadAt': now,
              'state': 'source_network_error', 'complete': False, 'recordCount': 0, 'totalCount': 0, 'rows': []}
    try:
        with client.open(urllib.request.Request(url, headers={'Accept': 'application/json', 'User-Agent': 'safeKor-collector/1.0'}), timeout=15) as response:
            result = snapshot(bounded_read(response), int(time.time() * 1000))
    except urllib.error.HTTPError as error:
        result = snapshot(bounded_read(error), int(time.time() * 1000))
        if 300 <= error.code < 400:
            result['state'] = 'source_redirect_rejected'
        elif result['state'] not in ('source_ip_denied', 'source_auth_error', 'source_quota'):
            result['state'] = 'source_http_error'
        result['complete'] = False
        result['rows'] = []
    except (OSError, ValueError):
        pass
    if result['state'] in ('source_ip_denied', 'source_auth_error', 'source_quota'):
        connection.execute("INSERT INTO runtime(name,value) VALUES ('next_attempt',?) ON CONFLICT(name) DO UPDATE SET value=excluded.value", (now + 6 * 3600000,))
        connection.commit()
    connection.close()
    body, headers = sign_snapshot(result, secret)
    try:
        with client.open(urllib.request.Request(WORKER + '/api/push/collector', data=body, headers=headers, method='POST'), timeout=15) as response:
            ack = json.loads(bounded_read(response))
            return {'status': result['state'], 'complete': result['complete'], 'records': result['recordCount'], 'snapshot_accepted': ack.get('accepted') is True}
    except (OSError, ValueError):
        return {'status': result['state'], 'snapshot_accepted': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', required=True)
    parser.add_argument('--reset-backoff', action='store_true')
    args = parser.parse_args()
    try:
        result = run(args.config, args.reset_backoff)
    except Exception:
        result = {'status': 'collector_unavailable'}
    # Fixed operational labels/counts only. Never log exception text or URLs.
    print(json.dumps(result, ensure_ascii=False))

if __name__ == '__main__':
    main()
