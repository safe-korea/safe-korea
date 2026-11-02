import json
from contextlib import closing
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import sqlite3
import tempfile
import unittest
from unittest.mock import patch
from alert_review_store import record_batch, ReviewStoreError
from check_alert_api import summarize, FIELDS


class PersistentReviewTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name) / 'review.sqlite'
        self.row = {'SN': 'synthetic-id', 'MSG_CN': 'private synthetic text', 'RCPTN_RGN_NM': 'private place'}

    def test_reopen_revision_and_old_version_replay(self):
        self.assertEqual(record_batch(self.path, [self.row])['record_counts'], {'first_seen_review': 1})
        self.assertEqual(record_batch(self.path, [self.row])['record_counts'], {'duplicate': 1})
        changed = dict(self.row, MSG_CN='synthetic correction')
        self.assertEqual(record_batch(self.path, [changed, self.row])['record_counts'], {'duplicate': 1, 'revision_review': 1})
        with closing(sqlite3.connect(self.path)) as db, db:
            self.assertEqual(db.execute('SELECT count(*) FROM reviewed_versions').fetchone()[0], 2)
        raw = self.path.read_bytes()
        for value in self.row.values():
            self.assertNotIn(value.encode(), raw)
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o600)

    def test_invalid_batch_does_not_partially_commit(self):
        record_batch(self.path, [self.row])
        with self.assertRaises(ReviewStoreError):
            record_batch(self.path, [dict(self.row, SN='new'), {'SN': None}])
        self.assertEqual(record_batch(self.path, [dict(self.row, SN='new')])['record_counts'], {'first_seen_review': 1})

    def test_foreign_database_and_future_version_are_preserved(self):
        with closing(sqlite3.connect(self.path)) as db, db:
            db.execute('CREATE TABLE user_data (value TEXT)')
            db.execute("INSERT INTO user_data VALUES ('keep')")
        self.path.chmod(0o600)
        with self.assertRaises(ReviewStoreError):
            record_batch(self.path, [self.row])
        with closing(sqlite3.connect(self.path)) as db, db:
            self.assertEqual(db.execute('SELECT value FROM user_data').fetchone()[0], 'keep')
            db.execute('PRAGMA user_version=99')
        with self.assertRaises(ReviewStoreError):
            record_batch(self.path, [self.row])

    def test_broad_permissions_and_symlinks_rejected(self):
        self.path.touch(mode=0o644)
        self.path.chmod(0o644)
        with self.assertRaises(ReviewStoreError):
            record_batch(self.path, [self.row])
        alias = Path(self.tmp.name) / 'alias.sqlite'
        self.path.chmod(0o600)
        alias.symlink_to(self.path)
        with self.assertRaises(ReviewStoreError):
            record_batch(alias, [self.row])

    def test_same_batch_duplicates(self):
        result = record_batch(self.path, [self.row, self.row])
        self.assertEqual(result['record_counts'], {'first_seen_review': 1, 'duplicate': 1})
        self.assertEqual(result['notification_eligible_count'], 0)

    def test_concurrent_reviewers_do_not_both_mark_new(self):
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(lambda _: record_batch(self.path, [self.row]), range(2)))
        self.assertEqual(sum(r['record_counts'].get('first_seen_review', 0) for r in results), 1)
        self.assertEqual(sum(r['record_counts'].get('duplicate', 0) for r in results), 1)

    def test_bad_api_response_does_not_touch_store(self):
        with patch('check_alert_api.record_batch') as writer:
            summarize(b'{"body":[{"SN":1}]}', state_db=self.path)
            summarize(b'{"header":{"resultCode":"32"}}', state_db=self.path)
            writer.assert_not_called()

    def test_persistence_failure_is_not_reported_as_success(self):
        raw = json.dumps({'body': [dict.fromkeys(FIELDS, 'synthetic')]}).encode()
        with patch('check_alert_api.record_batch', side_effect=ReviewStoreError('private-details')):
            result = summarize(raw, state_db=self.path)
        self.assertEqual(result['status'], 'review_store_error')
        self.assertNotIn('private-details', str(result))


if __name__ == '__main__':
    unittest.main()
