import 'dart:async';

import '../models/alert_guidance.dart';

/// Normalized notice produced AFTER authenticating the official upstream and
/// resolving its codes, drill status, timestamps and recipient regions.
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
    this.relatedAlertId,
  });
  final String id, revision, agency, area;
  final AlertKind kind;
  final DateTime issuedAt, expiresAt;
  final bool exercise;
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
/// no government-server push transport is configured.
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
    if (!sourceAuthenticated ||
        !recipientMatched ||
        !notice.freshAt(_clock())) {
      return false;
    }
    if (notice.kind == AlertKind.release &&
        (notice.relatedAlertId == null ||
            notice.relatedAlertId != _current?.id)) {
      return false;
    }
    final key = '${notice.id}/${notice.revision}';
    if (!_seen.add(key)) return false;
    if (_seen.length > 256) _seen.remove(_seen.first);
    _current = notice;
    _events.add(notice);
    return true;
  }

  Future<void> dispose() => _events.close();
}
