"""In-memory development review only: no delivery, persistent cursor or active alerts."""
from collections import Counter
from datetime import datetime
import hashlib
import json
from review_alert_scope import normalized, review_record


class ReviewSession:
    def __init__(self, started_at, selected_region=None):
        if started_at.tzinfo is None or started_at.utcoffset() is None:
            raise ValueError('Review start requires an explicit timezone')
        self.started_at = started_at
        self.region = normalized(selected_region)
        self.seen = {}

    def inspect(self, row):
        decision = {'scope': review_record(row)['route'], 'record': 'invalid',
                    'time': 'unverified', 'region': 'unknown', 'notify': False}
        if not isinstance(row, dict):
            return decision
        serial = row.get('SN')
        if isinstance(serial, bool) or not isinstance(serial, (str, int)) or not str(serial).strip():
            return decision
        # No raw identifiers/messages retained in session state or emitted.
        identity = hashlib.sha256(str(serial).strip().encode()).hexdigest()
        fingerprint = hashlib.sha256(json.dumps(row, sort_keys=True, ensure_ascii=False).encode()).hexdigest()
        versions = self.seen.setdefault(identity, set())
        decision['record'] = ('duplicate' if fingerprint in versions else
                              'revision_review' if versions else 'first_seen_review')
        versions.add(fingerprint)
        try:
            created = datetime.fromisoformat(row['CRT_DT'])
            if created.tzinfo is not None and created.utcoffset() is not None:
                decision['time'] = ('baseline_before_review' if created <= self.started_at
                                    else 'after_review_start_unverified')
            # An unspecified timezone is not silently assumed to be KST.
        except (KeyError, TypeError, ValueError):
            pass
        target = normalized(row.get('RCPTN_RGN_NM'))
        if target == '전국':
            decision['region'] = 'national_label_unverified'
        elif not self.region:
            decision['region'] = 'user_region_unknown'
        elif target == self.region:
            decision['region'] = 'exact_label_match_unverified'
        elif target:
            decision['region'] = 'mapping_required'
        # No substring match (e.g. two cities' 중구), region hierarchy inference,
        # future-clock assumption, cancellation of other alerts, or sound.
        return decision


def summarize_delivery_review(rows, started_at):
    session = ReviewSession(started_at)
    decisions = [session.inspect(row) for row in rows]
    return {'mode': 'in_memory_review_only',
            'record_counts': dict(sorted(Counter(d['record'] for d in decisions).items())),
            'time_counts': dict(sorted(Counter(d['time'] for d in decisions).items())),
            'region_counts': dict(sorted(Counter(d['region'] for d in decisions).items())),
            'notification_eligible_count': 0}
