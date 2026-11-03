import 'dart:async';

import '../models/alert_guidance.dart';

/// Normalized response notice. Official notices require authenticated upstream,
/// resolved codes, drill status, timestamps and recipient regions.
/// Explicit own-device previews use a separate test-only entry point.
/// This value object does not authenticate arbitrary JSON or push payloads.
class CivilAlertNotice {
  const CivilAlertNotice({
    required this.id,
    required this.revision,
    required this.kind,
    required this.issuedAt,
    required this.expiresAt,
    required this.agency,
    required this.area,
    this.exercise = false,
    this.testOnly = false,
    this.relatedAlertId,
  });
  final String id, revision, agency, area;
  final AlertKind kind;
  final DateTime issuedAt, expiresAt;
  final bool exercise, testOnly;
  final String? relatedAlertId;
  bool freshAt(DateTime now) =>
      id.isNotEmpty &&
      revision.isNotEmpty &&
      agency.trim().isNotEmpty &&
      area.trim().isNotEmpty &&
      !exercise &&
      !issuedAt.isBefore(now.subtract(const Duration(minutes: 10))) &&
      expiresAt.isAfter(issuedAt) &&
      expiresAt.isAfter(now) &&
      !issuedAt.isAfter(now.add(const Duration(seconds: 30)));
}

/// Transport-neutral app ingress. Optional Android system relay is experimental;
/// web push uses an authenticated same-origin lookup before this ingress.
/// Never call this with a review candidate, URL parameter or unverified push.
class CivilAlertIngress {
  CivilAlertIngress({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  static final shared = CivilAlertIngress();
  final DateTime Function() _clock;
  final _events = StreamController<CivilAlertNotice>.broadcast();
  final Set<String> _seen = {};
  CivilAlertNotice? _current;
  Stream<CivilAlertNotice> get notices => _events.stream;
  CivilAlertNotice? get latestAccepted => _current;
  bool accept(
    CivilAlertNotice notice, {
    required bool sourceAuthenticated,
    required bool recipientMatched,
  }) {
    if (notice.testOnly ||
        !sourceAuthenticated ||
        !recipientMatched ||
        !notice.freshAt(_clock())) {
      return false;
    }
    if (notice.kind == AlertKind.release &&
        (notice.relatedAlertId == null ||
            notice.relatedAlertId != _current?.id)) {
      return false;
    }
    return _publish(notice);
  }

  /// Explicit own-device preview. Never upgrades a test into an official notice.
  bool acceptResponseTest({
    required String id,
    required AlertKind kind,
    required DateTime issuedAt,
    required DateTime expiresAt,
  }) {
    final now = _clock();
    if (id.isEmpty ||
        expiresAt.difference(issuedAt) > const Duration(minutes: 2) ||
        (_current != null && !_current!.testOnly && _current!.freshAt(now))) {
      return false;
    }
    final notice = CivilAlertNotice(
      id: 'response-test/$id',
      revision: 'test',
      kind: kind,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      agency: '사용자가 요청한 테스트 알림',
      area: '이 기기에서만 진행하는 화면 연결 테스트',
      testOnly: true,
    );
    if (!notice.freshAt(now)) return false;
    return _publish(notice);
  }

  bool _publish(CivilAlertNotice notice) {
    final key = '${notice.id}/${notice.revision}';
    // A user may reopen the same short-lived test from the notification center.
    // Official notices remain deduplicated.
    if (!_seen.add(key) && !notice.testOnly) return false;
    if (_seen.length > 256) _seen.remove(_seen.first);
    _current = notice;
    _events.add(notice);
    return true;
  }

  Future<void> dispose() => _events.close();
}
