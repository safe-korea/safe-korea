"""Synthetic replay of four contexts observed in the official API.

No source message, region, serial or timestamp is embedded. The API sample
was training-related, not evidence of real attack or cancellation handling.
"""
from datetime import datetime, timezone
from pathlib import Path
import tempfile
import unittest
from alert_review_store import record_batch
from review_alert_delivery import ReviewSession
from review_alert_scope import review_record, summarize_scope


def synthetic_training_rows():
    texts = [
        '합성 안내: 민방위훈련 참여 안내 (Civil Defense Exercise)',
        '합성 상황: 훈련 공습경보 발령 안내',
        '합성 상황: 훈련 경계경보 발령 안내',
        '합성 상황: 훈련경보 해제 안내',
    ]
    return [{'SN': f'synthetic-training-{i}', 'MSG_CN': text,
             'DST_SE_NM': '민방공', 'EMRG_STEP_NM': '안전안내',
             'CRT_DT': '2000-01-01T00:00:00+09:00',
             'RCPTN_RGN_NM': '합성 지역'} for i, text in enumerate(texts)]


class TrainingReplayTests(unittest.TestCase):
    def test_four_observed_contexts_are_not_actual_alerts(self):
        rows = synthetic_training_rows()
        for row in rows:
            decision = review_record(row)
            self.assertIn('drill', decision['hints'])
            self.assertIn('drill_context_requires_review', decision['review_flags'])
            self.assertEqual(decision['route'], 'civil_defense_review')
            self.assertFalse(decision['notify'])
        summary = summarize_scope(rows)
        self.assertEqual(summary['hint_counts']['drill'], 4)
        self.assertEqual(summary['hint_counts']['air_raid'], 1)
        self.assertEqual(summary['hint_counts']['watch'], 1)
        self.assertEqual(summary['hint_counts']['release_or_cancel'], 1)
        self.assertEqual(summary['notification_eligible_count'], 0)

    def test_english_only_training_and_capitalization(self):
        for text in ('CIVIL DEFENSE EXERCISE', 'Civil Defence Exercise',
                     'civil defense drill', 'Civil Defence Drill'):
            row = synthetic_training_rows()[0]
            row['MSG_CN'] = text
            self.assertIn('drill', review_record(row)['hints'])
            self.assertFalse(review_record(row)['notify'])

    def test_ordinary_exercise_word_is_not_a_civil_defense_phrase(self):
        row = synthetic_training_rows()[0]
        row['MSG_CN'] = 'Exercise caution on wet roads'
        self.assertNotIn('drill', review_record(row)['hints'])
        self.assertFalse(review_record(row)['notify'])

    def test_negated_training_does_not_become_a_confirmed_training_state(self):
        row = synthetic_training_rows()[0]
        row['MSG_CN'] = '훈련이 아닙니다. 공습경보 발령'
        result = review_record(row)
        self.assertIn('drill_context_requires_review', result['review_flags'])
        self.assertIn('negated_or_reference_context', result['review_flags'])
        self.assertNotIn('is_training', result)
        self.assertFalse(result['notify'])

    def test_reordered_restart_and_revision_replay(self):
        rows = synthetic_training_rows()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'review.sqlite'
            self.assertEqual(record_batch(path, rows)['record_counts'], {'first_seen_review': 4})
            self.assertEqual(record_batch(path, list(reversed(rows)))['record_counts'], {'duplicate': 4})
            corrected = dict(rows[1], MSG_CN='합성 정정: 훈련 공습경보 안내 정정')
            result = record_batch(path, [corrected, rows[1]])
            self.assertEqual(result['record_counts'], {'duplicate': 1, 'revision_review': 1})
            self.assertEqual(result['notification_eligible_count'], 0)

    def test_training_release_cannot_close_other_alerts(self):
        session = ReviewSession(datetime(2026, 11, 2, tzinfo=timezone.utc))
        unrelated = dict(synthetic_training_rows()[0], SN='other-synthetic', MSG_CN='합성 공습경보')
        session.inspect(unrelated)
        for row in synthetic_training_rows():
            decision = session.inspect(row)
            self.assertEqual(decision['time'], 'baseline_before_review')
            self.assertFalse(decision['notify'])
        self.assertEqual(len(session.seen), 5)
        self.assertEqual(session.inspect(unrelated)['record'], 'duplicate')


if __name__ == '__main__':
    unittest.main()
