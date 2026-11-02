import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/models/shelter.dart';
import 'package:safe_korea/screens/pwa_shelters_screen.dart';
import 'package:safe_korea/services/shelter_api_client.dart';

import 'shelter_api_client_test.dart' show payload;

class FakeApi extends ShelterApiClient {
  FakeApi() : super(baseUrl: 'https://api.example.org');
  bool fail = false;
  int calls = 0;
  @override
  Future<ShelterCatalog> fetch(String code) async {
    calls++;
    if (fail) throw const ShelterApiException('offline');
    final data = payload()['catalog'] as Map<String, dynamic>;
    data['areaCode'] = code;
    data['deliveryStatus'] = 'stale';
    return ShelterCatalog.fromJson(data);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => rootBundle.evict('assets/regions.json'));
  testWidgets(
    'unconfigured service keeps official fallback and does not offer broken fetch',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PwaSheltersScreen(api: ShelterApiClient(baseUrl: '')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('연결을 준비'), findsOneWidget);
      expect(find.text('정부 대피시설 원문'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    },
  );
  testWidgets(
    'region selection, stale and retry states fit a narrow large-text screen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = FakeApi();
      addTearDown(api.close);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.5)),
            child: child!,
          ),
          home: PwaSheltersScreen(api: api),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.calls, 0);
      final menus = find.byType(DropdownButtonFormField<String>);
      await tester.tap(menus.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('서울특별시').last);
      await tester.pumpAndSettle();
      await tester.tap(menus.last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('동작구').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('대피소 찾기'));
      await tester.tap(find.text('대피소 찾기'));
      await tester.pumpAndSettle();
      expect(api.calls, 1);
      expect(find.textContaining('원본 재조회에 실패'), findsOneWidget);
      expect(find.textContaining('원본 갱신일'), findsOneWidget);
      api.fail = true;
      await tester.ensureVisible(find.text('대피소 찾기'));
      await tester.tap(find.text('대피소 찾기'));
      await tester.pumpAndSettle();
      expect(find.textContaining('새 자료를 확인하지 못했어요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
