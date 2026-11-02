import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/services/action_speech.dart';
import 'package:safe_korea/widgets/action_speech_button.dart';
import 'package:safe_korea/screens/status_share_screen.dart';
import 'package:safe_korea/screens/after_arrival_screen.dart';

class SpeechSpy extends ActionSpeech {
  final spoken = <String>[];
  int stops = 0;
  bool fail = false;
  Completer<void>? pending;
  @override
  Future<void> speak(String text) async {
    if (fail) throw StateError('no voice');
    spoken.add(text);
    pending = Completer<void>();
    await pending!.future;
  }

  @override
  Future<void> stop() async {
    stops++;
    if (pending != null && !pending!.isCompleted) pending!.complete();
  }
}

void main() {
  test(
    'failed native voice selection never speaks in a fallback voice',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final calls = <String>[];
      const channel = MethodChannel('flutter_tts');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            if (call.method == 'getVoices') {
              return [
                {'name': 'test', 'locale': 'ko-KR', 'network_required': '0'},
              ];
            }
            if (call.method == 'setVoice') return 0;
            return 1;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await expectLater(ActionSpeech().speak('안내'), throwsStateError);
      expect(calls, isNot(contains('speak')));
    },
  );
  testWidgets(
    'read aloud never autoplays, stops on changed instructions and leaving page',
    (tester) async {
      final speech = SpeechSpy();
      Future<void> mount(String text) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionSpeechButton(text: text, speech: speech),
          ),
        ),
      );
      await mount('실내 안내');
      expect(speech.spoken, isEmpty);
      await tester.tap(find.text('행동요령 읽어주기'));
      await tester.pump();
      expect(speech.spoken, ['실내 안내']);
      expect(find.text('읽기 중지'), findsOneWidget);
      await mount('실외 안내');
      await tester.pumpAndSettle();
      expect(speech.stops, greaterThan(0));
      expect(find.text('행동요령 읽어주기'), findsOneWidget);
      await tester.tap(find.text('행동요령 읽어주기'));
      await tester.pump();
      final stops = speech.stops;
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(speech.stops, greaterThan(stops));
    },
  );
  testWidgets('missing voice shows text fallback without starting sound', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ActionSpeechButton(text: '안내', speech: SpeechSpy()..fail = true),
      ),
    );
    await tester.tap(find.text('행동요령 읽어주기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('화면 안내를 읽어 주세요'), findsOneWidget);
    expect(find.text('읽기 중지'), findsNothing);
  });
  testWidgets(
    'manual status requires selection and explicit share, with training label and no automatic GPS',
    (tester) async {
      final sent = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: StatusShareScreen(
            training: true,
            shareText: (text, _) async => sent.add(text),
          ),
        ),
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text('이 장소에 도착했습니다.'));
      await tester.enterText(find.byType(TextField), '직접 확인한 장소');
      await tester.pumpAndSettle();
      expect(sent, isEmpty);
      await tester.ensureVisible(find.text('확인하고 공유 앱 열기'));
      await tester.tap(find.text('확인하고 공유 앱 열기'));
      await tester.pumpAndSettle();
      expect(sent.single, contains('[훈련 / 테스트] 실제 상황이 아닙니다.'));
      expect(sent.single, contains('장소: 직접 확인한 장소'));
      expect(sent.single, contains('안전 여부는 앱에서 확인하지 않습니다'));
      expect(find.text('전송 여부는 선택한 앱에서 확인하세요.'), findsOneWidget);
    },
  );
  testWidgets(
    'post arrival flow never declares safety or removes training context',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AfterArrivalScreen(training: true)),
      );
      expect(find.textContaining('안전이 확인된 것은 아니에요'), findsOneWidget);
      await tester.ensureVisible(find.text('가족에게 내 상태 알리기'));
      await tester.tap(find.text('가족에게 내 상태 알리기'));
      await tester.pumpAndSettle();
      expect(find.text('훈련 · 내 상태 공유'), findsOneWidget);
    },
  );
}
