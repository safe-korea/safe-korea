import 'widgets/situation_selector.dart';

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'models/alert_guidance.dart';
import 'services/connection_monitor.dart';
import 'screens/pwa_shelters_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/action_brief.dart';
import 'widgets/common.dart';
import 'widgets/public_support_links.dart';
import 'widgets/guideline_step.dart';

final _pwaNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Nanum Gothic',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  final fonts = FontLoader('SafeKoreaWeb')
    ..addFont(rootBundle.load('assets/fonts/NanumGothic-Regular.ttf'));
  await fonts.load();
  runApp(const SafeKoreaPwa());
  ConnectionMonitor.instance.start();
}

/// A separate entry point keeps unfinished native plugins out of the web app.
class SafeKoreaPwa extends StatelessWidget {
  const SafeKoreaPwa({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = buildAppTheme(fontFamily: 'SafeKoreaWeb');
    return MaterialApp(
      navigatorKey: _pwaNavigatorKey,
      title: 'SAFE KOREA',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Material localizes Korean with dense typography; override that family
      // as well so it cannot request an unbundled Noto font when offline.
      theme: theme.copyWith(
        typography: theme.typography.copyWith(
          dense: theme.typography.dense.apply(fontFamily: 'SafeKoreaWeb'),
          tall: theme.typography.tall.apply(fontFamily: 'SafeKoreaWeb'),
          englishLike: theme.typography.englishLike.apply(
            fontFamily: 'SafeKoreaWeb',
          ),
        ),
      ),
      builder: (context, child) => ValueListenableBuilder<LinkStatus>(
        valueListenable: ConnectionMonitor.instance,
        builder: (context, status, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (status.needsOfflineTools)
              Material(
                color: AppPalette.cautionBackground,
                child: SafeArea(
                  bottom: false,
                  child: TextButton.icon(
                    onPressed: () => _pwaNavigatorKey.currentState?.popUntil(
                      (route) => route.isFirst,
                    ),
                    icon: const Icon(Icons.wifi_off),
                    label: const Text('연결 확인 필요 · 저장된 행동요령 보기'),
                  ),
                ),
              ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: status.needsOfflineTools,
                child: child!,
              ),
            ),
          ],
        ),
      ),
      home: const PwaGuidanceHome(),
    );
  }
}

class PwaGuidanceHome extends StatefulWidget {
  const PwaGuidanceHome({super.key});
  @override
  State<PwaGuidanceHome> createState() => _PwaGuidanceHomeState();
}

class _PwaGuidanceHomeState extends State<PwaGuidanceHome> {
  @override
  void initState() {
    super.initState();
    ConnectionMonitor.instance.addListener(_connectionChanged);
  }

  void _connectionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ConnectionMonitor.instance.removeListener(_connectionChanged);
    super.dispose();
  }

  late Future<Map<String, dynamic>> _data = _load();
  Future<Map<String, dynamic>> _load() async =>
      jsonDecode(await rootBundle.loadString('assets/guidelines.json'))
          as Map<String, dynamic>;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        ConnectionMonitor.instance.value.needsOfflineTools
            ? '오프라인 행동요령'
            : '상황별 행동요령',
      ),
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return PageBody(
            children: [
              const Notice(
                '안내를 불러오지 못했어요. 정부 방송과 현장 안내를 확인하세요.',
                warning: true,
              ),
              FilledButton(
                onPressed: () => setState(() => _data = _load()),
                child: const Text('다시 불러오기'),
              ),
            ],
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        return PageBody(
          children: [
            const Text(
              '어떤 안내가 필요한가요?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Notice('경보를 들었다면, 상황에 맞는 행동을 확인하세요.'),
            if (ConnectionMonitor.instance.value.needsOfflineTools) ...[
              const Notice(
                '연결을 확인할 수 없어요. 저장된 행동요령을 먼저 확인하세요. 지도·새 시설 조회에는 인터넷이 필요해요.',
              ),
              OutlinedButton(
                onPressed: ConnectionMonitor.instance.refresh,
                child: const Text('연결 다시 확인'),
              ),
            ],
            for (final item
                in (data['items'] as List).cast<Map<String, dynamic>>())
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ActionTile(
                  icon: item['id'] == 'air'
                      ? Icons.campaign_outlined
                      : Icons.menu_book_outlined,
                  title: item['title'] as String,
                  subtitle: item['summary'] as String,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => PwaGuidanceDetail(item: item),
                    ),
                  ),
                ),
              ),
            if (!ConnectionMonitor.instance.value.needsOfflineTools)
              ActionTile(
                icon: Icons.location_city_outlined,
                title: '지역별 대피소 찾기',
                subtitle: '시·군·구 선택 · 인터넷 필요',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const PwaSheltersScreen(),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            const Notice('앱 안의 지도·GPS·가족 저장은 준비 중입니다.'),
            OutlinedButton.icon(
              onPressed: () => openExternal(
                context,
                Uri.parse(
                  'https://www.safekorea.go.kr/safekorea-kor/flsm/flsm/facilitiesSafteyMap.do?menuSn=234',
                ),
              ),
              icon: const Icon(Icons.open_in_new),
              label: const Text('정부 대피시설 찾기 · 인터넷 필요'),
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('출처와 확인 날짜'),
              children: [
                InfoLine(label: '출처', value: data['sourceName'] as String),
                InfoLine(label: '확인 날짜', value: data['reviewedAt'] as String),
                Text(data['notice'] as String),
                TextButton(
                  onPressed: () => openExternal(
                    context,
                    Uri.parse(data['sourceUrl'] as String),
                  ),
                  child: const Text('정부 원문 · 인터넷 필요'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const PublicSupportLinks(),
            TextButton(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: 'SAFE KOREA',
              ),
              child: const Text('오픈소스 라이선스'),
            ),
          ],
        );
      },
    ),
  );
}

class PwaGuidanceDetail extends StatefulWidget {
  const PwaGuidanceDetail({super.key, required this.item});
  final Map<String, dynamic> item;
  @override
  State<PwaGuidanceDetail> createState() => _PwaGuidanceDetailState();
}

class _PwaGuidanceDetailState extends State<PwaGuidanceDetail> {
  UserSetting _setting = UserSetting.unknown;
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final kind = AlertKind.fromName(item['id'] as String);
    final color = kind == null ? AppPalette.green : AppPalette.forAlert(kind);
    return Scaffold(
      appBar: AppBar(
        title: Text('${item['title']} 안내'),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: PageBody(
        children: [
          const Text('행동요령 확인 · 실제 경보가 아닙니다', style: TextStyle(fontSize: 14)),
          const SizedBox(height: 16),
          Text(
            kind?.headline ?? item['summary'] as String,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (kind != null) ...[
            SituationSelector(
              value: _setting,
              onChanged: (setting) => setState(() => _setting = setting),
            ),
            const SizedBox(height: 20),
            for (final (index, brief) in actionBriefs(kind, _setting).indexed)
              ActionBriefTile(brief: brief, accent: color, primary: index == 0),
            const SizedBox(height: 16),
          ],
          ExpansionTile(
            initiallyExpanded: kind == null,
            title: const Text('전체 행동요령'),
            children: [
              for (final (index, step) in (item['steps'] as List).indexed)
                GuidelineStep(
                  kind: item['id'] as String,
                  index: index,
                  text: step as String,
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Notice('최신 재난문자·정부 방송·현장 지시를 우선하세요.'),
        ],
      ),
    );
  }
}
