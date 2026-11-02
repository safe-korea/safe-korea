import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../services/local_store.dart';
import '../services/web_push_bridge.dart';
import '../widgets/common.dart';
import 'family_screen.dart';
import 'radio_screen.dart';
import 'supplies_screen.dart';
import 'data_permissions_screen.dart';

const preparednessItems = <String, String>{
  'water': '생수 · 간편식',
  'medicine': '상비약 · 개인 복용약',
  'light': '손전등',
  'radio': '라디오 · 여분 건전지',
  'power': '충전기 · 보조배터리',
  'contact': '가족 비상연락카드',
  'hygiene': '위생용품 · 개인 생필품',
  'protection': '상황에 맞는 개인 보호용품',
};

class ReadinessScreen extends StatefulWidget {
  const ReadinessScreen({super.key, this.store});
  final LocalStore? store;
  @override
  State<ReadinessScreen> createState() => _ReadinessScreenState();
}

class _ReadinessScreenState extends State<ReadinessScreen> {
  late final LocalStore _store = widget.store ?? LocalStore();
  Set<String> _checked = {};
  bool _loading = true, _saving = false, _readFailed = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await _store.loadPreparation();
      if (mounted) {
        setState(() {
          _checked = values.intersection(preparednessItems.keys.toSet());
          _loading = false;
          _readFailed = false;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _readFailed = true;
          _error = '준비물 체크를 불러오지 못했습니다. 다시 읽어 주세요.';
        });
      }
    }
  }

  Future<void> _toggle(String id, bool value) async {
    final next = {..._checked};
    if (value) {
      next.add(id);
    } else {
      next.remove(id);
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _store.savePreparation(next);
      if (mounted) setState(() => _checked = next);
    } catch (_) {
      if (mounted) setState(() => _error = '체크를 저장하지 못했습니다. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('나의 준비')),
    body: PageBody(
      children: [
        if (kIsWeb) ...[
          OutlinedButton.icon(
            onPressed: openWebNotificationSettings,
            icon: const Icon(Icons.notifications_outlined),
            label: const Text('알림 설정'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: openWebInstallSettings,
            icon: const Icon(Icons.offline_pin_outlined),
            label: const Text('설치·오프라인 관리'),
          ),
          const SizedBox(height: 16),
        ],
        const Text(
          '비상배낭 체크리스트',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('가볍게 준비하고 유효기간을 확인하세요.'),
        const SizedBox(height: 16),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (!_loading) ...[
          Text(
            '체크한 준비물 ${_checked.length} / ${preparednessItems.length}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _checked.length / preparednessItems.length,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Semantics(liveRegion: true, child: Notice(_error!, warning: true)),
          if (_readFailed)
            OutlinedButton(onPressed: _load, child: const Text('체크리스트 다시 읽기')),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final entry in preparednessItems.entries)
                  CheckboxListTile(
                    selected: _checked.contains(entry.key),
                    selectedTileColor: const Color(0xFFE3F0EC),
                    secondary: MediaQuery.textScalerOf(context).scale(16) > 24
                        ? null
                        : ExcludeSemantics(
                            child: Icon(switch (entry.key) {
                              'water' => Icons.water_drop_outlined,
                              'medicine' => Icons.medication_outlined,
                              'light' => Icons.flashlight_on_outlined,
                              'radio' => Icons.radio_outlined,
                              'power' => Icons.battery_charging_full,
                              'contact' => Icons.contact_page_outlined,
                              'hygiene' => Icons.clean_hands_outlined,
                              _ => Icons.shield_outlined,
                            }, color: teal),
                          ),
                    title: Text(entry.value),
                    value: _checked.contains(entry.key),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    onChanged: _saving || _readFailed
                        ? null
                        : (value) => _toggle(entry.key, value!),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Notice('체크 여부는 이 기기에만 저장됩니다. 이 목록이 모든 상황의 대비를 보장하지는 않습니다.'),
        const Text(
          '참고: 행정안전부 국민안전24 · 비상시 행동요령\n원문 확인 2026-10-31 · 개인 상황에 맞게 준비하세요.',
        ),
        const SizedBox(height: 24),
        ActionTile(
          icon: Icons.radio_outlined,
          title: '라디오 연결',
          subtitle: 'KBS 공식 서비스 · 인터넷 필요',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const RadioScreen()),
          ),
        ),
        ActionTile(
          icon: Icons.people_outline,
          title: '가족 만남 장소',
          subtitle: '첫 번째 장소 · 대체 장소',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const FamilyScreen()),
          ),
        ),
        const SizedBox(height: 24),
        // A supplier preview is useful in development, but is not a live store.
        if (kDebugMode) ...[
          const SizedBox(height: 12),
          ActionTile(
            icon: Icons.shopping_bag_outlined,
            title: '비상용품 준비',
            subtitle: '구매 전 확인 · 판매처 준비 중',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const SuppliesScreen()),
            ),
          ),
        ],
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const DataPermissionsScreen(),
            ),
          ),
          icon: const Icon(Icons.privacy_tip_outlined),
          label: const Text('데이터와 권한'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () =>
              showLicensePage(context: context, applicationName: 'SAFE KOREA'),
          icon: const Icon(Icons.info_outline),
          label: const Text('앱 정보 · 오픈소스 라이선스'),
        ),
      ],
    ),
  );
}
