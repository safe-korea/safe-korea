import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/services/local_store.dart';
import 'package:safe_korea/services/meeting_share.dart';
import 'package:safe_korea/screens/meeting_share_screen.dart';
import 'package:safe_korea/screens/family_screen.dart';

import 'local_store_test.dart' show MemoryStore;

const plan = FamilyPlan(
  contactName: 'hidden-person',
  phone: 'hidden-phone',
  backupContactName: 'hidden-backup',
  backupPhone: 'hidden-number',
  meetingPlace: '첫 장소',
  meetingPoint: MeetingPoint(37.5665, 126.978),
  backupPlace: '대체 장소',
  note: '개인 약속',
);

void main() {
  test('share text includes only meeting fields and optional note', () {
    final text = buildMeetingShareText(plan);
    expect(text, contains('첫 장소'));
    expect(
      text,
      contains('https://map.kakao.com/link/map/37.566500,126.978000'),
    );
    expect(text, contains('대체 장소: 대체 장소\n지도 위치 미지정'));
    expect(text, isNot(contains('hidden-')));
    expect(text, isNot(contains('개인 약속')));
    expect(buildMeetingShareText(plan, includeNote: true), contains('개인 약속'));
    expect(canShareMeetingPlan(const FamilyPlan(note: '메모만')), false);
    expect(
      buildMeetingShareText(
        const FamilyPlan(meetingPoint: MeetingPoint(99, 127)),
      ),
      isNot(contains('mlat=')),
    );
  });
  testWidgets(
    'sharing is explicit, previews note selection, supplies popover anchor',
    (tester) async {
      String? sent;
      Rect? anchor;
      await tester.pumpWidget(
        MaterialApp(
          home: MeetingShareScreen(
            plan: plan,
            shareText: (text, origin) async {
              sent = text;
              anchor = origin;
            },
          ),
        ),
      );
      expect(sent, isNull);
      expect(find.textContaining('개인 약속'), findsNothing);
      await tester.tap(find.text('가족 약속도 포함'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('카카오톡 등으로 공유'));
      await tester.tap(find.text('카카오톡 등으로 공유'));
      await tester.pumpAndSettle();
      expect(sent, contains('개인 약속'));
      expect(sent, isNot(contains('hidden-')));
      expect(anchor!.width, greaterThan(0));
      expect(anchor!.height, greaterThan(0));
      expect(find.textContaining('도착 여부를 확인할 수 없습니다'), findsOneWidget);
    },
  );
  testWidgets('compact preview hides raw links until expanded', (tester) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: MeetingShareScreen(plan: plan)),
    );
    expect(find.text('지도 링크 포함'), findsOneWidget);
    expect(find.textContaining('https://'), findsNothing);
    expect(tester.getBottomRight(find.text('카카오톡 등으로 공유')).dy, lessThan(874));
    await tester.ensureVisible(find.text('전송 내용 전체 보기'));
    await tester.tap(find.text('전송 내용 전체 보기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('https://'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('share failure keeps copy fallback available', (tester) async {
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = call.arguments['text'] as String;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MeetingShareScreen(
          plan: plan,
          shareText: (_, _) async =>
              throw PlatformException(code: 'unavailable'),
        ),
      ),
    );
    await tester.ensureVisible(find.text('카카오톡 등으로 공유'));
    await tester.tap(find.text('카카오톡 등으로 공유'));
    await tester.pumpAndSettle();
    expect(find.textContaining('공유 창을 열지 못했습니다'), findsOneWidget);
    await tester.ensureVisible(find.text('내용 복사'));
    await tester.tap(find.text('내용 복사'));
    await tester.pumpAndSettle();
    expect(copied, buildMeetingShareText(plan));
  });
  testWidgets(
    'empty family plan still shows share action with an explanation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(402, 874));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(home: FamilyScreen(store: MemoryStore())),
      );
      await tester.pumpAndSettle();
      final button = find.widgetWithText(FilledButton, '가족에게 공유');
      expect(button.hitTestable(), findsOneWidget);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(find.text('장소를 하나 저장하면 공유할 수 있어요.'), findsOneWidget);
      expect(find.text('기기에 저장').hitTestable(), findsOneWidget);
      await tester.ensureVisible(find.text('저장·보관 안내'));
      expect(find.text('기기에 저장').hitTestable(), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('family-field-2')),
        '새 장소',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('기기에 저장'));
      await tester.tap(find.text('기기에 저장'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      expect(button.hitTestable(), findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(MeetingShareScreen), findsOneWidget);
      expect(find.text('새 장소'), findsOneWidget);
    },
  );
  testWidgets('long saved note does not push family sharing off screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = MemoryStore()
      ..plan = FamilyPlan(meetingPlace: '첫 장소', note: '긴 약속 ' * 100);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: FamilyScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('가족에게 공유').hitTestable(), findsOneWidget);
    expect(find.textContaining('긴 약속'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('unsaved edits cannot share a stale saved snapshot', (
    tester,
  ) async {
    final store = MemoryStore()..plan = plan;
    await tester.pumpWidget(MaterialApp(home: FamilyScreen(store: store)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('만남 장소 수정'));
    await tester.tap(find.text('만남 장소 수정'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('family-field-2')),
      '수정 중',
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '가족에게 공유'))
          .onPressed,
      isNull,
    );
    expect(find.text('수정한 내용을 먼저 저장한 뒤 공유하세요.'), findsOneWidget);
  });
}
