import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/offline_area.dart';
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
  const OfflineMapScreen({super.key, this.initialId, this.savedArea});
  final OfflineArea? savedArea;
  final String? initialId;
  @override
  State<OfflineMapScreen> createState() => _OfflineMapScreenState();
}

class _OfflineMapScreenState extends State<OfflineMapScreen> {
  late final _area = widget.savedArea == null
      ? OfflineArea.load()
      : Future.value(widget.savedArea!);
  final _transform = TransformationController();
  String? _selectedId;
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
          '선택한 대피소 주변을 저장한 지도입니다. 전국 지도는 아닙니다.\n\n'
          '지도: © OpenStreetMap contributors / Geofabrik, ODbL 1.0\n'
          '원본: 2026-11-01 배포 파일\n준비: ${area.map['preparedAt']}\n'
          'https://www.openstreetmap.org/copyright\n\n'
          '대피시설: ${area.catalog.sourceName}\n공식 조회: ${area.catalog.retrievedAt}\n시설별 갱신일: 미제공\n\n'
          '기호는 공식 목록의 시설 좌표이며 실제 출입구가 아닐 수 있습니다. 도로·건물·시설의 누락 또는 변경이 있을 수 있어요. 현재 위치와 경로 안내는 제공하지 않으며 현장 통제를 우선하세요.',
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
      title: Text(widget.savedArea == null ? '잠실 주변 오프라인 지도' : '저장한 주변 지도'),
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
                    const Expanded(
                      child: Text(
                        '인터넷 없이 사용 · 현재 위치·길찾기 없음',
                        style: TextStyle(fontSize: 13),
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
                        maxScale: 5,
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
                      DropdownButtonFormField<String>(
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
  void _zoom(double factor) {
    final current = _transform.value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(1.0, 5.0);
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
