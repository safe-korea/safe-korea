import 'offline_map_screen.dart';

import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/shelter.dart';
import '../services/shelter_api_client.dart';
import '../services/location_service.dart';
import '../services/region_suggestion_service.dart';
import '../services/local_region_service.dart';
import '../widgets/nearby_shelters.dart';
import '../widgets/common.dart';
import '../widgets/location_controls.dart';

/// Optional one-shot location for on-device distance sorting; region-only API.
class PwaSheltersScreen extends StatefulWidget {
  const PwaSheltersScreen({
    super.key,
    this.api,
    this.locationService,
    this.regionService,
  });
  final LocationService? locationService;
  final RegionSuggestionService? regionService;
  final ShelterApiClient? api;
  @override
  State<PwaSheltersScreen> createState() => _PwaSheltersScreenState();
}

class _PwaSheltersScreenState extends State<PwaSheltersScreen> {
  late final _api = widget.api ?? ShelterApiClient();
  late final _regions = _loadRegions();
  String? _province, _district, _error;
  ShelterCatalog? _catalog;
  bool _busy = false, _locating = false;
  Position? _position;
  String? _locationMessage;
  String? _nearbyArea;
  final _nearbyKey = GlobalKey();
  bool _showRegion = true;

  Future<void> _locate() async {
    if (_locating || _busy) return;
    if (!_api.configured) {
      setState(
        () => _locationMessage = '대피소 조회 연결을 준비하고 있어요. 아래 정부 원문을 이용하세요.',
      );
      return;
    }
    setState(() {
      _locating = true;
      _position = null;
      _nearbyArea = null;
      _locationMessage = null;
    });
    try {
      final position = await (widget.locationService ?? LocationService())
          .current();
      if (!mounted) return;
      setState(() {
        _position = position;
        _shown = 20;
        _locationMessage = '현재 지역의 대피소를 찾고 있어요…';
      });
      final suggestion = await (widget.regionService ?? LocalRegionService())
          .suggest(position, await _regions);
      if (!mounted) return;
      if (suggestion?.districtCode == null) {
        setState(() {
          _showRegion = true;
          _locationMessage = '위치는 확인했지만 조회 지역을 확정하지 못했어요. 아래에서 지역을 선택하세요.';
        });
        return;
      }
      setState(() {
        _province = suggestion!.provinceCode;
        _district = suggestion.districtCode;
      });
      await _fetch();
      if (!mounted) return;
      setState(() {
        final found =
            _error == null && _catalog?.areaCode == suggestion!.districtCode;
        _nearbyArea = found ? suggestion.districtCode : null;
        _showRegion = !found;
        _locationMessage = found
            ? '${suggestion.label} 조회 완료 · 아래 가까운 순으로 표시했어요.'
            : '현재 지역의 새 자료를 불러오지 못했어요. 이전 조회 결과는 아래에서 확인하세요.';
      });
      if (_nearbyArea != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final target = _nearbyKey.currentContext;
          if (mounted && target != null) {
            Scrollable.ensureVisible(
              target,
              duration: const Duration(milliseconds: 300),
              alignment: 0.05,
            );
          }
        });
      }
    } on LocationFailure catch (error) {
      if (mounted) setState(() => _locationMessage = error.message);
    } on TimeoutException {
      if (mounted) {
        setState(
          () => _locationMessage = '위치 확인 시간이 초과됐어요. 다시 시도하거나 지역을 직접 선택하세요.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _locationMessage = '위치를 확인하지 못했어요. 지역 선택은 계속 사용할 수 있어요.',
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  String _distance(Shelter shelter) {
    final position = _position!;
    final meters = shelter.distanceFrom(position.latitude, position.longitude);
    return meters < 1000
        ? '${meters.round()}m'
        : '${(meters / 1000).toStringAsFixed(1)}km';
  }

  int _shown = 20;

  Future<List<Map<String, dynamic>>> _loadRegions() async {
    final data = jsonDecode(await rootBundle.loadString('assets/regions.json'));
    return (data['provinces'] as List).cast<Map<String, dynamic>>();
  }

  @override
  void dispose() {
    if (widget.api == null) _api.close();
    super.dispose();
  }

  Future<void> _fetch() async {
    if (_busy || _district == null) return;
    setState(() {
      _busy = true;
      _nearbyArea = null;
      _error = null;
    });
    try {
      final catalog = await _api.fetch(_district!);
      if (mounted) {
        setState(() {
          _catalog = catalog;
          _shown = 20;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = '자료를 불러오지 못했어요. 인터넷 연결을 확인하고 다시 시도하세요.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('지역별 대피소')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _regions,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('지역 목록을 열지 못했어요. 화면을 다시 열어 주세요.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final provinces = snapshot.data!;
        final selected = provinces
            .where((p) => p['code'] == _province)
            .firstOrNull;
        final districts = ((selected?['districts'] as List?) ?? [])
            .cast<Map<String, dynamic>>();
        final catalog = _catalog;
        final shelters = [...?catalog?.shelters];
        final position = _position;
        if (position != null) {
          shelters.sort(
            (a, b) => a
                .distanceFrom(position.latitude, position.longitude)
                .compareTo(
                  b.distanceFrom(position.latitude, position.longitude),
                ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              '내 주변 대피소 찾기',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('GPS 없이도 찾을 수 있어요. 시설 조회와 지도 연결은 인터넷이 필요해요.'),
            const SizedBox(height: 16),
            LocationControls(
              position: _position,
              busy: _locating || _busy,
              message: _locationMessage,
              onLocate: _locate,
              onClear: () => setState(() {
                _position = null;
                _nearbyArea = null;
                _showRegion = true;
                _locationMessage = null;
                _shown = 20;
              }),
            ),
            if (_position != null &&
                _nearbyArea != null &&
                catalog?.areaCode == _nearbyArea)
              NearbyShelters(
                key: _nearbyKey,
                catalog: catalog!,
                position: _position!,
                onSelect: (shelter) => openExternal(
                  context,
                  Uri.parse(
                    'https://map.kakao.com/link/map/${Uri.encodeComponent(shelter.name)},${shelter.latitude},${shelter.longitude}',
                  ),
                ),
              ),
            const SizedBox(height: 20),
            if (!_showRegion)
              TextButton(
                onPressed: _locating || _busy
                    ? null
                    : () => setState(() => _showRegion = true),
                child: const Text('다른 지역 직접 선택'),
              ),
            if (!_api.configured)
              const Notice('대피소 조회 연결을 준비하고 있어요. 아래 정부 사이트에서 확인해 주세요.'),
            if (_api.configured && _showRegion) ...[
              DropdownButtonFormField<String>(
                key: ValueKey('province-$_province'),
                initialValue: _province,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '시·도'),
                items: [
                  for (final p in provinces)
                    DropdownMenuItem(
                      value: p['code'] as String,
                      child: Text(p['name'] as String),
                    ),
                ],
                onChanged: _busy || _locating
                    ? null
                    : (value) => setState(() {
                        _province = value;
                        _district = null;
                        _catalog = null;
                        _error = null;
                      }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('district-$_province-$_district'),
                initialValue: _district,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '시·군·구'),
                items: [
                  for (final d in districts)
                    DropdownMenuItem(
                      value: d['code'] as String,
                      child: Text(d['name'] as String),
                    ),
                ],
                onChanged: _busy || _locating || _province == null
                    ? null
                    : (value) => setState(() {
                        _district = value;
                        _catalog = null;
                        _error = null;
                      }),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _district == null || _busy || _locating
                    ? null
                    : _fetch,
                icon: const Icon(Icons.search),
                label: Text(_busy ? '공식 자료 확인 중…' : '대피소 찾기'),
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(),
                ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Notice(
                  _catalog == null ? _error! : '새 자료를 확인하지 못했어요. 이전 조회 결과입니다.',
                  warning: true,
                ),
              ),
            if (catalog != null) ...[
              const SizedBox(height: 20),
              Text(
                '${catalog.coverage} · ${catalog.shelters.length}곳',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '출처: ${catalog.sourceName}\n조회: ${DateTime.parse(catalog.retrievedAt!).toLocal().toString().split('.').first}\n원본 갱신일: 제공되지 않음',
              ),
              if (catalog.skippedCount > 0)
                Text('정보 검증에서 제외된 시설 ${catalog.skippedCount}곳'),
              const SizedBox(height: 12),
              Notice(
                catalog.deliveryStatus == 'stale'
                    ? '원본 재조회에 실패해 이전 자료를 보여드려요. 현장 개방 여부를 확인하세요.'
                    : '목록 등재가 현재 개방이나 이동 경로의 안전을 보장하지 않아요.',
                warning: catalog.deliveryStatus == 'stale',
              ),
              if (catalog.shelters.isEmpty)
                const Text('확인된 시설이 없어요. 정부 사이트와 현장 안내를 확인하세요.'),
              Text(
                position == null
                    ? '위치 미사용 · 원본 순서'
                    : '선택한 지역 안에서 직선거리 가까운 순 · 이동 경로 아님',
              ),
              const SizedBox(height: 12),
              for (final shelter in shelters.take(_shown))
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          shelter.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(shelter.address),
                        OfflineMapLink(shelter: shelter),
                        if (position != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '현재 위치에서 직선거리 ${_distance(shelter)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => openExternal(
                            context,
                            Uri.parse(
                              'https://map.kakao.com/link/map/${Uri.encodeComponent(shelter.name)},${shelter.latitude},${shelter.longitude}',
                            ),
                          ),
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('카카오 지도로 열기'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            if (catalog != null && catalog.shelters.length > _shown)
              TextButton(
                onPressed: () => setState(() => _shown += 20),
                child: const Text('대피소 20곳 더 보기'),
              ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () =>
                  openExternal(context, Uri.parse(officialMapSource)),
              icon: const Icon(Icons.open_in_new),
              label: const Text('정부 대피시설 원문'),
            ),
            const SizedBox(height: 12),
            const Text(
              '지역 판별: 국가공간정보포털·KnellBalm의 2023년 경계 가공자료. 경계·변경 지역에서는 직접 선택이 필요할 수 있어요.\n조회 시 지역 코드와 IP가 데이터 서버에 전달돼요. 지도 버튼은 해당 시설 위치를 카카오에 전달해요. 현재 GPS·가족 정보는 전송하지 않아요. 이 화면의 시설 목록은 오프라인 저장되지 않아요.',
            ),
          ],
        );
      },
    ),
  );
}
