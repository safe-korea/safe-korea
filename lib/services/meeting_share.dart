import 'local_store.dart';

bool canShareMeetingPlan(FamilyPlan plan) =>
    plan.meetingPlace.trim().isNotEmpty ||
    plan.backupPlace.trim().isNotEmpty ||
    (plan.meetingPoint?.isValid ?? false) ||
    (plan.backupPoint?.isValid ?? false);

/// Only explicit meeting fields; legacy contacts are never serialized here.
String buildMeetingShareText(FamilyPlan plan, {bool includeNote = false}) {
  final lines = <String>['[safeKor] 가족 만남 장소', '통신이 끊기면 만날 장소를 미리 정해 둡니다.'];
  void addPlace(String title, String name, MeetingPoint? point) {
    if (name.trim().isEmpty && !(point?.isValid ?? false)) return;
    lines.add('\n$title: ${name.trim().isEmpty ? "지도에 지정한 장소" : name.trim()}');
    if (point?.isValid ?? false) {
      final latitude = point!.latitude.toStringAsFixed(6);
      final longitude = point.longitude.toStringAsFixed(6);
      lines.add('지도: https://map.kakao.com/link/map/$latitude,$longitude');
    } else {
      lines.add('지도 위치 미지정');
    }
  }

  addPlace('첫 번째 장소', plan.meetingPlace, plan.meetingPoint);
  addPlace('대체 장소', plan.backupPlace, plan.backupPoint);
  if (includeNote && plan.note.trim().isNotEmpty) {
    lines.add('\n가족 약속: ${plan.note.trim()}');
  }
  lines.add('\n사전 약속이며 실제 대피 상태나 장소의 안전을 알리는 메시지는 아닙니다.');
  return lines.join('\n');
}
