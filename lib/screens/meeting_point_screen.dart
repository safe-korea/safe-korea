import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/local_store.dart';
import '../widgets/common.dart';
import '../widgets/map_load_status.dart';

class MeetingPointScreen extends StatefulWidget {
  const MeetingPointScreen({
    super.key,
    required this.title,
    this.initialPoint,
    this.readOnly = false,
    this.tileProviderFactory,
  });
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

  void _select(LatLng value) {
    if (widget.readOnly || _zoom < 14 || _status.failed || _status.loading) {
      return;
    }
    final point = MeetingPoint(value.latitude, value.longitude);
    if (point.isValid) setState(() => _point = point);
  }

  @override
  void dispose() {
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
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              widget.readOnly
                  ? '가족이 정한 만남 장소 · 공식 대피시설 표시가 아닙니다.'
                  : '지도를 확대한 뒤 장소를 누르세요. 공식 대피시설로 등록되는 것은 아닙니다.',
            ),
          ),
          Expanded(
            child: Stack(
              children: [
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
                        userAgentPackageName: 'kr.example.safe_korea',
                        tileProvider: _tiles,
                        tileBuilder: (context, child, tile) => ObservedMapTile(
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
                            point: LatLng(_point!.latitude, _point!.longitude),
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
                      FloatingActionButton.small(
                        heroTag: 'meeting-zoom-in',
                        tooltip: '지도 확대',
                        onPressed: () => _controller.move(
                          _controller.camera.center,
                          (_controller.camera.zoom + 1).clamp(5, 19),
                        ),
                        child: const Icon(Icons.add),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'meeting-zoom-out',
                        tooltip: '지도 축소',
                        onPressed: () => _controller.move(
                          _controller.camera.center,
                          (_controller.camera.zoom - 1).clamp(5, 19),
                        ),
                        child: const Icon(Icons.remove),
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
                        if (_status.failed) ...[
                          const Text(
                            '지도 배경을 불러오지 못했습니다. 뒤로 가서 장소 이름만 저장할 수 있습니다.',
                          ),
                          OutlinedButton(
                            onPressed: _status.retry,
                            child: const Text('지도 다시 시도'),
                          ),
                        ],
                        if (_status.loading) const Text('지도 불러오는 중…'),
                        if (_point != null)
                          Text(
                            '선택 좌표 ${_point!.latitude.toStringAsFixed(5)}, ${_point!.longitude.toStringAsFixed(5)}',
                          ),
                        if (!widget.readOnly) ...[
                          if (_zoom < 14)
                            const Text('장소를 정확히 찍을 수 있도록 더 확대하세요.'),
                          OutlinedButton(
                            onPressed:
                                _zoom < 14 || _status.failed || _status.loading
                                ? null
                                : () => _select(_controller.camera.center),
                            child: const Text('지도 중앙에 핀 놓기'),
                          ),
                          FilledButton(
                            onPressed:
                                _point == null ||
                                    _status.failed ||
                                    _status.loading
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
