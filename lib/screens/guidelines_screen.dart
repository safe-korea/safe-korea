import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/common.dart';
import '../widgets/guideline_step.dart';
import '../theme/app_theme.dart';
import '../models/alert_guidance.dart';
import 'alert_guide_screen.dart';

class GuidelinesScreen extends StatefulWidget {
  const GuidelinesScreen({super.key});
  @override
  State<GuidelinesScreen> createState() => _GuidelinesScreenState();
}

class _GuidelinesScreenState extends State<GuidelinesScreen> {
  late final Future<Map<String, dynamic>> _data = rootBundle
      .loadString('assets/guidelines.json')
      .then((s) => jsonDecode(s) as Map<String, dynamic>);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('상황별 행동강령')),
    body: FutureBuilder(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const PageBody(
            children: [Notice('행동강령을 불러오지 못했습니다. 정부 방송과 현장 안내를 확인하세요.')],
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        return PageBody(
          children: [
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const AlertGuideScreen(),
                ),
              ),
              icon: const Icon(Icons.touch_app_outlined),
              label: const Text('내 상황에 맞는 행동 보기'),
            ),
            const SizedBox(height: 8),
            const Text('실내·실외·이동 중 안내 · 오프라인 저장됨'),
            const SizedBox(height: 16),
            for (final item in data['items'] as List)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  backgroundColor: item['id'] == 'air'
                      ? AppPalette.alertBackground
                      : AppPalette.surface,
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  title: Text(
                    item['title'] as String,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(item['summary'] as String),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (AlertKind.fromName(item['id'] as String)
                        case final kind?)
                      FilledButton.tonal(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => AlertGuideScreen(initialKind: kind),
                          ),
                        ),
                        child: const Text('내 상황에 맞춰 보기'),
                      ),
                    const SizedBox(height: 12),
                    for (final (index, step) in (item['steps'] as List).indexed)
                      GuidelineStep(
                        kind: item['id'] as String,
                        index: index,
                        text: step as String,
                      ),
                  ],
                ),
              ),
            const Text(
              '최신 정부 방송·현장 지시를 우선하세요.',
              style: TextStyle(fontSize: 14),
            ),
            ExpansionTile(
              title: const Text('출처와 확인 날짜'),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InfoLine(label: '출처', value: data['sourceName'] as String),
                InfoLine(label: '확인 날짜', value: data['reviewedAt'] as String),
                const InfoLine(label: '원문 갱신', value: '미표기'),
                Text(
                  data['notice'] as String,
                  style: const TextStyle(fontSize: 14),
                ),
                TextButton(
                  onPressed: () => openExternal(
                    context,
                    Uri.parse(data['sourceUrl'] as String),
                  ),
                  child: const Text('정부 원문 열기 (인터넷 필요)'),
                ),
                if (data['additionalSourceUrl'] case final String url)
                  TextButton(
                    onPressed: () => openExternal(context, Uri.parse(url)),
                    child: const Text('국민안전24 상세 행동요령'),
                  ),
              ],
            ),
          ],
        );
      },
    ),
  );
}
