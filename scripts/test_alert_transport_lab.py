import unittest
from datetime import datetime, timezone
from alert_transport_lab import SyntheticGate, fixture


class SyntheticGateTests(unittest.TestCase):
    def setUp(self):
        self.now = datetime.now(timezone.utc)
        self.gate = SyntheticGate()

    def test_valid_and_duplicate(self):
        row = fixture('air', self.now)
        self.assertEqual(self.gate.accept(row, '서울특별시', self.now)['kind'], 'air')
        self.assertIsNone(self.gate.accept(row, '서울특별시', self.now))

    def test_reject_unsafe_contexts(self):
        for name in ['other-region', 'stale', 'future', 'weather', 'release']:
            with self.subTest(name=name):
                self.assertIsNone(self.gate.accept(fixture(name, self.now), '서울특별시', self.now))

    def test_live_record_cannot_enter_lab(self):
        row = fixture('air', self.now)
        del row['labSynthetic']
        self.assertIsNone(self.gate.accept(row, '서울특별시', self.now))

    def test_missing_region_or_timezone_rejected(self):
        row = fixture('air', self.now)
        self.assertIsNone(self.gate.accept(row, '', self.now))
        row['CRT_DT'] = self.now.replace(tzinfo=None).isoformat()
        self.assertIsNone(self.gate.accept(row, '서울특별시', self.now))

    def test_ambiguous_and_reference_rejected(self):
        for message in ['훈련 공습경보 핵 경보', '훈련 공습경보 예정', '훈련 공습경보 정정']:
            row = fixture('air', self.now)
            row['MSG_CN'] = message
            self.assertIsNone(self.gate.accept(row, '서울특별시', self.now))
