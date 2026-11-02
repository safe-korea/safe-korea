from datetime import datetime, timezone
import unittest
from review_alert_delivery import ReviewSession, summarize_delivery_review

START = datetime(2026, 11, 2, tzinfo=timezone.utc)


def row(**changes):
    result = {'SN': 'synthetic-id', 'DST_SE_NM': '민방공', 'EMRG_STEP_NM': '위급재난',
              'MSG_CN': '합성 공습경보', 'CRT_DT': '2026-11-02T08:59:00+09:00',
              'RCPTN_RGN_NM': '서울특별시 중구', 'MDFCN_YMD': 'synthetic-version'}
    result.update(changes)
    return result


class DeliveryReviewTests(unittest.TestCase):
    def test_duplicate_revision_and_old_version_replay(self):
        session = ReviewSession(START)
        original = row()
        changed = row(MSG_CN='합성 정정 안내')
        self.assertEqual(session.inspect(original)['record'], 'first_seen_review')
        self.assertEqual(session.inspect(original)['record'], 'duplicate')
        self.assertEqual(session.inspect(changed)['record'], 'revision_review')
        self.assertEqual(session.inspect(original)['record'], 'duplicate')
        self.assertNotIn('synthetic-id', str(session.seen))
        self.assertNotIn('합성', str(session.seen))

    def test_old_and_future_are_never_live(self):
        session = ReviewSession(START)
        self.assertEqual(session.inspect(row())['time'], 'baseline_before_review')
        result = session.inspect(row(CRT_DT='2099-01-01T00:00:00+09:00'))
        self.assertEqual(result['time'], 'after_review_start_unverified')
        self.assertFalse(result['notify'])

    def test_missing_timezone_invalid_time_and_start(self):
        for value in [None, '', '2026-11-02 09:00:00', 'invalid']:
            self.assertEqual(ReviewSession(START).inspect(row(CRT_DT=value))['time'], 'unverified')
        with self.assertRaises(ValueError):
            ReviewSession(datetime(2026, 11, 2))

    def test_unknown_user_region_never_becomes_nationwide(self):
        result = ReviewSession(START).inspect(row())
        self.assertEqual(result['region'], 'user_region_unknown')
        self.assertFalse(result['notify'])

    def test_equal_district_names_do_not_match_across_cities(self):
        session = ReviewSession(START, '서울특별시 중구')
        self.assertEqual(session.inspect(row())['region'], 'exact_label_match_unverified')
        for target in ['부산광역시 중구', '중구', '서울특별시', '서울특별시 중구, 부산광역시 중구']:
            self.assertEqual(session.inspect(row(RCPTN_RGN_NM=target))['region'], 'mapping_required')

    def test_nationwide_requires_field_not_body_and_still_needs_verification(self):
        session = ReviewSession(START)
        self.assertEqual(session.inspect(row(MSG_CN='전국 경보 설명'))['region'], 'user_region_unknown')
        self.assertEqual(session.inspect(row(RCPTN_RGN_NM='전국'))['region'], 'national_label_unverified')

    def test_release_never_closes_other_records(self):
        session = ReviewSession(START)
        session.inspect(row())
        result = session.inspect(row(SN='other-synthetic', MSG_CN='합성 경보 해제'))
        self.assertEqual(result['record'], 'first_seen_review')
        self.assertEqual(len(session.seen), 2)
        self.assertFalse(result['notify'])

    def test_invalid_identity_and_summary_no_private_data(self):
        for value in [None, '', False, {}]:
            self.assertEqual(ReviewSession(START).inspect(row(SN=value))['record'], 'invalid')
        summary = summarize_delivery_review([row(), row()], START)
        self.assertEqual(summary['record_counts']['duplicate'], 1)
        self.assertNotIn('서울', str(summary))
        self.assertEqual(summary['notification_eligible_count'], 0)


if __name__ == '__main__':
    unittest.main()
