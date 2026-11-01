import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/shelter.dart';
import '../services/location_service.dart';
import '../services/region_suggestion_service.dart';
import '../services/shelter_repository.dart';
import '../services/saved_shelters_controller.dart';
import 'saved_shelters_screen.dart';
import 'shelter_record_screen.dart';
import '../widgets/common.dart';
import '../models/public_shelter_photo.dart';
import '../widgets/public_shelter_photo.dart';
import '../widgets/shelter_street_view_button.dart';
import '../widgets/shelter_map.dart';

class SheltersScreen extends StatefulWidget {
  const SheltersScreen({
    super.key,
    this.catalog,
    this.locationService,
    this.repository,
    this.savedShelters,
    this.regionService,
  });
  final ShelterCatalog? catalog;
  final LocationService? locationService;
  final RegionSuggestionService? regionService;
  final ShelterRepository? repository;
  final SavedSheltersController? savedShelters;
  @override
  State<SheltersScreen> createState() => _SheltersScreenState();
}

class _SheltersScreenState extends State<SheltersScreen> {
  late final ShelterRepository _repository =
      widget.repository ?? ShelterRepository();
  late final _saved = widget.savedShelters ?? SavedSheltersController.shared;
  List<Map<String, dynamic>> _provinces = [];
  String _province = '11';
  String? _district = '11110';
  bool _fetching = false, _choosingRegion = true, _queryFailed = false;
  String? _networkMessage;
  ShelterCatalog? _catalog;
  Position? _position;
  bool _locating = false, _map = false;
  String? _error, _locationMessage;
  String _query = '';
  bool _suggesting = false;
  String? _regionMessage;
  RegionSuggestion? _suggestion;
  @override
  void initState() {
    super.initState();
    _load();
    _saved.ensureLoaded();
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
          _choosingRegion = catalog.retrievedAt == null;
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
    final districtCode = _district;
    if (districtCode == null) return;
    final province = _provinces.firstWhere((p) => p['code'] == _province);
    final district = _districts.firstWhere((d) => d['code'] == districtCode);
    setState(() {
      _fetching = true;
      _queryFailed = false;
      _networkMessage = null;
    });
    try {
      final catalog = await _repository.fetch(
        districtCode,
        '${province['name']} ${district['name']}',
      );
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _choosingRegion = false;
        _map = false;
        _query = '';
      });
      try {
        await _repository.save(catalog);
        if (mounted) {
          setState(
            () => _networkMessage =
                '공식 지도에서 ${catalog.shelters.length}건 저장 · 목록은 오프라인 사용 가능',
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
    } on ConflictingShelterIdentity {
      if (mounted) {
        _queryFailed = true;
        setState(
          () => _networkMessage = '공식 자료의 같은 시설 번호에 서로 다른 정보가 있어 구분할 수 없습니다. 기존 자료를 유지합니다. 정부 공식 시설 검색에서 확인해 주세요.',
        );
      }
    } on IncompleteShelterResponse catch (error) {
      if (mounted) {
        _queryFailed = true;
        setState(
          () => _networkMessage =
              '공식 자료는 전체 ${error.total}건인데 지도 목록은 ${error.mapCount}건으로 건수가 일치하지 않습니다. 기존 자료를 유지합니다. 정부 공식 시설 검색에서 확인해 주세요.',
        );
      }
    } catch (_) {
      if (mounted) {
        _queryFailed = true;
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
              '현재 위치 확인 · 오차 약 ${position.accuracy.round()}m\n확인 ${_formatTime(position.timestamp.toIso8601String())} · 실시간 추적 아님';
          _map = false;
        });
      }
    } on LocationFailure catch (error) {
      if (mounted) setState(() => _locationMessage = error.message);
    } on TimeoutException {
      if (mounted) {
        setState(
          () => _locationMessage = '위치 확인 시간이 초과되었습니다. 다시 시도하거나 지역을 직접 선택하세요.',
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

  Future<void> _suggestRegion() async {
    setState(() {
      _suggesting = true;
      _regionMessage = null;
      _suggestion = null;
    });
    try {
      final position = await (widget.locationService ?? LocationService())
          .current();
      if (!mounted) return;
      final suggestion =
          await (widget.regionService ?? RegionSuggestionService()).suggest(
            position,
            _provinces,
          );
      if (!mounted) return;
      setState(() {
        _suggestion = suggestion;
        _position = position;
        _regionMessage = suggestion == null
            ? '현재 위치의 시군구를 확실하게 찾지 못했습니다. 지역을 직접 선택해 주세요.'
            : suggestion.districtCode == null
            ? '${suggestion.label}까지만 확인했습니다. 시군구는 직접 선택해 주세요.'
            : '조회 지역 제안: ${suggestion.label} · 위치 오차 약 ${position.accuracy.round()}m. 경계 부근에서는 실제 지역과 다를 수 있으니 확인하세요.';
      });
    } on LocationFailure catch (error) {
      if (mounted) setState(() => _regionMessage = error.message);
    } on TimeoutException {
      if (mounted) {
        setState(
          () => _regionMessage = '위치 또는 지역 확인 시간이 초과되었습니다. 지역을 직접 선택해 주세요.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _regionMessage = '현재 위치의 지역을 확인하지 못했습니다. 지역을 직접 선택해 주세요.',
        );
      }
    } finally {
      if (mounted) setState(() => _suggesting = false);
    }
  }

  void _applySuggestion() {
    final suggestion = _suggestion;
    if (suggestion == null) return;
    setState(() {
      _province = suggestion.provinceCode;
      _district = suggestion.districtCode;
      _choosingRegion = true;
      _suggestion = null;
      _regionMessage = suggestion.districtCode == null
          ? '${suggestion.label} 선택됨. 시군구를 직접 선택해야 조회할 수 있습니다.'
          : '${suggestion.label} 선택됨. 아래에서 지역을 확인하고 대피소 불러오기를 눌러 주세요.';
    });
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
      appBar: AppBar(
        title: const Text('주변 대피시설'),
        actions: [
          ListenableBuilder(
            listenable: _saved,
            builder: (context, _) => IconButton(
              tooltip: '저장한 대피소 (${_saved.entries.length})',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => SavedSheltersScreen(controller: _saved),
                ),
              ),
              icon: Badge(
                isLabelVisible: _saved.entries.isNotEmpty,
                label: Text('${_saved.entries.length}'),
                child: const Icon(Icons.bookmark_outline),
              ),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _saved,
        builder: (context, _) => PageBody(
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                '공습용 대피시설 · 화학 공격은 별도 행동강령 확인',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8D421F),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (!_choosingRegion && catalog != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      catalog.coverage,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(() => _choosingRegion = true),
                    child: const Text('지역 변경'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => SavedSheltersScreen(controller: _saved),
                ),
              ),
              icon: const Icon(Icons.bookmark_outline),
              label: const Text('저장한 대피소 · 오프라인 목록'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _locating || _suggesting ? null : _locate,
              icon: const Icon(Icons.my_location),
              label: Text(_locating ? '위치 확인 중…' : 'GPS 현재 위치 확인'),
            ),
            const SizedBox(height: 8),
            const Text(
              '조회한 지역 안에서 가까운 순으로 표시합니다.',
              style: TextStyle(fontSize: 14),
            ),
            if (_locationMessage != null)
              Semantics(liveRegion: true, child: Notice(_locationMessage!)),
            if (_position != null)
              TextButton(
                onPressed: _locating
                    ? null
                    : () => setState(() {
                        _position = null;
                        _locationMessage = null;
                        _map = false;
                      }),
                child: const Text('현재 위치 표시 지우기'),
              ),
            const SizedBox(height: 16),
            if (_provinces.isNotEmpty && _choosingRegion) ...[
              const Text(
                '지역을 선택하세요',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ExpansionTile(
                expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                tilePadding: EdgeInsets.zero,
                title: const Text('현재 위치로 지역 찾기'),
                children: [
                  const Text(
                    '현재 위치로 지역을 찾으면 좌표가 Apple/Google 등 기기 주소 변환 서비스에 전달될 수 있습니다. 직접 지역을 선택하면 위치를 보내지 않습니다.',
                  ),
                  OutlinedButton.icon(
                    onPressed: _suggesting || _fetching || _locating
                        ? null
                        : _suggestRegion,
                    icon: const Icon(Icons.location_searching),
                    label: Text(
                      _suggesting ? '현재 위치의 지역 확인 중…' : '위치로 조회 지역 제안받기',
                    ),
                  ),
                  if (_regionMessage != null)
                    Semantics(liveRegion: true, child: Notice(_regionMessage!)),
                  if (_suggestion?.districtCode != null) ...[
                    const Text(
                      '확인한 지역의 코드·IP를 국민안전24에 보내 시설을 조회합니다.',
                      style: TextStyle(fontSize: 14),
                    ),
                    FilledButton.icon(
                      onPressed: _fetching
                          ? null
                          : () {
                              _applySuggestion();
                              _fetch();
                            },
                      icon: const Icon(Icons.near_me_outlined),
                      label: const Text('이 지역 대피소 바로 조회'),
                    ),
                  ],
                  if (_suggestion != null)
                    OutlinedButton(
                      onPressed: _fetching ? null : _applySuggestion,
                      child: const Text('제안한 지역 선택'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('province-$_province'),
                initialValue: _province,
                isExpanded: true,
                isDense: false,
                itemHeight: null,
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
                isDense: false,
                itemHeight: null,
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
              const Text('조회 시 지역 코드·IP를 국민안전24에 전송합니다. 위치 전송 없음.'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _fetching || _suggesting || _district == null
                    ? null
                    : _fetch,
                icon: const Icon(Icons.download_outlined),
                label: Text(_fetching ? '공식 시설 조회 중…' : '선택 지역 대피소 불러오기'),
              ),
              const SizedBox(height: 12),
            ],
            if (_networkMessage != null)
              Semantics(liveRegion: true, child: Notice(_networkMessage!)),
            if (_queryFailed)
              OutlinedButton(
                onPressed: () =>
                    openExternal(context, Uri.parse(officialMapSource)),
                child: const Text('정부 공식 시설 검색 열기'),
              ),
            if (_error != null) ...[
              Notice(_error!),
              OutlinedButton(onPressed: _load, child: const Text('다시 읽기')),
            ],
            if (catalog == null && _error == null)
              const Center(child: CircularProgressIndicator()),
            if (catalog != null) ...[
              if (catalog.shelters.isEmpty && catalog.retrievedAt == null)
                const Notice(
                  '저장된 대피시설이 없습니다.\n위에서 지역을 선택해 공식 대피소를 조회하세요. 조회한 목록은 이 기기에 저장됩니다.',
                ),
              if (catalog.retrievedAt != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${catalog.coverage} · 지도 표시 ${catalog.shelters.length}곳\n조회 ${_formatTime(catalog.retrievedAt)} · 국민안전24',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              if (catalog.shelters.isEmpty && catalog.retrievedAt != null)
                const Notice(
                  '해당 지역의 공식 조회 결과가 0건입니다. 실제 시설이 없다는 뜻으로 단정하지 말고 정부 사이트나 지자체에 확인하세요.',
                ),
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  '온라인 지도: 조회 범위·IP를 지도 제공자에게 전송합니다.',
                  style: TextStyle(fontSize: 14),
                ),
              ),
              if (!_map)
                FilledButton.icon(
                  onPressed: () => setState(() => _map = true),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('온라인 지도 열기'),
                ),
              const SizedBox(height: 16),
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
              if (_map) ...[
                SizedBox(
                  height: 360,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _buildMap(items),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => Scaffold(
                            appBar: AppBar(title: const Text('대피소 지도')),
                            body: SafeArea(
                              child: ShelterMap(
                                shelters: items,
                                currentLocation: _position == null
                                    ? null
                                    : LatLng(
                                        _position!.latitude,
                                        _position!.longitude,
                                      ),
                                onSelected: (shelter) =>
                                    _showShelter(shelter, catalog),
                              ),
                            ),
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.fullscreen),
                      label: const Text('크게 보기'),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _map = false),
                      child: const Text('지도 닫기'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              ExpansionTile(
                expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                tilePadding: EdgeInsets.zero,
                title: const Text('자료 출처와 조회 시각'),
                children: [
                  InfoLine(label: '출처', value: catalog.sourceName),
                  InfoLine(label: '자료 범위', value: catalog.coverage),
                  InfoLine(
                    label: '마지막 조회',
                    value: _formatTime(catalog.retrievedAt),
                  ),
                  InfoLine(
                    label: '집계',
                    value:
                        '등재 ${catalog.officialCount ?? catalog.shelters.length}건 · 좌표 제외 ${catalog.skippedCount}건',
                  ),
                  const Text(
                    '전국 전체 목록이 아닙니다. 시설 상태는 현장에서 확인하세요.',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (items.isNotEmpty) ...[
                const Text('개방·수용 여유는 현장 확인', style: TextStyle(fontSize: 14)),
                const Text(
                  '시설을 누르면 상세 정보와 저장 버튼이 나와요.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
              ],
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
            if (!_queryFailed)
              OutlinedButton(
                onPressed: () =>
                    openExternal(context, Uri.parse(officialMapSource)),
                child: const Text('정부 공식 시설 검색 열기'),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? raw) {
    if (raw == null) return '아직 조회하지 않았어요';
    final time = DateTime.tryParse(raw)?.toLocal();
    if (time == null) return '확인할 수 없음';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}.${two(time.month)}.${two(time.day)} ${two(time.hour)}:${two(time.minute)}';
  }

  Widget _shelterCard(
    Shelter shelter, {
    ShelterCatalog? catalog,
    bool detail = false,
  }) {
    final source = catalog ?? _catalog;
    if (!detail) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showShelter(shelter, source),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shelter.name,
                        style: const TextStyle(
                          fontSize: 18,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        shelter.address,
                        style: const TextStyle(fontSize: 15, height: 1.4),
                      ),
                      if (_position != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          '직선거리 ${(shelter.distanceFrom(_position!.latitude, _position!.longitude) / 1000).toStringAsFixed(2)}km',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const ExcludeSemantics(child: Icon(Icons.chevron_right)),
              ],
            ),
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              shelter.name,
              style: const TextStyle(
                fontSize: 20,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(shelter.address, style: const TextStyle(fontSize: 16)),
            if (_position != null)
              Text(
                '직선거리 ${(shelter.distanceFrom(_position!.latitude, _position!.longitude) / 1000).toStringAsFixed(2)}km · 이동 경로 아님',
              ),
            const SizedBox(height: 8),
            const Text('개방 여부·수용 여유는 현장 확인', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            if (PublicShelterPhoto.match(source, shelter) != null) ...[
              PublicShelterPhotoCard(
                photo: PublicShelterPhoto.match(source, shelter)!,
              ),
              const SizedBox(height: 12),
            ],
            ShelterStreetViewButton(shelter: shelter),
            ExpansionTile(
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              tilePadding: EdgeInsets.zero,
              title: const Text('시설 자료 상세'),
              children: [
                InfoLine(
                  label: '원자료 갱신',
                  value: shelter.updatedAt ?? '제공되지 않음',
                ),
                const InfoLine(
                  label: '현장 상태',
                  value: '개방·수용 여유 미확인\n이동 경로 안전 미확인',
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (source != null)
              FilledButton.tonalIcon(
                onPressed: _saved.loaded && !_saved.busy && !_saved.loading
                    ? () => _toggleSaved(shelter, source)
                    : null,
                icon: Icon(
                  _saved.contains(source, shelter.id)
                      ? Icons.bookmark
                      : Icons.bookmark_add_outlined,
                ),
                label: Text(
                  _saved.contains(source, shelter.id) ? '대피소 저장 해제' : '대피소 저장',
                ),
              ),
            if (source != null &&
                _saved.entryFor(source, shelter.id) != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ShelterRecordScreen(
                      entry: _saved.entryFor(source, shelter.id)!,
                      controller: _saved,
                    ),
                  ),
                ),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('우선순위·사진·메모 추가'),
              ),
            ],
            if (!_saved.loaded && !_saved.loading)
              TextButton(
                onPressed: _saved.load,
                child: const Text('대피소 저장 기능 다시 읽기'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleSaved(Shelter shelter, ShelterCatalog catalog) async {
    final wasSaved = _saved.contains(catalog, shelter.id);
    final existing = _saved.entryFor(catalog, shelter.id);
    if (existing != null &&
        !await confirmPersonalRecordRemoval(context, existing)) {
      return;
    }
    if (!mounted) return;
    final result = await _saved.toggle(catalog, shelter.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result
              ? (wasSaved ? '저장한 대피소에서 해제했습니다.' : '이 기기에 대피소를 저장했습니다.')
              : '대피소 저장 변경에 실패했습니다. 다시 시도해 주세요.',
        ),
      ),
    );
  }

  void _showShelter(Shelter shelter, [ShelterCatalog? snapshot]) {
    final catalog = snapshot ?? _catalog;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ListenableBuilder(
        listenable: _saved,
        builder: (context, _) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _shelterCard(shelter, catalog: catalog, detail: true),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMap(List<Shelter> items) {
    final catalog = _catalog;
    return ShelterMap(
      key: ValueKey('${_catalog?.areaCode}-$_query'),
      shelters: items,
      currentLocation: _position == null
          ? null
          : LatLng(_position!.latitude, _position!.longitude),
      onSelected: (shelter) => _showShelter(shelter, catalog),
    );
  }
}
