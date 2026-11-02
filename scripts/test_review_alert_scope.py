import unittest
from review_alert_scope import NON_CIVIL_TYPES, review_record, summarize_scope


def record(kind='민방공', message='공습경보 발령', level='위급재난'):
    return {'DST_SE_NM': kind, 'MSG_CN': message, 'EMRG_STEP_NM': level}


class ScopeReviewTests(unittest.TestCase):
    def test_civil_defense_is_only_a_review_candidate(self):
        for level in ('위급재난', '긴급재난', '안전안내'):
            d = review_record(record(level=level))
            self.assertEqual(d['route'], 'civil_defense_review')
            self.assertFalse(d['notify'])

    def test_documented_general_categories_are_excluded(self):
        for kind in NON_CIVIL_TYPES:
            with self.subTest(kind=kind):
                self.assertEqual(review_record(record(kind, '일반 안내'))['route'], 'excluded')

    def test_unknown_codes_and_missing_values_are_held(self):
        for r in [None, {}, record(kind='새 분류'), record(level='새 단계'), record(message='')]:
            self.assertEqual(review_record(r)['route'], 'hold_for_review')
        # Unverified numeric code cannot override an unknown name.
        r = record(kind=''); r['DST_SE_ID'] = 'TEST_CODE'
        self.assertEqual(review_record(r)['route'], 'hold_for_review')

    def test_keywords_do_not_override_official_category(self):
        for kind in ('호우', '기타', '테러', '폭발'):
            d = review_record(record(kind, '공습경보 관련 안내'))
            self.assertEqual(d['route'], 'hold_for_review')
            self.assertFalse(d['notify'])

    def test_drill_correction_and_release_hints_coexist(self):
        d = review_record(record(message='훈련 공습경보 오발령 정정 및 해제 안내'))
        self.assertEqual(d['hints'], ['air_raid', 'correction', 'drill', 'release_or_cancel'])
        self.assertFalse(d['notify'])

    def test_negation_and_future_text_never_trigger_state_changes(self):
        for message in ('훈련이 아닙니다. 공습경보', '경보 해제 아님', '내일 공습 훈련 예정',
                        '경계경보 취소 안내', '화생방 경보', '전쟁 관련 안내'):
            d = review_record(record(message=message))
            self.assertEqual(d['route'], 'civil_defense_review')
            self.assertFalse(d['notify'])
            self.assertNotIn('active', d)

    def test_summary_never_leaks_original_data(self):
        rows = [record(message='공습 private-text'), record('호우', 'private-location'), {}]
        result = summarize_scope(rows)
        self.assertEqual(result['notification_eligible_count'], 0)
        self.assertEqual(result['route_counts'], {'civil_defense_review': 1, 'excluded': 1, 'hold_for_review': 1})
        self.assertNotIn('private', str(result))

    def test_whitespace_is_normalized_but_not_fuzzy_matched(self):
        self.assertEqual(review_record(record(' 민방공\n'))['route'], 'civil_defense_review')
        self.assertEqual(review_record(record('민방공 유사분류'))['route'], 'hold_for_review')


if __name__ == '__main__':
    unittest.main()
