import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/shelter.dart';
import '../services/location_service.dart';
import '../services/shelter_repository.dart';
import '../widgets/common.dart';

class SheltersScreen extends StatefulWidget {
  const SheltersScreen({
    super.key,
    this.catalog,
    this.locationService,
    this.repository,
  });
  final ShelterCatalog? catalog;
  final LocationService? locationService;
  final ShelterRepository? repository;
  @override
  State<SheltersScreen> createState() => _SheltersScreenState();
}

class _SheltersScreenState extends State<SheltersScreen> {
  late final ShelterRepository _repository =
      widget.repository ?? ShelterRepository();
  List<Map<String, dynamic>> _provinces = [];
  String _province = '11', _district = '11110';
  bool _fetching = false;
  String? _networkMessage;
  ShelterCatalog? _catalog;
  Position? _position;
  bool _locating = false, _map = false;
  String? _error, _locationMessage;
  String _query = '';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final regionData = jsonDecode(
        await rootBundle.loadString('assets/regions.json'),
      ) as Map<String, dynamic>;
      _provinces = (regionData['provinces'] as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      for (final province in _provinces) {
        (province['districts'] as List).sort(
          (a, b) => (a['code'] as String).compareTo(b['code'] as String),
        );
      }
      ShelterCatalog? cached;
      if (widget.catalog == null) {
        try {
          cached = await _repository.cached();
        } catch (_) {
          _networkMessage = '기기에 저장된 시설 자료를 읽지 못했습니다. 지역을 선택해 다시 조회해 주세요.';
        }
      }
      final catalog =
          widget.catalog ??
          cached ??
          ShelterCatalog.fromJson(
            jsonDecode(await rootBundle.loadString('assets/shelters.json'))
                as Map<String, dynamic>,
          );
      if (mounted) {
        setState(() {
          _catalog = catalog;
          final area = catalog.areaCode;
          if (area != null) {
            for (final province in _provinces) {
              if ((province['districts'] as List).any(
                (d) => d['code'] == area,
              )) {
                _province = province['code'] as String;
                _district = area;
              }
            }
          }
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = '시설 자료를 읽지 못했습니다. 정부 공식 시설 검색을 이용해 주세요.');
      }
    }
  }

  List<dynamic> get _districts =>
      _provinces.firstWhere((p) => p['code'] == _province)['districts'] as List;

  Future<void> _fetch() async {
    final province = _provinces.firstWhere((p) => p['code'] == _province);
    final district = _districts.firstWhere((d) => d['code'] == _district);
    setState(() {
      _fetching = true;
      _networkMessage = null;
    });
    try {
      final catalog = await _repository.fetch(
        _district,
        '${province['name']} ${district['name']}',
      );
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _map = false;
        _query = '';
      });
      try {
        await _repository.save(catalog);
        if (mounted) {
          setState(
            () => _networkMessage =
                '공식 지도에서 ${catalog.shelters.length}건을 받아 기기에 저장했습니다. 인터넷 없이 목록을 다시 볼 수 있습니다.',
          );
        }
      } catch (_) {
        if (mounted) {
          setState(
            () => _networkMessage =
                '시설은 조회했지만 기기에 저장하지 못했습니다. 이번 화면에서만 이용할 수 있습니다.',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _networkMessage =
              '공식 시설 조회에 실패했습니다. 연결이나 정부 사이트 응답을 확인해 주세요. 기존에 표시하던 자료는 유지합니다.',
        );
      }
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  @override
  void dispose() {
    if (widget.repository == null) _repository.close();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _position = null;
      _map = false;
      _locationMessage = null;
    });
    try {
      final position = await (widget.locationService ?? LocationService())
          .current();
      if (mounted) {
        setState(() {
          _position = position;
          _locationMessage =
              '현재 위치 확인 · 오차 약 ${position.accuracy.round()}m\n${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}\n확인 시각: ${position.timestamp.toLocal()}';
          _map = false;
        });
      }
    } on LocationFailure catch (error) {
      if (mounted) setState(() => _locationMessage = error.message);
    } on TimeoutException {
      if (mounted) {
        setState(
          () => _locationMessage =
              '위치 확인 시간이 초과되었습니다. 실외에서 다시 시도하거나 주소로 목록을 검색하세요.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _locationMessage = '위치를 확인하지 못했습니다. 위치 없이도 시설 목록을 볼 수 있어요.',
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  List<Shelter> get _filtered {
    final catalog = _catalog;
    if (catalog == null) return [];
    final position = _position;
    final items = position == null
        ? catalog.shelters
        : catalog.nearest(position.latitude, position.longitude);
    return items
        .where((s) => '${s.name} ${s.address}'.contains(_query.trim()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = _catalog;
    final items = _filtered;
    return Scaffold(
      appBar: AppBar(title: const Text('주변 대피시설')),
      body: PageBody(
        children: [
          const Notice(
            '가까운 시설이 안전한 경로나 현재 개방을 뜻하지 않습니다. 공습용 대피시설은 화학 공격에 적합하지 않을 수 있습니다.',
            urgent: true,
          ),
          if (_provinces.isNotEmpty) ...[
            const Text(
              '지역을 선택해 공식 대피소 조회',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('province-$_province'),
              initialValue: _province,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '시·도'),
              items: [
                for (final p in _provinces)
                  DropdownMenuItem(
                    value: p['code'] as String,
                    child: Text(p['name'] as String),
                  ),
              ],
              onChanged: _fetching
                  ? null
                  : (value) => setState(() {
                      _province = value!;
                      _district = _districts.first['code'] as String;
                    }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('district-$_district'),
              initialValue: _district,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '시·군·구'),
              items: [
                for (final d in _districts)
                  DropdownMenuItem(
                    value: d['code'] as String,
                    child: Text(d['name'] as String),
                  ),
              ],
              onChanged: _fetching
                  ? null
                  : (value) => setState(() => _district = value!),
            ),
            const SizedBox(height: 12),
            const Text(
              '선택한 지역 코드와 IP가 국민안전24에 전달됩니다. GPS 좌표는 전송하지 않습니다. 공식 웹사이트 조회를 사용하며 응답이 지연되거나 변경될 수 있습니다.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _fetching ? null : _fetch,
              icon: const Icon(Icons.download_outlined),
              label: Text(_fetching ? '공식 시설 조회 중…' : '선택 지역 대피소 불러오기'),
            ),
            const SizedBox(height: 12),
            if (_networkMessage != null)
              Semantics(liveRegion: true, child: Notice(_networkMessage!)),
          ],
          const Text(
            '위치 없이도 검색할 수 있어요',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '현재 위치는 버튼을 눌렀을 때만 확인하며 기기에서 거리 계산에 사용합니다. 저장하지 않습니다. GPS 오차와 직선거리를 고려하세요.',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _locating ? null : _locate,
            icon: const Icon(Icons.my_location),
            label: Text(_locating ? '위치 확인 중…' : 'GPS 현재 위치 확인'),
          ),
          const SizedBox(height: 12),
          if (_locationMessage != null)
            Semantics(liveRegion: true, child: Notice(_locationMessage!)),
          if (_error != null) ...[
            Notice(_error!),
            OutlinedButton(onPressed: _load, child: const Text('다시 읽기')),
          ],
          if (catalog == null && _error == null)
            const Center(child: CircularProgressIndicator()),
          if (catalog != null) ...[
            Text(
              '출처: ${catalog.sourceName}\n자료 범위: ${catalog.coverage}\n자료 확보일: ${catalog.retrievedAt ?? '미확보'}',
            ),
            const SizedBox(height: 16),
            if (catalog.shelters.isEmpty && catalog.retrievedAt == null)
              const Notice(
                '저장된 대피시설이 없습니다.\n위에서 지역을 선택해 공식 대피소를 조회하세요. 조회한 목록은 이 기기에 저장됩니다.',
              ),
            if (catalog.retrievedAt != null)
              Notice(
                '현재 표시 범위: ${catalog.coverage}\n국민안전24 등재 시설 ${catalog.officialCount ?? catalog.shelters.length}건 중 좌표 유효 시설 ${catalog.shelters.length}건 · 제외 ${catalog.skippedCount}건\n전국 전체 목록이 아닙니다. 저장 후 시설 정보가 변경될 수 있습니다.',
              ),
            if (catalog.shelters.isEmpty && catalog.retrievedAt != null)
              const Notice(
                '해당 지역의 공식 조회 결과가 0건입니다. 실제 시설이 없다는 뜻으로 단정하지 말고 정부 사이트나 지자체에 확인하세요.',
              ),
            if (catalog.shelters.isNotEmpty) ...[
              TextField(
                onChanged: (value) => setState(() {
                  _query = value;
                  _map = false;
                }),
                decoration: const InputDecoration(
                  labelText: '시설명 또는 주소 검색',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${items.length}개 시설 · ${_position == null ? '위치 미사용, 원본 순서' : '직선거리 가까운 순'}',
              ),
              const SizedBox(height: 12),
            ],
            const Notice(
              '온라인 지도를 열면 지도 제공자에게 조회 지역과 IP가 전달됩니다. 인터넷이 필요하며 배경이 비어 있으면 시설 목록을 이용하세요.',
            ),
            if (!_map)
              OutlinedButton.icon(
                onPressed: () => setState(() => _map = true),
                icon: const Icon(Icons.map_outlined),
                label: const Text('온라인 지도 열기'),
              ),
            if (_map) ...[
              SizedBox(
                height: 320,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _buildMap(items),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                children: [
                  TextButton(
                    onPressed: () => openExternal(
                      context,
                      Uri.parse('https://www.openstreetmap.org/copyright'),
                    ),
                    child: const Text('© OpenStreetMap contributors'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _map = false),
                    child: const Text('지도 닫기'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            for (final shelter in items.take(50)) _shelterCard(shelter),
            if (items.length > 50)
              const Text(
                '목록에는 현재 순서의 앞 50개만 표시합니다. 지도에는 검색 결과 전체를 표시합니다. 시설명이나 주소로 범위를 좁힐 수 있습니다.',
              ),
            if (catalog.shelters.isNotEmpty && items.isEmpty)
              const Notice('일치하는 시설이 없습니다. 검색어를 바꿔 주세요.'),
            TextButton(
              onPressed: () =>
                  openExternal(context, Uri.parse(catalog.sourceUrl)),
              child: const Text('공식 자료 출처 보기'),
            ),
          ],
          OutlinedButton(
            onPressed: () =>
                openExternal(context, Uri.parse(officialMapSource)),
            child: const Text('정부 공식 시설 검색 열기'),
          ),
        ],
      ),
    );
  }

  Widget _shelterCard(Shelter shelter) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            shelter.name,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
          Text(shelter.address),
          if (_position != null)
            Text(
              '직선거리 ${(shelter.distanceFrom(_position!.latitude, _position!.longitude) / 1000).toStringAsFixed(2)}km · 이동 경로 아님',
            ),
          Text(
            '원자료 갱신: ${shelter.updatedAt ?? '제공되지 않음'}\n현재 개방·수용 여유·현장 위험 미확인',
          ),
        ],
      ),
    ),
  );
  Widget _buildMap(List<Shelter> items) {
    final first = items.firstOrNull;
    final center = first != null
        ? LatLng(first.latitude, first.longitude)
        : _position != null
        ? LatLng(_position!.latitude, _position!.longitude)
        : const LatLng(36.3, 127.8);
    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: first != null || _position != null ? 14 : 6,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'kr.example.safe_korea',
        ),
        MarkerLayer(
          markers: [
            for (final shelter in items)
              Marker(
                point: LatLng(shelter.latitude, shelter.longitude),
                width: 48,
                height: 48,
                child: IconButton(
                  tooltip: shelter.name,
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => SafeArea(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _shelterCard(shelter),
                        ),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.location_on, size: 40, color: teal),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
