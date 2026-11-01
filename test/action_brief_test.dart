import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/models/alert_guidance.dart';
import 'package:safe_korea/widgets/action_brief.dart';
import 'package:safe_korea/widgets/alert_actions.dart';
import 'package:safe_korea/theme/app_theme.dart';

void main() {
  test('briefs keep conditions that change the action', () {
    for (final kind in AlertKind.values) {
      for (final setting in UserSetting.values) {
        final briefs = actionBriefs(kind, setting);
        expect(briefs, hasLength(3));
        expect(
          briefs.every((b) => b.title.isNotEmpty && b.detail.isNotEmpty),
          isTrue,
        );
      }
    }
    expect(
      actionBriefs(AlertKind.air, UserSetting.unknown)[1].detail,
      contains('침수'),
    );
    expect(
      actionBriefs(AlertKind.air, UserSetting.vehicle).first.title,
      contains('운전 중이면'),
    );
    expect(
      actionBriefs(AlertKind.chemical, UserSetting.indoors).last.title,
      contains('무조건 지하로 가지 마세요'),
    );
    final nuclear = actionBriefs(AlertKind.nuclear, UserSetting.unknown);
    expect(nuclear[0].title, contains('섬광·폭발을 봤다면'));
    expect(nuclear[1].title, contains('폭발 전'));
    expect(nuclear[2].title, contains('폭발 후'));
  });
  testWidgets('pictogram rows align titles and details without clipping text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: AlertActions(kind: AlertKind.air),
            ),
          ),
        ),
      ),
    );
    final briefs = actionBriefs(AlertKind.air, UserSetting.unknown);
    final start = tester.getTopLeft(find.text(briefs.first.title)).dx;
    for (final brief in briefs) {
      expect(tester.getTopLeft(find.text(brief.title)).dx, start);
      expect(tester.getTopLeft(find.text(brief.detail)).dx, start);
      expect(tester.widget<Text>(find.text(brief.detail)).maxLines, isNull);
      expect(
        tester.widget<Text>(find.text(brief.detail)).overflow,
        isNot(TextOverflow.ellipsis),
      );
    }
    expect(tester.takeException(), isNull);
  });
}
