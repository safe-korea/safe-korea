import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart' as kakao;

import '../models/shelter.dart';
import '../models/shelter_cluster.dart';
import 'common.dart';
import 'shelter_pin.dart';
import 'shelter_cluster_pin.dart';

class MapConfiguration {
  const MapConfiguration({
    this.nativeAppKey = const String.fromEnvironment('KAKAO_NATIVE_APP_KEY'),
  });
  final String nativeAppKey;
  bool get hasKakaoKey => nativeAppKey.trim().isNotEmpty;
}

class ShelterMap extends StatefulWidget {
  const ShelterMap({
    super.key,
    required this.shelters,
    required this.onSelected,
    this.configuration = const MapConfiguration(),
  });
  final List<Shelter> shelters;
  final ValueChanged<Shelter> onSelected;
  final MapConfiguration configuration;
  @override
  State<ShelterMap> createState() => _ShelterMapState();
}

class _ShelterMapState extends State<ShelterMap> {
  bool _failed = false;
  final _mapController = MapController();
  late int _level = widget.shelters.isEmpty ? 6 : 14;
  kakao.KakaoMapController? _nativeController;
  final _nativePois = <kakao.Poi>[];
  final _nativeStyles = <int, kakao.PoiStyle>{};
  bool _nativeUpdating = false;
  int _nativeRevision = 0;
  Future<void>? _initialization;
  Timer? _watchdog;
  static Future<void>? _sdkInitialization;
  LatLng get _center => widget.shelters.isEmpty
      ? const LatLng(36.3, 127.8)
      : LatLng(widget.shelters.first.latitude, widget.shelters.first.longitude);
  @override
  void initState() {
    super.initState();
    if (widget.configuration.hasKakaoKey) {
      _watchdog = Timer(const Duration(seconds: 25), () {
        if (mounted) setState(() => _failed = true);
      });
      _initialization = _sdkInitialization ??= kakao.KakaoMapSdk.instance
          .initialize(widget.configuration.nativeAppKey)
          .timeout(const Duration(seconds: 15));
    }
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _markers(kakao.KakaoMapController controller) {
    _watchdog?.cancel();
    _nativeController = controller;
    _nativePois.clear();
    _nativeStyles.clear();
    _nativeRevision++;
    _refreshNative();
  }

  Future<void> _refreshNative() async {
    if (_nativeUpdating || _nativeController == null || _failed || !mounted) {
      return;
    }
    _nativeUpdating = true;
    final controller = _nativeController!;
    final revision = _nativeRevision;
    try {
      for (final poi in [..._nativePois]) {
        if (!mounted || !identical(controller, _nativeController)) return;
        await controller.labelLayer.removePoi(poi);
      }
      _nativePois.clear();
      for (final cluster in clusterShelters(
        widget.shelters,
        _level.toDouble(),
      )) {
        if (!mounted || !identical(controller, _nativeController)) return;
        final count = cluster.isSingle ? 1 : cluster.members.length;
        if (!_nativeStyles.containsKey(count)) {
          final size = cluster.isSingle
              ? const Size(44, 56)
              : const Size(52, 52);
          final image = await kakao.KImage.fromWidget(
            cluster.isSingle
                ? const ShelterPin()
                : ShelterClusterPin(count: count),
            size,
            context: context,
          );
          if (!mounted ||
              _failed ||
              !identical(controller, _nativeController)) {
            return;
          }
          _nativeStyles[count] = kakao.PoiStyle(
            icon: image,
            anchor: kakao.KPoint(0.5, cluster.isSingle ? 1.0 : 0.5),
          );
        }
        final poi = await controller.labelLayer.addPoi(
          kakao.LatLng(cluster.latitude, cluster.longitude),
          style: _nativeStyles[count]!,
          id: cluster.id,
          onClick: () => _activateCluster(cluster, native: true),
        );
        if (!mounted || _failed || !identical(controller, _nativeController)) {
          return;
        }
        _nativePois.add(poi);
      }
    } catch (_) {
      if (mounted && identical(controller, _nativeController)) {
        setState(() => _failed = true);
      }
    } finally {
      _nativeUpdating = false;
      if (mounted && !_failed && revision != _nativeRevision) _refreshNative();
    }
  }

  Future<void> _activateCluster(
    ShelterCluster cluster, {
    bool native = false,
  }) async {
    if (!mounted) return;
    if (cluster.isSingle) {
      widget.onSelected(cluster.members.single);
      return;
    }
    if (_level >= 18) {
      _chooseCluster(cluster);
      return;
    }
    final next = (_level + 2).clamp(0, 18);
    if (native) {
      try {
        await _nativeController?.moveCamera(
          kakao.CameraUpdate.newCenterPosition(
            kakao.LatLng(cluster.latitude, cluster.longitude),
            zoomLevel: next,
          ),
        );
      } catch (_) {
        if (mounted) setState(() => _failed = true);
      }
    } else {
      _mapController.move(
        LatLng(cluster.latitude, cluster.longitude),
        next.toDouble(),
      );
    }
  }

  void _chooseCluster(ShelterCluster cluster) {
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.65,
          child: ListView.builder(
            itemCount: cluster.members.length + 1,
            itemBuilder: (_, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '가까운 위치의 대피소 ${cluster.members.length}곳',
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '시설 이름과 주소를 확인한 뒤 선택하세요. 숫자 표시 위치가 실제 출입구를 뜻하지는 않습니다.',
                      ),
                    ],
                  ),
                );
              }
              final shelter = cluster.members[index - 1];
              return ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(shelter.name),
                subtitle: Text(shelter.address),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(sheetContext);
                  widget.onSelected(shelter);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initialization == null || _failed) return _fallback();
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _fallback();
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(semanticsLabel: '지도 준비 중'),
          );
        }
        return kakao.KakaoMap(
          option: kakao.KakaoMapOption(
            position: kakao.LatLng(_center.latitude, _center.longitude),
            zoomLevel: widget.shelters.isEmpty ? 7 : 14,
          ),
          onMapReady: _markers,
          onCameraMoveEnd: (position, gesture) {
            if (_level == position.zoomLevel) return;
            _level = position.zoomLevel;
            _nativeRevision++;
            _refreshNative();
          },
          onMapError: (_) {
            if (mounted) setState(() => _failed = true);
          },
        );
      },
    );
  }

  Widget _fallback() => Stack(
    children: [
      FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _center,
          initialZoom: _level.toDouble(),
          initialCameraFit: widget.shelters.length > 1
              ? CameraFit.coordinates(
                  coordinates: [
                    for (final s in widget.shelters)
                      LatLng(s.latitude, s.longitude),
                  ],
                  padding: const EdgeInsets.all(56),
                  maxZoom: 15,
                )
              : null,
          onMapReady: () {
            final level = _mapController.camera.zoom.floor();
            if (mounted && level != _level) setState(() => _level = level);
          },
          onPositionChanged: (camera, hasGesture) {
            final level = camera.zoom.floor();
            if (level != _level) setState(() => _level = level);
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'kr.example.safe_korea',
          ),
          MarkerLayer(
            markers: [
              for (final cluster in clusterShelters(
                widget.shelters,
                _level.toDouble(),
              ))
                Marker(
                  point: LatLng(cluster.latitude, cluster.longitude),
                  width: cluster.isSingle ? 48 : 52,
                  height: cluster.isSingle ? 58 : 52,
                  alignment: cluster.isSingle
                      ? Alignment.topCenter
                      : Alignment.center,
                  child: Semantics(
                    button: true,
                    label: cluster.isSingle
                        ? '${cluster.members.single.name} 대피소 상세'
                        : '대피소 ${cluster.members.length}곳 묶음 확대',
                    child: GestureDetector(
                      onTap: () => _activateCluster(cluster),
                      onLongPress: cluster.isSingle
                          ? null
                          : () => _chooseCluster(cluster),
                      child: cluster.isSingle
                          ? const ShelterPin()
                          : ShelterClusterPin(count: cluster.members.length),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      Positioned(
        top: 8,
        left: 8,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              widget.configuration.hasKakaoKey
                  ? '연결 문제로 기본 지도 표시 중'
                  : '기본 지도\n숫자는 대피소 묶음 · 누르면 확대',
              style: const TextStyle(fontSize: 12, color: ink),
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 0,
        left: 0,
        child: Material(
          color: Colors.white.withValues(alpha: 0.95),
          child: InkWell(
            onTap: () => openExternal(
              context,
              Uri.parse('https://www.openstreetmap.org/copyright'),
            ),
            child: const Padding(
              padding: EdgeInsets.all(9),
              child: Text(
                '© OpenStreetMap contributors',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
