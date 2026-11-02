import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from check_alert_api import FIELDS, LIMIT, NoRedirect, probe, summarize


class AlertProbeTests(unittest.TestCase):
    def test_records_do_not_expose_message_or_unknown_secrets(self):
        row = dict.fromkeys(FIELDS, 'private-value')
        row['secret'] = 'credential-do-not-print'
        result = summarize(json.dumps({'body': [row, row]}).encode())
        self.assertEqual(result['status'], 'records_observed')
        self.assertEqual(result['duplicate_ids'], 1)
        self.assertNotIn('private-value', str(result))
        self.assertNotIn('credential', str(result))
        self.assertFalse(result['delivery_latency_verified'])

    def test_gateway_ip_and_quota_errors(self):
        for code, status in [('32', 'unregistered_ip'), ('22', 'daily_quota_exceeded')]:
            self.assertEqual(summarize(f'<error><returnReasonCode>{code}</returnReasonCode></error>'.encode())['status'], status)
            self.assertEqual(summarize(json.dumps({'header': {'resultCode': code}}).encode())['status'], status)

    def test_empty_invalid_and_partial_are_not_success(self):
        for raw in [b'{}', b'<html>login</html>', b'broken', b'{"body":[{"SN":1}]}', b'x' * (LIMIT + 1)]:
            self.assertNotEqual(summarize(raw)['status'], 'records_observed')

    def test_error_header_cannot_be_overridden_by_records(self):
        row = dict.fromkeys(FIELDS, 'example')
        for code in ['01', '99', 'unexpected-code']:
            raw = json.dumps({'header': {'resultCode': code}, 'body': [row]}).encode()
            self.assertNotEqual(summarize(raw)['status'], 'records_observed')

    def test_null_or_empty_fields_are_incomplete(self):
        for value in [None, '', ' ', {}, [], False]:
            row = dict.fromkeys(FIELDS, 'example')
            row['MSG_CN'] = value
            self.assertEqual(summarize(json.dumps({'body': [row]}).encode())['status'],
                             'records_incomplete')

    def test_non_object_config_never_calls_network(self):
        with tempfile.TemporaryDirectory() as directory, patch('urllib.request.build_opener') as opener:
            file = Path(directory) / 'key.json'
            file.write_text('[]')
            file.chmod(0o600)
            self.assertEqual(probe(file)['status'], 'missing_or_invalid_local_config')
            opener.assert_not_called()

    def test_invalid_sample_size_never_calls_network(self):
        with patch('urllib.request.build_opener') as opener:
            for size in [0, 101, -1, True, '100']:
                self.assertEqual(probe('unused', size)['status'], 'invalid_sample_size')
            opener.assert_not_called()

    def test_no_redirect(self):
        self.assertIsNone(NoRedirect().redirect_request(None, None, 302, '', {}, 'https://other.example'))

    def test_invalid_config_never_calls_network(self):
        with tempfile.TemporaryDirectory() as directory, patch('urllib.request.build_opener') as opener:
            file = Path(directory) / 'key.json'
            self.assertEqual(probe(file)['status'], 'missing_or_invalid_local_config')
            file.write_text('{"serviceKey":"secret"}')
            file.chmod(0o644)
            self.assertEqual(probe(file)['status'], 'config_requires_mode_600')
            opener.assert_not_called()


if __name__ == '__main__':
    unittest.main()
