"""Synthetic cases derived from official civil-defense message structures.
Source: law.go.kr/LSW/flDownload.do?bylClsCd=200201&flSeq=152590231
These are NOT captured alerts or proof of numeric API code mappings.
"""
import unittest
from review_alert_scope import review_record, summarize_scope


def review(message, level='위급재난', category='민방공'):
    return review_record({'MSG_CN': message, 'EMRG_STEP_NM': level, 'DST_SE_NM': category})


class OfficialMessageScenarioTests(unittest.TestCase):
    def test_attack_variants_remain_review_only(self):
        cases = [
            ('[합성 사례] 항공기 상황, 가상지역 경계경보', {'watch'}),
            ('[합성 사례] 미사일 상황, 가상지역 경계 경보', {'watch'}),
            ('[합성 사례] 항공기 상황, 가상지역 공습경보', {'air_raid'}),
            ('[합성 사례] 미사일 상황, 가상지역 공습경보', {'air_raid'}),
            ('[합성 사례] 포격 상황, 가상지역 공습경보', {'air_raid'}),
            ('[합성 사례] 생물학 공격, 가상지역 화생방 경보', {'biological', 'cbrn'}),
            ('[합성 사례] 화학 공격, 가상지역 화생방경보', {'chemical', 'cbrn'}),
            ('[합성 사례] 핵 폭발, 가상지역 핵 경보', {'nuclear'}),
        ]
        for message, hints in cases:
            with self.subTest(message=message):
                result = review(message)
                self.assertTrue(hints <= set(result['hints']))
                self.assertEqual(result['route'], 'civil_defense_review')
                self.assertFalse(result['notify'])

    def test_nuclear_and_chemical_are_not_collapsed(self):
        result = review('[합성 사례] 핵 경보')
        self.assertIn('nuclear', result['hints'])
        self.assertNotIn('chemical', result['hints'])
        self.assertNotIn('cbrn', result['hints'])

    def test_safety_channel_release_is_not_discarded(self):
        for kind in ('경계', '공습', '화생방', '핵'):
            result = review(f'[합성 사례] 가상지역 {kind} 경보 해제', '안전안내')
            self.assertEqual(result['route'], 'civil_defense_review')
            self.assertIn('release_requires_original_link', result['review_flags'])
            self.assertNotIn('release_channel_requires_review', result['review_flags'])
            self.assertFalse(result['notify'])

    def test_unexpected_release_channel_is_flagged_not_dropped(self):
        result = review('[합성 사례] 공습경보 해제', '위급재난')
        self.assertIn('release_channel_requires_review', result['review_flags'])
        self.assertEqual(result['route'], 'civil_defense_review')

    def test_drill_and_correction_can_coexist_with_release(self):
        result = review('[합성 사례] 훈련 공습경보 오발령 정정, 해제', '안전안내')
        for flag in ('drill_context_requires_review', 'correction_requires_original_link',
                     'release_requires_original_link'):
            self.assertIn(flag, result['review_flags'])
        self.assertFalse(result['notify'])

    def test_negation_and_reference_are_not_actual_alerts(self):
        for message in ('공습경보 아님', '실제 핵 경보가 아닙니다', '내일 훈련 예정',
                        '공습경보 표준 문안', '경보해제 예시'):
            result = review(message)
            self.assertIn('negated_or_reference_context', result['review_flags'])
            self.assertFalse(result['notify'])

    def test_weather_safety_messages_are_not_civil_defense(self):
        for message in ('호우 안내', '호우 경보 해제'):
            result = review(message, '안전안내', '호우')
            self.assertNotEqual(result['route'], 'civil_defense_review')
            self.assertFalse(result['notify'])

    def test_summary_emits_fixed_flags_only(self):
        rows = [{'MSG_CN': 'private-name 공습경보 해제 예시',
                 'EMRG_STEP_NM': '안전안내', 'DST_SE_NM': '민방공'}]
        result = summarize_scope(rows)
        self.assertEqual(result['review_flag_counts']['release_requires_original_link'], 1)
        self.assertNotIn('private-name', str(result))


if __name__ == '__main__':
    unittest.main()
