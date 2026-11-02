"""Single, read-only official API probe. Never emits credentials or message text."""
import argparse
from review_alert_scope import summarize_scope
import json
from pathlib import Path
import ssl
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

ENDPOINT = 'https://www.safetydata.go.kr/V2/api/DSSP-IF-00247'
LIMIT = 2 * 1024 * 1024
ERRORS = {'22': 'daily_quota_exceeded', '30': 'unregistered_key',
          '31': 'expired_key', '32': 'unregistered_ip', '33': 'missing_key',
          '20': 'access_denied', '01': 'application_error', '02': 'service_timeout',
          '10': 'invalid_parameter', '11': 'missing_parameter', '12': 'service_not_found',
          '13': 'unsupported_method', '34': 'multiple_keys', '99': 'unknown_gateway_error'}
FIELDS = {'SN', 'CRT_DT', 'MSG_CN', 'RCPTN_RGN_NM', 'EMRG_STEP_NM',
          'DST_SE_NM', 'REG_YMD', 'MDFCN_YMD', 'RCPTN_RGN_ID',
          'EMRG_STEP_ID', 'DST_SE_ID'}


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def summarize(raw):
    """Summarize only structure. API free text and unknown fields never escape."""
    if len(raw) > LIMIT:
        return {'status': 'response_too_large'}
    try:
        data = json.loads(raw)
    except (ValueError, UnicodeError):
        try:
            root = ET.fromstring(raw)
            code = next((node.text for node in root.iter()
                         if node.tag.split('}')[-1] in ('returnReasonCode', 'resultCode')), None)
            return {'status': ERRORS.get(code, 'xml_response_unverified')}
        except ET.ParseError:
            return {'status': 'invalid_response'}
    # Walk envelopes without assuming page one is newest or a schema is confirmed.
    rows = []
    codes = []
    def visit(value):
        if isinstance(value, dict):
            if 'SN' in value:
                rows.append(value)
            for key, child in value.items():
                if key in ('resultCode', 'returnReasonCode'):
                    codes.append(str(child))
                visit(child)
        elif isinstance(value, list):
            for child in value:
                visit(child)
    visit(data)
    if any(code in ERRORS for code in codes):
        return {'status': next(ERRORS[code] for code in codes if code in ERRORS)}
    if any(code not in ('00', '0') for code in codes):
        return {'status': 'unrecognized_gateway_code'}
    if not rows:
        return {'status': 'no_records_schema_unverified'}
    ids = [str(row['SN']) for row in rows]
    complete = all(FIELDS <= row.keys() and all(
        isinstance(row.get(field), (str, int)) and not isinstance(row.get(field), bool)
        and str(row[field]).strip() for field in FIELDS) for row in rows)
    return {'status': 'records_observed' if complete else 'records_incomplete',
            'record_count': len(rows), 'duplicate_ids': len(ids) - len(set(ids)),
            'documented_fields_seen': sorted(FIELDS.intersection(set().union(*(r.keys() for r in rows)))),
            'missing_documented_fields': sorted(set().union(*(FIELDS - r.keys() for r in rows))),
            'delivery_latency_verified': False, 'alert_delivery_enabled': False,
            'scope_review': summarize_scope(rows) if complete else None}


def probe(config_path):
    try:
        path = Path(config_path)
        if path.stat().st_mode & 0o077:
            return {'status': 'config_requires_mode_600'}
        config = json.loads(path.read_text())
        if not isinstance(config, dict):
            return {'status': 'missing_or_invalid_local_config'}
        key = config['serviceKey']
        if not isinstance(key, str) or not key.strip():
            return {'status': 'missing_local_key'}
    except (OSError, ValueError, KeyError):
        return {'status': 'missing_or_invalid_local_config'}
    query = urllib.parse.urlencode({'serviceKey': key, 'numOfRows': 3,
                                   'pageNo': 1, 'returnType': 'json'})
    # Explicitly avoid environment proxies: only the official HTTPS host gets the key.
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect(),
                                        urllib.request.HTTPSHandler(context=ssl.create_default_context()))
    try:
        with opener.open(ENDPOINT + '?' + query, timeout=15) as response:
            return summarize(response.read(LIMIT + 1))
    except urllib.error.HTTPError as error:
        # No error string/URL/body logging, no redirects or retries.
        return {'status': 'http_error', 'http_status': error.code}
    except (OSError, ValueError, RecursionError):
        return {'status': 'network_or_response_error'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', default='config/safetydata.local.json')
    args = parser.parse_args()
    result = probe(args.config)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result['status'] == 'records_observed' else 1


if __name__ == '__main__':
    raise SystemExit(main())
