"""Development-only review routing; never an alert classifier or sender.

Names follow the DSSP-IF-00247 public schema. Numeric ID mappings and
war-alert semantics remain unverified. Text hints are review aids only.
"""
from collections import Counter
import unicodedata

NON_CIVIL_TYPES = frozenset(('AI 가뭄 가축질병 강풍 건조 교통 교통사고 교통통제 금융 기타 '
                            '대설 미세먼지 붕괴 산불 산사태 수도 안개 에너지 전염병 정전 '
                            '지진 지진해일 태풍 테러 통신 폭발 폭염 풍랑 한파 호우 홍수 '
                            '화재 환경오염사고 황사').split())
LEVELS = frozenset(('위급재난', '긴급재난', '안전안내'))
HINTS = {
    'drill': ('훈련', '연습', '테스트', 'civil defense exercise',
              'civil defence exercise', 'civil defense drill', 'civil defence drill'),
    'correction': ('정정', '오발령', '오 발령', '잘못 발령'),
    'release_or_cancel': ('해제', '취소', '종료'),
    'air_raid': ('공습',),
    'watch': ('경계경보', '경계 경보'),
    'cbrn': ('화생방', '화학공격', '화학 공격', '생물학공격', '생물학 공격'),
    'chemical': ('화학공격', '화학 공격'),
    'biological': ('생물학공격', '생물학 공격'),
    'nuclear': ('핵경보', '핵 경보', '핵공격', '핵 공격', '핵폭발', '핵 폭발', '핵 상황'),
    'war': ('전쟁', '전시상황', '전시 상황'),
}


def normalized(value):
    return ' '.join(unicodedata.normalize('NFKC', value).split()) if isinstance(value, str) else ''


def review_record(record):
    """Return fixed labels only: no message, location, identifiers or secrets."""
    result = {'route': 'hold_for_review', 'reason': 'invalid_record',
              'hints': [], 'review_flags': [], 'notify': False}
    if not isinstance(record, dict):
        return result
    kind = normalized(record.get('DST_SE_NM'))
    level = normalized(record.get('EMRG_STEP_NM'))
    message = normalized(record.get('MSG_CN'))
    if not kind or not level or not message:
        return result
    hints = sorted(name for name, words in HINTS.items() if any(word.casefold() in message.casefold() for word in words))
    result['hints'] = hints
    flags = []
    if 'drill' in hints:
        flags.append('drill_context_requires_review')
    if 'correction' in hints:
        flags.append('correction_requires_original_link')
    if 'release_or_cancel' in hints:
        flags.append('release_requires_original_link')
        if kind == '민방공' and level != '안전안내':
            flags.append('release_channel_requires_review')
    if any(word in message for word in ('아님', '아닙니다', '예정', '내일', '예시', '표준 문안')):
        flags.append('negated_or_reference_context')
    result['review_flags'] = sorted(flags)
    if level not in LEVELS:
        result['reason'] = 'unknown_emergency_level'
    elif kind == '민방공':
        result.update(route='civil_defense_review', reason='official_name_candidate_only')
    elif kind in NON_CIVIL_TYPES and not hints:
        result.update(route='excluded', reason='outside_civil_defense_scope')
    elif kind in NON_CIVIL_TYPES:
        result['reason'] = 'text_category_conflict'
    else:
        result['reason'] = 'unknown_disaster_category'
    # A drill/release word may be negated, quoted, or refer to a future event.
    # Never infer current state, cancel an alert, or sound a siren here.
    return result


def summarize_scope(records):
    decisions = [review_record(record) for record in records]
    return {'mode': 'review_only',
            'route_counts': dict(sorted(Counter(d['route'] for d in decisions).items())),
            'hint_counts': dict(sorted(Counter(h for d in decisions for h in d['hints']).items())),
            'review_flag_counts': dict(sorted(Counter(
                flag for d in decisions for flag in d['review_flags']).items())),
            'notification_eligible_count': 0,
            'official_code_mapping_verified': False}
