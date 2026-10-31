import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart' as kakao;

import '../models/shelter.dart';
import 'common.dart';
import 'shelter_pin.dart';

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
    super.dispose();
  }

  Future<void> _markers(kakao.KakaoMapController controller) async {
    _watchdog?.cancel();
    try {
      final image = await kakao.KImage.fromWidget(
        const ShelterPin(),
        const Size(44, 56),
        context: context,
      );
      final style = kakao.PoiStyle(icon: image);
      for (final shelter in widget.shelters) {
        if (!mounted || _failed) return;
        await controller.labelLayer.addPoi(
          kakao.LatLng(shelter.latitude, shelter.longitude),
          style: style,
          id: shelter.id,
          onClick: () => widget.onSelected(shelter),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
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
        options: MapOptions(
          initialCenter: _center,
          initialZoom: widget.shelters.isEmpty ? 6 : 14,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'kr.example.safe_korea',
          ),
          MarkerLayer(
            markers: [
              for (final shelter in widget.shelters)
                Marker(
                  point: LatLng(shelter.latitude, shelter.longitude),
                  width: 48,
                  height: 58,
                  alignment: Alignment.topCenter,
                  child: Semantics(
                    button: true,
                    label: '${shelter.name} 대피소 상세',
                    child: GestureDetector(
                      onTap: () => widget.onSelected(shelter),
                      child: const ShelterPin(),
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
                  : '기본 지도 · 카카오 지도 준비 중',
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
