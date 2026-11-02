import 'package:url_launcher/url_launcher.dart';

import '../models/shelter.dart';

/// Provider-hosted imagery only: no scraping, thumbnail copying or GPS request.
class ShelterStreetView {
  ShelterStreetView({Future<bool> Function(Uri, LaunchMode)? launch})
    : _launch = launch ?? ((uri, mode) => launchUrl(uri, mode: mode));
  final Future<bool> Function(Uri, LaunchMode) _launch;

  static Uri urlFor(Shelter shelter) {
    final lat = shelter.latitude, lon = shelter.longitude;
    if (!lat.isFinite ||
        !lon.isFinite ||
        lat < 33 ||
        lat > 39.5 ||
        lon < 124 ||
        lon > 132) {
      throw const FormatException('시설 좌표를 확인할 수 없습니다.');
    }
    // Kakao's documented URL order is latitude, longitude.
    return Uri.https('map.kakao.com', '/link/roadview/$lat,$lon');
  }

  Future<bool> open(Shelter shelter) async {
    final uri = urlFor(shelter);
    for (final mode in [
      LaunchMode.inAppBrowserView,
      LaunchMode.externalApplication,
    ]) {
      try {
        if (await _launch(uri, mode)) return true;
      } catch (_) {
        // Browser-sheet support varies by device; try the system browser next.
      }
    }
    return false;
  }
}
