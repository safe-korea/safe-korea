import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/main.dart';
import 'package:safe_korea/screens/civil_alert_screen.dart';
import 'package:flutter/material.dart';
import 'package:safe_korea/models/alert_guidance.dart';
import 'package:safe_korea/services/civil_alert_ingress.dart';

CivilAlertNotice notice(
  DateTime now, {
  String revision = '1',
  AlertKind kind = AlertKind.air,
  bool exercise = false,
  String? related,
}) => CivilAlertNotice(
  id: 'synthetic-test-only',
  revision: revision,
  kind: kind,
  issuedAt: now,
  expiresAt: now.add(const Duration(minutes: 2)),
  agency: '합성 검증 자료 · 실제 발령 아님',
  area: '합성 테스트 지역',
  exercise: exercise,
  relatedAlertId: related,
);
void main() {
  test('ingress rejects unauthenticated, other recipients, drills, stale/future and repeats', () async {
    final now = DateTime.utc(2026, 11, 2, 12);
    final ingress = CivilAlertIngress(clock: () => now);
    addTearDown(ingress.dispose);
    expect(
      ingress.accept(
        notice(now),
        sourceAuthenticated: false,
        recipientMatched: true,
      ),
      false,
    );
    expect(
      ingress.accept(
        notice(now),
        sourceAuthenticated: true,
        recipientMatched: false,
      ),
      false,
    );
    expect(
      ingress.accept(
        notice(now, exercise: true),
        sourceAuthenticated: true,
        recipientMatched: true,
      ),
      false,
    );
    expect(
      ingress.accept(
        notice(now.subtract(const Duration(minutes: 20))),
        sourceAuthenticated: true,
        recipientMatched: true,
      ),
      false,
    );
    expect(
      ingress.accept(
        notice(now.add(const Duration(minutes: 2))),
        sourceAuthenticated: true,
        recipientMatched: true,
      ),
      false,
    );
    expect(
      ingress.accept(
        notice(now, kind: AlertKind.release),
        sourceAuthenticated: true,
        recipientMatched: true,
      ),
      false,
    );
    expect(
      ingress.accept(
        notice(now),
        sourceAuthenticated: true,
        recipientMatched: true,
      ),
      true,
    );
    expect(
      ingress.accept(
        notice(now),
        sourceAuthenticated: true,
        recipientMatched: true,
      ),
      false,
    );
    expect(
      ingress.accept(
        notice(now, revision: '2'),
        sourceAuthenticated: true,
        recipientMatched: true,
      ),
      true,
    );
  });
  testWidgets(
    'accepted notice automatically opens response UI without a drill entry',
    (tester) async {
      final ingress = CivilAlertIngress();
      addTearDown(ingress.dispose);
      await tester.pumpWidget(
        SafeKoreaApp(officialAlertEvents: ingress.notices),
      );
      await tester.pumpAndSettle();
      expect(find.text('지금 필요한 안내'), findsOneWidget);
      ingress.accept(
        notice(DateTime.now()),
        sourceAuthenticated: true,
        recipientMatched: true,
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('지금 즉시 대피하세요'), findsOneWidget);
      expect(find.text('훈련 / 테스트'), findsNothing);
      await tester.tap(find.text('실내'));
      await tester.pumpAndSettle();
      expect(find.text('계단으로 이동'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'received CBRN notice lets user follow the announced attack type',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CivilAlertScreen(
            notice: notice(DateTime.now(), kind: AlertKind.cbrn),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final chemical = find.text('화학 공격 안내');
      await tester.ensureVisible(chemical);
      await tester.tap(chemical);
      await tester.pumpAndSettle();
      expect(find.text('무조건 지하로 가지 마세요'), findsOneWidget);
      expect(find.text('공격 종류 다시 확인'), findsOneWidget);
      await tester.tap(find.text('공격 종류 다시 확인'));
      await tester.pumpAndSettle();
      expect(find.text('생물학 공격 안내'), findsOneWidget);
    },
  );
}
