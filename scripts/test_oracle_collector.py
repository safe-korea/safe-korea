import base64
import hashlib
import hmac
import importlib.util
import json
from pathlib import Path
import sqlite3
import unittest

spec = importlib.util.spec_from_file_location('oracle_collector', Path(__file__).resolve().parents[1] / 'deployment/alert_collector/collector.py')
collector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(collector)
cron_spec = importlib.util.spec_from_file_location('collector_cron', Path(__file__).resolve().parents[1] / 'deployment/alert_collector/install_cron.py')
cron = importlib.util.module_from_spec(cron_spec)
cron_spec.loader.exec_module(cron)

class CollectorTests(unittest.TestCase):
    def test_cron_preserves_other_jobs_and_is_idempotent(self):
        folder = Path('/home/ubuntu/.local/share/safekor-alert-collector')
        original = 'MAILTO=""\n0 2 * * * /home/ubuntu/existing-backup\n'
        updated = cron.managed_cron(original, folder)
        self.assertTrue(updated.startswith(original))
        self.assertEqual(updated.count('*/2 * * * *'), 1)
        self.assertEqual(cron.managed_cron(updated, folder), updated)
        with self.assertRaises(ValueError):
            cron.managed_cron(original + cron.START, folder)

    def row(self, category='민방공'):
        result = dict.fromkeys(collector.FIELDS, 'synthetic')
        result.update(SN=1, DST_SE_NM=category, MSG_CN='합성 자료 · 실제 발령 아님')
        return result

    def test_only_civil_defense_rows_are_exported(self):
        rows = [self.row(), self.row('실종')]
        result = collector.snapshot(json.dumps({'header': {'resultCode': '00'}, 'totalCount': 2, 'body': rows}).encode(), 1700000000000)
        self.assertTrue(result['complete'])
        self.assertEqual(result['recordCount'], 2)
        self.assertEqual(len(result['rows']), 1)
        self.assertEqual(result['rows'][0]['DST_SE_NM'], '민방공')

    def test_incomplete_or_gateway_errors_cannot_export_rows(self):
        for raw in [b'{}', b'broken', b'x' * (collector.LIMIT + 1), json.dumps({'totalCount': 101, 'body': [self.row()]}).encode()]:
            result = collector.snapshot(raw, 1700000000000)
            self.assertFalse(result['complete'])
            self.assertEqual(result['rows'], [])
        for raw in [b'<returnReasonCode>32</returnReasonCode>', b'{"header":{"resultCode":"32"}}']:
            self.assertEqual(collector.snapshot(raw, 1700000000000)['state'], 'source_ip_denied')

    def test_signature_binds_exact_body_and_timestamp(self):
        record = collector.snapshot(b'{"totalCount":0,"body":[]}', 1700000000000)
        body, headers = collector.sign_snapshot(record, 'a' * 43)
        expected = hmac.digest(b'a' * 43, b'1700000000000\n' + body, 'sha256')
        self.assertEqual(base64.urlsafe_b64encode(expected).decode().rstrip('='), headers['X-SafeKor-Signature'])
        self.assertNotIn('serviceKey', body.decode())
        self.assertEqual(headers['User-Agent'], 'safeKor-collector/1.0')

    def test_daily_budget_and_persistent_backoff(self):
        db = sqlite3.connect(':memory:')
        now = 1700000000000
        self.assertIsNone(collector.reserve_budget(db, now))
        db.execute('UPDATE budget SET count=900')
        db.commit()
        self.assertEqual(collector.reserve_budget(db, now), 'daily_budget')
        db.execute('DELETE FROM budget')
        db.execute("INSERT INTO runtime(name,value) VALUES ('next_attempt',?)", (now + 3600000,))
        db.commit()
        self.assertEqual(collector.reserve_budget(db, now), 'source_backoff')
        self.assertIsNone(collector.reserve_budget(db, now + 3600001))
        db.close()
