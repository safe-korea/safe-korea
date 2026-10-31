import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/shelter.dart';
import '../services/location_service.dart';
import '../widgets/common.dart';

class SheltersScreen extends StatefulWidget {
  const SheltersScreen({super.key, this.catalog, this.locationService});
  final ShelterCatalog? catalog;
  final LocationService? locationService;
  @override
  State<SheltersScreen> createState() => _SheltersScreenState();
}

class _SheltersScreenState extends State<SheltersScreen> {
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
      final catalog =
          widget.catalog ??
          ShelterCatalog.fromJson(
            jsonDecode(await rootBundle.loadString('assets/shelters.json'))
                as Map<String, dynamic>,
          );
      if (mounted) {
        setState(() {
          _catalog = catalog;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = '시설 자료를 읽지 못했습니다. 정부 공식 시설 검색을 이용해 주세요.');
      }
    }
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
            if (catalog.shelters.isEmpty)
              const Notice(
                '공식 대피시설 데이터 미연동\n공식 다운로드 접근이 확인되지 않아 시설을 표시하지 않습니다. 정부 시설 검색 또는 안전디딤돌에서 확인해 주세요.',
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
              const Text('가까운 50개만 표시합니다. 시설명이나 주소로 범위를 좁혀 주세요.'),
            if (catalog.shelters.isNotEmpty && items.isEmpty)
              const Notice('일치하는 시설이 없습니다. 검색어를 바꿔 주세요.'),
            TextButton(
              onPressed: () =>
                  openExternal(context, Uri.parse(catalog.sourceUrl)),
              child: const Text('공공데이터포털 출처 보기'),
            ),
          ],
          OutlinedButton(
            onPressed: () => openExternal(
              context,
              Uri.parse(
                'https://safekorea.go.kr/safekorea-kor/flsm/flsm/facilitiesSafteyMap.do?menuSn=235',
              ),
            ),
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
          Text('원자료 갱신: ${shelter.updatedAt}\n현재 개방·수용 여유·현장 위험 미확인'),
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
            for (final shelter in items.take(50))
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
