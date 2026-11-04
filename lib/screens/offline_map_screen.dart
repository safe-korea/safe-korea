import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/offline_area.dart';
import '../services/location_service.dart';
import '../models/shelter.dart';

class OfflineMapLink extends StatelessWidget {
  const OfflineMapLink({super.key, required this.shelter});
  final Shelter shelter;
  @override
  Widget build(BuildContext context) => !OfflineArea.covers(shelter)
      ? const SizedBox.shrink()
      : OutlinedButton.icon(
          icon: const Icon(Icons.offline_pin_outlined),
          label: const Text('주변 오프라인 지도 보기'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => OfflineMapScreen(initialId: shelter.id),
            ),
          ),
        );
}

class OfflineMapScreen extends StatefulWidget {
  const OfflineMapScreen({
    super.key,
    this.initialId,
    this.savedArea,
    this.title,
    this.showMyLocation = false,
    this.locationService,
  });
  final OfflineArea? savedArea;
  final String? initialId;
  final String? title;
  // GPS works without internet; the position is used only on this screen.
  final bool showMyLocation;
  final LocationService? locationService;
  @override
  State<OfflineMapScreen> createState() => _OfflineMapScreenState();
}

class _OfflineMapScreenState extends State<OfflineMapScreen> {
  late final _area = widget.savedArea == null
      ? OfflineArea.load()
      : Future.value(widget.savedArea!);
  final _transform = TransformationController();
  String? _selectedId;
  Position? _me;
  String? _meMessage;
  bool _locating = false;

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _meMessage = null;
    });
    try {
      final here = await (widget.locationService ?? LocationService())
          .current();
      if (mounted) setState(() => _me = here);
    } on LocationFailure catch (e) {
      if (mounted) setState(() => _meMessage = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _meMessage = '위치를 확인하지 못했어요. 지도에서 주변 도로 이름으로 찾아보세요.');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialId;
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _sources(OfflineArea area) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('지도 범위와 출처'),
      content: SingleChildScrollView(
        child: Text(
          '${widget.showMyLocation ? '저장한 시·군·구 범위의 지도입니다. 내 위치는 GPS로 이 기기에서만 계산하며 서버로 보내지 않아요.' : '선택한 대피소 주변을 저장한 지도입니다.'} 전국 지도는 아닙니다.\n\n'
          '지도: © OpenStreetMap contributors / Geofabrik, ODbL 1.0\n'
          '원본: 2026-11-01 배포 파일\n준비: ${area.map['preparedAt']}\n'
          'https://www.openstreetmap.org/copyright\n\n'
          '대피시설: ${area.catalog.sourceName}\n공식 조회: ${area.catalog.retrievedAt}\n시설별 갱신일: 미제공\n\n'
          '기호는 공식 목록의 시설 좌표이며 실제 출입구가 아닐 수 있습니다. 도로·건물·시설의 누락 또는 변경이 있을 수 있어요. 거리는 직선거리이며 경로 안내는 제공하지 않습니다. 현장 통제를 우선하세요.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('확인'),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.title ??
            (widget.savedArea == null ? '잠실 주변 오프라인 지도' : '저장한 주변 지도'),
      ),
    ),
    body: FutureBuilder<OfflineArea>(
      future: _area,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('동봉 지도를 열지 못했어요. 저장한 주소와 행동요령을 확인하세요.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final area = snapshot.data!;
        final bounds = (area.map['bounds'] as List).cast<num>();
        final shelters = area.catalog.shelters;
        final selected = shelters.where((s) => s.id == _selectedId).firstOrNull;
        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.showMyLocation
                            ? '인터넷 없이 사용 · 길찾기 없음'
                            : '인터넷 없이 사용 · 현재 위치·길찾기 없음',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _sources(area),
                      child: const Text('출처·범위'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Geographic aspect ratio is preserved; never stretch the map to fit.
                    final ratio =
                        (bounds[3] - bounds[1]) /
                        ((bounds[2] - bounds[0]) *
                            math.cos(
                              (bounds[1] + bounds[3]) / 2 * math.pi / 180,
                            ));
                    final width = math.min(
                      constraints.maxWidth,
                      constraints.maxHeight / ratio,
                    );
                    final height = width * ratio;
                    final size = Size(width, height);
                    return ClipRect(
                      child: InteractiveViewer(
                        transformationController: _transform,
                        minScale: 1,
                        maxScale: _maxScale(bounds),
                        child: Center(
                          child: SizedBox(
                            width: width,
                            height: height,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _MapPainter(
                                      area.map['features'] as List,
                                      bounds,
                                    ),
                                  ),
                                ),
                                for (var i = 0; i < shelters.length; i++)
                                  Positioned(
                                    left:
                                        _point(
                                          shelters[i].longitude,
                                          shelters[i].latitude,
                                          size,
                                          bounds,
                                        ).dx -
                                        20,
                                    top:
                                        _point(
                                          shelters[i].longitude,
                                          shelters[i].latitude,
                                          size,
                                          bounds,
                                        ).dy -
                                        20,
                                    child: Semantics(
                                      button: true,
                                      label: '${i + 1}번 ${shelters[i].name}',
                                      child: GestureDetector(
                                        onTap: () => setState(
                                          () => _selectedId = shelters[i].id,
                                        ),
                                        child: SizedBox(
                                          width: 40,
                                          height: 40,
                                          child: Center(
                                            child: Container(
                                              width:
                                                  selected?.id == shelters[i].id
                                                  ? 28
                                                  : 22,
                                              height:
                                                  selected?.id == shelters[i].id
                                                  ? 28
                                                  : 22,
                                              decoration: BoxDecoration(
                                                color:
                                                    selected?.id ==
                                                        shelters[i].id
                                                    ? const Color(0xFFB42318)
                                                    : const Color(0xFF086B50),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 2,
                                                ),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                '${i + 1}',
                                                textScaler:
                                                    TextScaler.noScaling,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (_me != null && _inside(_me!, bounds))
                                  Positioned(
                                    left:
                                        _point(
                                          _me!.longitude,
                                          _me!.latitude,
                                          size,
                                          bounds,
                                        ).dx -
                                        10,
                                    top:
                                        _point(
                                          _me!.longitude,
                                          _me!.latitude,
                                          size,
                                          bounds,
                                        ).dy -
                                        10,
                                    child: Semantics(
                                      label: '내 위치',
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1A73E8),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                const Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Text(
                                    '↑ 북',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      backgroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '© OpenStreetMap contributors · ODbL · 대피소: 행정안전부',
                  style: TextStyle(fontSize: 11),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: '지도 축소',
                    onPressed: () => _zoom(1 / 1.5),
                    icon: const Icon(Icons.zoom_out),
                  ),
                  TextButton(
                    onPressed: () => _transform.value = Matrix4.identity(),
                    child: const Text('전체 범위'),
                  ),
                  IconButton(
                    tooltip: '지도 확대',
                    onPressed: () => _zoom(1.5),
                    icon: const Icon(Icons.zoom_in),
                  ),
                ],
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .32,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.showMyLocation) ...[
                        OutlinedButton.icon(
                          onPressed: _locating ? null : _locate,
                          icon: const Icon(Icons.my_location),
                          label: Text(
                            _locating
                                ? '위치 확인 중…'
                                : _me == null
                                ? '내 위치 확인 (GPS)'
                                : '내 위치 다시 확인',
                          ),
                        ),
                        if (_meMessage != null)
                          Text(
                            _meMessage!,
                            style: const TextStyle(fontSize: 14),
                          ),
                        if (_me != null) ...[
                          const SizedBox(height: 6),
                          SelectableText(_coordinates(_me!)),
                          if (!_inside(_me!, bounds))
                            const Text(
                              '지금 위치는 저장한 지도 범위 밖이에요.',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          for (final (shelter, meters) in _nearest(
                            _me!,
                            shelters,
                          ))
                            TextButton(
                              style: TextButton.styleFrom(
                                alignment: Alignment.centerLeft,
                              ),
                              onPressed: () =>
                                  setState(() => _selectedId = shelter.id),
                              child: Text(
                                '${shelters.indexOf(shelter) + 1}. ${shelter.name} · ${_direction(_me!, shelter)} 직선 ${_distance(meters)}',
                              ),
                            ),
                        ],
                        const SizedBox(height: 8),
                      ],
                      DropdownButtonFormField<String>(
                        // Let the field grow with large system text instead of clipping.
                        isDense: false,
                        itemHeight: null,
                        key: ValueKey(_selectedId),
                        initialValue: selected?.id,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: '저장한 대피소 ${shelters.length}곳',
                        ),
                        items: [
                          for (var i = 0; i < shelters.length; i++)
                            DropdownMenuItem(
                              value: shelters[i].id,
                              child: Text(
                                '${i + 1}. ${shelters[i].name}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (id) => setState(() => _selectedId = id),
                      ),
                      if (selected != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          selected.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        SelectableText(selected.address),
                      ] else
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('번호 핀이나 목록에서 시설을 선택하세요.'),
                        ),
                      const SizedBox(height: 4),
                      const Text(
                        '개방 여부·안전한 이동 경로를 보장하지 않아요.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
  // A district is several km wide: allow zooming down to street level.
  static double _maxScale(List<num> b) {
    final km =
        (b[2] - b[0]) * 111.32 * math.cos((b[1] + b[3]) / 2 * math.pi / 180);
    return (km / 0.4).clamp(5.0, 30.0);
  }

  static bool _inside(Position p, List<num> b) =>
      p.longitude >= b[0] &&
      p.longitude <= b[2] &&
      p.latitude >= b[1] &&
      p.latitude <= b[3];

  static double _meters(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1), dLon = rad(lon2 - lon1);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat1)) *
            math.cos(rad(lat2)) *
            math.pow(math.sin(dLon / 2), 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  static List<(Shelter, double)> _nearest(Position p, List<Shelter> all) {
    final list = [
      for (final s in all)
        (s, _meters(p.latitude, p.longitude, s.latitude, s.longitude)),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    return list.take(3).toList();
  }

  static String _direction(Position p, Shelter s) {
    final dy = s.latitude - p.latitude;
    final dx =
        (s.longitude - p.longitude) * math.cos(p.latitude * math.pi / 180);
    final deg = (math.atan2(dx, dy) * 180 / math.pi + 360) % 360;
    const names = ['북', '북동', '동', '남동', '남', '남서', '서', '북서'];
    return names[((deg + 22.5) ~/ 45) % 8];
  }

  static String _distance(double m) => m < 1000
      ? '${(m / 10).round() * 10}m'
      : '${(m / 1000).toStringAsFixed(1)}km';

  static String _coordinates(Position p) {
    final t = p.timestamp.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '내 위치 북위 ${p.latitude.toStringAsFixed(5)}° · 동경 ${p.longitude.toStringAsFixed(5)}°\n오차 ±${p.accuracy.round()}m · ${two(t.hour)}:${two(t.minute)} 확인';
  }

  void _zoom(double factor) {
    final current = _transform.value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(
      1.0,
      widget.showMyLocation ? 30.0 : 5.0,
    );
    _transform.value = Matrix4.identity()..scaleByDouble(next, next, 1, 1);
  }
}

Offset _point(double lon, double lat, Size size, List<num> bounds) => Offset(
  (lon - bounds[0]) / (bounds[2] - bounds[0]) * size.width,
  (bounds[3] - lat) / (bounds[3] - bounds[1]) * size.height,
);

class _MapPainter extends CustomPainter {
  _MapPainter(this.features, this.bounds);
  final List<num> bounds;
  final List features;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawColor(const Color(0xFFF4F1E8), BlendMode.src);
    final occupied = <Rect>[];
    final labels = <(String, Offset)>[];
    final usedNames = <String>{};
    for (final kind in ['park', 'water', 'building', 'road']) {
      for (final feature in features.where((f) => f['kind'] == kind)) {
        final points = (feature['points'] as List)
            .map(
              (p) => _point(
                (p[0] as num).toDouble(),
                (p[1] as num).toDouble(),
                size,
                bounds,
              ),
            )
            .toList();
        if (points.length < 2) continue;
        final path = Path()..fillType = PathFillType.evenOdd;
        path.moveTo(points.first.dx, points.first.dy);
        for (final point in points.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        final major = [
          'primary',
          'secondary',
          'tertiary',
          'trunk',
        ].contains(feature['type']);
        final paint = Paint()..isAntiAlias = true;
        if (kind == 'road') {
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = major ? 5 : 1.8;
          paint.color = major ? const Color(0xFFD4B878) : Colors.white;
        } else {
          path.close();
          for (final hole in (feature['holes'] as List? ?? [])) {
            final ring = (hole as List)
                .map(
                  (p) => _point(
                    (p[0] as num).toDouble(),
                    (p[1] as num).toDouble(),
                    size,
                    bounds,
                  ),
                )
                .toList();
            if (ring.isEmpty) continue;
            path.moveTo(ring.first.dx, ring.first.dy);
            for (final point in ring.skip(1)) {
              path.lineTo(point.dx, point.dy);
            }
            path.close();
          }
          paint.color = kind == 'water'
              ? const Color(0xFFB5DCE7)
              : kind == 'park'
              ? const Color(0xFFCBE2BB)
              : const Color(0xFFDDD9CF);
        }
        canvas.drawPath(path, paint);
        final name = feature['name'] as String;
        if (name.isEmpty || (kind != 'water' && !(kind == 'road' && major))) {
          continue;
        }
        labels.add((name, points[points.length ~/ 2]));
      }
    }
    for (final (name, anchor) in labels) {
      if (usedNames.contains(name)) continue;
      final label = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: name,
          style: const TextStyle(
            fontFamily: 'SafeKoreaWeb',
            fontSize: 10,
            color: Color(0xFF334E45),
            backgroundColor: Color(0xDDFFFFFF),
          ),
        ),
      )..layout(maxWidth: 100);
      final rect = Rect.fromLTWH(
        anchor.dx,
        anchor.dy,
        label.width,
        label.height,
      ).inflate(3);
      if (!(Offset.zero & size).contains(rect.topLeft) ||
          !(Offset.zero & size).contains(rect.bottomRight) ||
          occupied.any((r) => r.overlaps(rect))) {
        continue;
      }
      occupied.add(rect);
      usedNames.add(name);
      label.paint(canvas, anchor);
    }
    final scaleWidth =
        size.width *
        200 /
        ((bounds[2] - bounds[0]) *
            111320 *
            math.cos((bounds[1] + bounds[3]) / 2 * math.pi / 180));
    final scale = Paint()
      ..color = const Color(0xFF17352D)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(12, size.height - 12),
      Offset(12 + scaleWidth, size.height - 12),
      scale,
    );
    TextPainter(
        textDirection: TextDirection.ltr,
        text: const TextSpan(
          text: '200m',
          style: TextStyle(
            fontFamily: 'SafeKoreaWeb',
            fontSize: 10,
            color: Color(0xFF17352D),
            backgroundColor: Colors.white,
          ),
        ),
      )
      ..layout()
      ..paint(canvas, Offset(12, size.height - 28));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) =>
      oldDelegate.features != features;
}
