import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safe_korea/main.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('preview evacuation-first drill', (tester) async {
    await tester.pumpWidget(const SafeKoreaApp());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('모의 공습경보 시작'));
    await tester.tap(find.text('모의 공습경보 시작'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('drill');
    expect(find.text('대피시설 확인').hitTestable(), findsOneWidget);
    expect(find.text('준비된 배낭만 챙기세요').hitTestable(), findsOneWidget);
    expect(find.text('물 · 간편식 · 상비약'), findsNothing);
    await tester.ensureVisible(find.text('챙길 것 보기'));
    await tester.tap(find.text('챙길 것 보기'));
    await tester.pumpAndSettle();
    expect(find.text('물 · 간편식 · 상비약'), findsOneWidget);
    await tester.ensureVisible(find.text('행동요령 보기'));
    await tester.tap(find.text('행동요령 보기'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('연습 체크 · 선택 사항'));
    await tester.tap(find.text('연습 체크 · 선택 사항'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('정부 안내를 확인하는 방법을 익혔어요'));
    await binding.takeScreenshot('drill-details');
    await tester.tap(find.text('훈련 종료 · 홈으로'));
    await tester.pumpAndSettle();
    expect(find.text('모의 공습경보 시작'), findsOneWidget);
  });
}
