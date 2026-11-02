import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/screens/saved_shelters_screen.dart';
import 'package:safe_korea/services/saved_shelters_controller.dart';
import 'package:safe_korea/theme/app_theme.dart';

import 'map_and_saved_shelters_test.dart' show fixture, SavedMemoryStore;

void main() {
  testWidgets('saved summary prioritizes map and aligns name with address', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final saved = SavedSheltersController(store: SavedMemoryStore());
    await saved.load();
    final catalog = fixture('11110', '테스트 지역', 'a');
    await saved.toggle(catalog, 'a');
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: SavedSheltersScreen(controller: saved),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('온라인 지도 보기').hitTestable(), findsOneWidget);
    expect(find.text('공식 자료 다시 확인'), findsNothing);
    expect(find.text('기기 저장'), findsNothing);
    expect(
      tester.getTopLeft(find.text('테스트 시설 a')).dx,
      tester.getTopLeft(find.text('테스트 주소 a')).dx,
    );
    expect(find.text('개방 여부는 현장에서 확인하세요'), findsOneWidget);
    await tester.ensureVisible(find.text('조회·저장 정보'));
    await tester.tap(find.text('조회·저장 정보'));
    await tester.pumpAndSettle();
    expect(find.text('공식 자료 다시 확인'), findsOneWidget);
    expect(find.text('공식 출처 열기'), findsOneWidget);
    expect(find.text('저장 해제'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    saved.dispose();
  });
}
