import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'models/alert_guidance.dart';
import 'theme/app_theme.dart';
import 'widgets/action_brief.dart';
import 'widgets/common.dart';
import 'widgets/guideline_step.dart';

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
}

/// A separate entry point keeps unfinished native plugins out of the web app.
class SafeKoreaPwa extends StatelessWidget {
  const SafeKoreaPwa({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = buildAppTheme(fontFamily: 'SafeKoreaWeb');
    return MaterialApp(
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
  late Future<Map<String, dynamic>> _data = _load();
  Future<Map<String, dynamic>> _load() async =>
      jsonDecode(await rootBundle.loadString('assets/guidelines.json'))
          as Map<String, dynamic>;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('상황별 행동요령')),
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
            const Notice('비공식 준비용 안내 · 실제 경보 수신 없음'),
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
            const Notice('웹 지도·GPS·가족 저장은 준비 중입니다. 대피시설은 정부 사이트에서 확인할 수 있습니다.'),
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
            const Text(
              '지금 어디에 있나요?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final setting in UserSetting.values)
                  ChoiceChip(
                    label: Text(setting.label),
                    selected: setting == _setting,
                    onSelected: (_) => setState(() => _setting = setting),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            for (final brief in actionBriefs(kind, _setting))
              ActionBriefTile(brief: brief, accent: color),
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
