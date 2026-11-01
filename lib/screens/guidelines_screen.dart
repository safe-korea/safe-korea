import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/common.dart';
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
                  leading: ExcludeSemantics(
                    child: Icon(
                      switch (item['id']) {
                        'air' => Icons.warning_amber_rounded,
                        'watch' => Icons.hearing_outlined,
                        'chemical' => Icons.masks_outlined,
                        'biological' => Icons.health_and_safety_outlined,
                        'release' => Icons.notifications_off_outlined,
                        _ => Icons.backpack_outlined,
                      },
                      color: item['id'] == 'air'
                          ? AppPalette.alert
                          : AppPalette.green,
                    ),
                  ),
                  title: Text(
                    item['title'] as String,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(item['summary'] as String),
                  childrenPadding: const EdgeInsets.all(20),
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
                    for (final (index, step) in (item['steps'] as List).indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          '${index + 1}. $step',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            Text(data['notice'] as String),
            const SizedBox(height: 12),
            Text(
              '출처: ${data['sourceName']}\n원문 확인: ${data['reviewedAt']}\n원문 자체 갱신일: 미표기',
            ),
            TextButton(
              onPressed: () =>
                  openExternal(context, Uri.parse(data['sourceUrl'] as String)),
              child: const Text('정부 원문 열기 (인터넷 필요)'),
            ),
            if (data['additionalSourceUrl'] case final String url)
              TextButton(
                onPressed: () => openExternal(context, Uri.parse(url)),
                child: const Text('국민안전24 상세 행동요령'),
              ),
          ],
        );
      },
    ),
  );
}
