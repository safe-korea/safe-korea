import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/offline_area.dart';
import '../models/shelter.dart';
import '../screens/offline_map_screen.dart';
import '../services/area_map_service.dart';
import '../services/connection_monitor.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';

/// "Save my area" entry: one tap, one short confirmation, then download.
class AreaMapCard extends StatefulWidget {
  const AreaMapCard({super.key, this.service, this.monitor});
  final AreaMapService? service;
  final ConnectionMonitor? monitor;
  @override
  State<AreaMapCard> createState() => _AreaMapCardState();
}

class _AreaMapCardState extends State<AreaMapCard> {
  late final _service = widget.service ?? AreaMapService();
  ConnectionMonitor get _link => widget.monitor ?? ConnectionMonitor.instance;
  AreaMap? _saved;
  String? _status, _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _link.addListener(_changed);
    if (kIsWeb) return;
    _service.load().then((value) {
      if (mounted) setState(() => _saved = value);
    }, onError: (Object _) {});
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _link.removeListener(_changed);
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
      _status = '현재 위치로 지역 확인 중…';
    });
    try {
      AreaMapPlan plan;
      try {
        plan = await _service.plan();
        if (!mounted) return;
        final ok = await _confirm(plan);
        if (ok != true || !mounted) return;
      } on AreaMapChoice catch (choice) {
        if (!mounted) return;
        final picked = await _choose(choice.plans);
        if (picked == null || !mounted) return;
        plan = picked;
      }
      setState(() => _status = '${plan.region.label} 지도 받는 중…');
      final saved = await _service.download(
        plan,
        progress: (done, total) {
          if (mounted) {
            setState(
              () => _status = '${plan.region.label} 지도 받는 중… $done/$total',
            );
          }
        },
      );
      if (!mounted) return;
      setState(() => _saved = saved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved.catalog == null
                ? '${saved.regionName} 지도를 저장했어요. 대피소 목록은 받지 못했어요.'
                : '${saved.regionName} 지도와 대피소 ${saved.catalog!.shelters.length}곳을 저장했어요.',
          ),
        ),
      );
    } on LocationFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on AreaMapFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = '지도를 저장하지 못했어요. 연결을 확인하고 다시 시도하세요.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = null;
        });
      }
    }
  }

  Future<bool?> _confirm(AreaMapPlan plan) => showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${plan.region.label} 지도를 저장할까요?',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('${plan.sizeLabel} · 대피소 목록 포함 · 인터넷 없이 볼 수 있어요'),
            const SizedBox(height: 4),
            Text(
              '내 위치 좌표는 보내지 않고 ${plan.region.label} 전체를 받아요.',
              style: const TextStyle(fontSize: 14, color: AppPalette.muted),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('저장'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
          ],
        ),
      ),
    ),
  );

  Future<AreaMapPlan?> _choose(List<AreaMapPlan> plans) =>
      showModalBottomSheet<AreaMapPlan>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '어느 지역 지도를 저장할까요?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text('지금 위치가 시·군·구 경계 근처예요. 대피소 목록도 함께 받아요.'),
                const SizedBox(height: 4),
                const Text(
                  '내 위치 좌표는 보내지 않고 고른 지역 전체를 받아요.',
                  style: TextStyle(fontSize: 14, color: AppPalette.muted),
                ),
                const SizedBox(height: 12),
                for (final plan in plans)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, plan),
                      child: Text('${plan.region.label} · ${plan.sizeLabel}'),
                    ),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
              ],
            ),
          ),
        ),
      );

  void _open(AreaMap saved) {
    final catalog =
        saved.catalog ??
        ShelterCatalog.fromJson({
          'schemaVersion': 1,
          'sourceName': '행정안전부 민방위 대피시설',
          'sourceUrl': officialMapSource,
          'coverage': saved.regionName,
          'items': <Object>[],
        });
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => OfflineMapScreen(
          title: '${saved.regionName} 지도',
          savedArea: OfflineArea(saved.map, catalog),
          showMyLocation: true,
        ),
      ),
    );
  }

  String _date(DateTime t) {
    final d = t.toLocal();
    return '${d.month}/${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    // Browser storage (~5MB) cannot hold a district map; the PWA keeps the
    // per-shelter maps only.
    if (kIsWeb) return const SizedBox.shrink();
    final offline = _link.value.needsOfflineTools;
    final saved = _saved;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.map_outlined, color: AppPalette.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    saved == null ? '내 지역 지도 저장' : '${saved.regionName} 지도',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              saved == null
                  ? '지금 있는 시·군·구 지도와 대피소를 저장해 인터넷 없이 봐요.'
                  : '${_date(saved.savedAt)} 저장 · 대피소 ${saved.catalog?.shelters.length ?? 0}곳 · 인터넷 없이 보기',
              style: const TextStyle(fontSize: 14),
            ),
            if (_status != null) ...[
              const SizedBox(height: 8),
              Semantics(liveRegion: true, child: Text(_status!)),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppPalette.caution),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (saved != null) ...[
              FilledButton.icon(
                onPressed: () => _open(saved),
                icon: const Icon(Icons.offline_pin_outlined),
                label: const Text('저장한 지도 보기'),
              ),
              const SizedBox(height: 8),
            ],
            (saved == null ? FilledButton.icon : OutlinedButton.icon)(
              onPressed: _busy || offline ? null : _save,
              icon: const Icon(Icons.my_location),
              label: Text(
                offline
                    ? '연결 후 저장'
                    : saved == null
                    ? '현재 위치로 저장'
                    : '현재 위치로 다시 저장',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
