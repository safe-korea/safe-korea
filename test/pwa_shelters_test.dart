import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_korea/models/shelter.dart';
import 'package:safe_korea/screens/pwa_shelters_screen.dart';
import 'package:safe_korea/services/shelter_api_client.dart';

import 'shelter_api_client_test.dart' show payload;
import 'region_and_refresh_test.dart' show FixtureLocation;

import 'package:safe_korea/services/location_service.dart';

class DeniedLocation extends LocationService {
  @override
  Future<Never> current() async =>
      throw const LocationFailure('위치 권한을 허용하지 않았어요.');
}

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
  testWidgets('PWA GPS is opt-in, clears and makes no facility request', (
    tester,
  ) async {
    final location = FixtureLocation();
    final api = FakeApi();
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: PwaSheltersScreen(api: api, locationService: location),
      ),
    );
    await tester.pumpAndSettle();
    expect(location.calls, 0);
    await tester.tap(find.text('GPS 현재 위치 확인'));
    await tester.pumpAndSettle();
    expect(location.calls, 1);
    expect(api.calls, 0);
    expect(find.textContaining('현재 위치 확인 · 오차'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('내 위치 옵션'));
    await tester.tap(find.byTooltip('내 위치 옵션'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('내 위치 사용 해제'));
    await tester.pumpAndSettle();
    expect(find.textContaining('현재 위치 확인 · 오차'), findsNothing);
  });
  testWidgets('PWA denied GPS retains region selection', (tester) async {
    final api = FakeApi();
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: PwaSheltersScreen(api: api, locationService: DeniedLocation()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('GPS 현재 위치 확인'));
    await tester.pumpAndSettle();
    expect(find.textContaining('위치 권한을 허용하지'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));
    expect(api.calls, 0);
  });
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
      await tester.ensureVisible(menus.last);
      await tester.pumpAndSettle();
      await tester.tap(menus.last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('동작구').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('대피소 찾기'), 150);
      await tester.pumpAndSettle();
      await tester.tap(find.text('대피소 찾기'));
      await tester.pumpAndSettle();
      expect(api.calls, 1);
      expect(find.textContaining('원본 재조회에 실패'), findsOneWidget);
      expect(find.textContaining('원본 갱신일'), findsOneWidget);
      api.fail = true;
      await tester.scrollUntilVisible(find.text('대피소 찾기'), 150);
      await tester.pumpAndSettle();
      await tester.tap(find.text('대피소 찾기'));
      await tester.pumpAndSettle();
      expect(find.textContaining('새 자료를 확인하지 못했어요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
