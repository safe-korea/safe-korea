import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/local_store.dart';
import '../services/map_sdk.dart';
import '../widgets/shelter_map.dart' show MapConfiguration;

import 'package:kakao_map_sdk/kakao_map_sdk.dart' as kakao;

import '../widgets/common.dart';
import '../widgets/map_load_status.dart';

class MeetingPointScreen extends StatefulWidget {
  const MeetingPointScreen({
    super.key,
    required this.title,
    this.initialPoint,
    this.readOnly = false,
    this.tileProviderFactory,
    this.configuration = const MapConfiguration(),
  });
  final MapConfiguration configuration;
  final String title;
  final MeetingPoint? initialPoint;
  final bool readOnly;
  final TileProvider Function()? tileProviderFactory;
  @override
  State<MeetingPointScreen> createState() => _MeetingPointScreenState();
}

class _MeetingPointScreenState extends State<MeetingPointScreen> {
  final _controller = MapController();
  final _status = MapLoadStatus();
  late final _tiles = widget.tileProviderFactory?.call();
  late MeetingPoint? _point = widget.initialPoint;
  late double _zoom = _point == null ? 7 : 16;

  bool get _native =>
      widget.configuration.hasKakaoKey && widget.tileProviderFactory == null;
  bool _nativeLoading = true;
  bool _nativeFailed = false;
  bool _pinBusy = false;
  int _attempt = 0;
  Timer? _watchdog;
  kakao.KakaoMapController? _nativeController;
  kakao.Poi? _pin;
  Future<void>? _initialization;
  bool get _loading => _native ? _nativeLoading : _status.loading;
  bool get _failed => _native ? _nativeFailed : _status.failed;

  @override
  void initState() {
    super.initState();
    if (_native) _startNative();
  }

  void _startNative() {
    _watchdog?.cancel();
    _attempt++;
    final attempt = _attempt;
    _nativeLoading = true;
    _nativeFailed = false;
    _nativeController = null;
    _pin = null;
    _initialization = initializeMapSdk(widget.configuration.nativeAppKey);
    _initialization!.catchError((Object _) {
      if (mounted && attempt == _attempt) _failNative();
    });
    _watchdog = Timer(const Duration(seconds: 25), () {
      if (mounted && attempt == _attempt) _failNative();
    });
  }

  void _failNative() {
    _watchdog?.cancel();
    if (mounted) {
      setState(() {
        _nativeFailed = true;
        _nativeLoading = false;
      });
    }
  }

  Future<void> _renderPin(MeetingPoint point) async {
    final controller = _nativeController;
    if (controller == null || _pinBusy) return;
    setState(() => _pinBusy = true);
    try {
      final position = kakao.LatLng(point.latitude, point.longitude);
      if (_pin == null) {
        final icon = await kakao.KImage.fromWidget(
          const Icon(Icons.location_pin, color: teal, size: 48),
          const Size(48, 56),
          context: context,
        );
        if (!mounted || controller != _nativeController) return;
        _pin = await controller.labelLayer.addPoi(
          position,
          style: kakao.PoiStyle(icon: icon, anchor: const kakao.KPoint(.5, 1)),
          id: 'family-meeting-point',
        );
      } else {
        await _pin!.move(position);
      }
      if (mounted && controller == _nativeController) {
        setState(() => _point = point);
      }
    } catch (_) {
      _failNative();
    } finally {
      if (mounted) setState(() => _pinBusy = false);
    }
  }

  Future<void> _changeZoom(int delta) async {
    if (!_native) {
      _controller.move(
        _controller.camera.center,
        (_controller.camera.zoom + delta).clamp(5, 19),
      );
      return;
    }
    try {
      final camera = await _nativeController!.getCameraPosition();
      if (!mounted) return;
      await _nativeController!.moveCamera(
        kakao.CameraUpdate.newCenterPosition(
          camera.position,
          zoomLevel: (camera.zoomLevel + delta).clamp(5, 19),
        ),
      );
    } catch (_) {
      _failNative();
    }
  }

  Future<void> _selectCenter() async {
    if (!_native) {
      _select(_controller.camera.center);
      return;
    }
    try {
      final camera = await _nativeController!.getCameraPosition();
      if (!mounted) return;
      _zoom = camera.zoomLevel.toDouble();
      _select(LatLng(camera.position.latitude, camera.position.longitude));
    } catch (_) {
      _failNative();
    }
  }

  Widget _nativeMap() => FutureBuilder<void>(
    future: _initialization,
    builder: (context, snapshot) {
      if (snapshot.hasError || _nativeFailed) {
        return const Center(child: Icon(Icons.map_outlined, size: 64));
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(
          child: CircularProgressIndicator(semanticsLabel: '카카오 지도 준비 중'),
        );
      }
      final attempt = _attempt;
      return kakao.KakaoMap(
        key: ValueKey(attempt),
        option: kakao.KakaoMapOption(
          position: kakao.LatLng(
            _point?.latitude ?? 36.3,
            _point?.longitude ?? 127.8,
          ),
          zoomLevel: _point == null ? 7 : 16,
        ),
        onMapReady: (controller) async {
          if (!mounted || attempt != _attempt) return;
          _watchdog?.cancel();
          setState(() {
            _nativeController = controller;
            _nativeLoading = false;
          });
          if (_point != null) await _renderPin(_point!);
        },
        onMapClick: (_, point) =>
            _select(LatLng(point.latitude, point.longitude)),
        onCameraMoveEnd: (camera, _) {
          if (mounted && attempt == _attempt) {
            setState(() => _zoom = camera.zoomLevel.toDouble());
          }
        },
        onMapError: (_) {
          if (attempt == _attempt) _failNative();
        },
      );
    },
  );

  void _select(LatLng value) {
    if (widget.readOnly || _zoom < 14 || _failed || _loading || _pinBusy) {
      return;
    }
    final point = MeetingPoint(value.latitude, value.longitude);
    if (point.isValid) {
      if (_native) {
        _renderPin(point);
      } else {
        setState(() => _point = point);
      }
    }
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _controller.dispose();
    _status.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                if (_native)
                  _nativeMap()
                else
                  FlutterMap(
                    mapController: _controller,
                    options: MapOptions(
                      initialCenter: _point == null
                          ? const LatLng(36.3, 127.8)
                          : LatLng(_point!.latitude, _point!.longitude),
                      initialZoom: _zoom,
                      minZoom: 5,
                      maxZoom: 19,
                      onTap: (_, point) => _select(point),
                      onPositionChanged: (camera, _) {
                        if (_zoom.floor() != camera.zoom.floor()) {
                          setState(() => _zoom = camera.zoom);
                        }
                      },
                    ),
                    children: [
                      ListenableBuilder(
                        listenable: _status,
                        builder: (context, _) => TileLayer(
                          key: ValueKey(_status.generation),
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'kr.safekor.app',
                          tileProvider: _tiles,
                          tileBuilder: (context, child, tile) =>
                              ObservedMapTile(
                                key: ObjectKey(tile),
                                tile: tile,
                                status: _status,
                                attempt: _status.generation,
                                child: child,
                              ),
                        ),
                      ),
                      if (_point != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(
                                _point!.latitude,
                                _point!.longitude,
                              ),
                              width: 48,
                              height: 56,
                              alignment: Alignment.topCenter,
                              child: Semantics(
                                label: '가족 만남 장소 핀',
                                child: const Icon(
                                  Icons.location_pin,
                                  color: teal,
                                  size: 48,
                                ),
                              ),
                            ),
                          ],
                        ),
                      RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution(
                            'OpenStreetMap contributors',
                            onTap: () => openExternal(
                              context,
                              Uri.parse(
                                'https://www.openstreetmap.org/copyright',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Column(
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: FloatingActionButton.small(
                          heroTag: 'meeting-zoom-in',
                          tooltip: '지도 확대',
                          onPressed: _loading || _failed
                              ? null
                              : () => _changeZoom(1),
                          child: const Icon(Icons.add),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: FloatingActionButton.small(
                          heroTag: 'meeting-zoom-out',
                          tooltip: '지도 축소',
                          onPressed: _loading || _failed
                              ? null
                              : () => _changeZoom(-1),
                          child: const Icon(Icons.remove),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            flex: 0,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.4,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListenableBuilder(
                    listenable: _status,
                    builder: (context, _) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _native ? '카카오 지도 · 인터넷 연결 필요' : '기본 지도 · 인터넷 연결 필요',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.readOnly ? '가족이 정한 장소입니다. 공식 대피시설과는 달라요.' : '확대 후 장소를 누르거나 중앙에 핀을 놓으세요. 가족 약속용이며 공식 대피시설이 아닙니다.',
                        ),
                        const SizedBox(height: 12),
                        if (_failed) ...[
                          const Text(
                            '지도 배경을 불러오지 못했습니다. 인터넷 연결을 확인하세요. 저장된 좌표는 유지됩니다. 뒤로 가면 장소 이름과 약속을 볼 수 있어요.',
                          ),
                          OutlinedButton(
                            onPressed: () {
                              if (_native) {
                                setState(_startNative);
                              } else {
                                _status.retry();
                              }
                            },
                            child: const Text('지도 다시 시도'),
                          ),
                        ],
                        if (_loading) const Text('지도 불러오는 중…'),
                        if (_point != null)
                          Text(
                            '선택 좌표 ${_point!.latitude.toStringAsFixed(5)}, ${_point!.longitude.toStringAsFixed(5)}',
                          ),
                        if (!widget.readOnly) ...[
                          if (_zoom < 14)
                            const Text('장소를 정확히 찍을 수 있도록 더 확대하세요.'),
                          OutlinedButton(
                            onPressed:
                                _zoom < 14 || _failed || _loading || _pinBusy
                                ? null
                                : _selectCenter,
                            child: const Text('지도 중앙에 핀 놓기'),
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed:
                                _point == null ||
                                    _failed ||
                                    _loading ||
                                    _pinBusy
                                ? null
                                : () => Navigator.pop(context, _point),
                            child: const Text('이 위치 선택'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
