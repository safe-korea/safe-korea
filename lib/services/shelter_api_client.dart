import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/shelter.dart';
import 'connection_monitor.dart' show ConnectionMonitor;

const shelterApiBaseUrl = String.fromEnvironment('SHELTER_API_BASE_URL');

class ShelterApiException implements Exception {
  const ShelterApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Public regional data only. Never sends GPS, family data, cookies or API keys.
class ShelterApiClient {
  ShelterApiClient({http.Client? client, String baseUrl = shelterApiBaseUrl})
    : _client = client ?? http.Client(),
      // Keep the public configuration argument readable at call sites.
      // ignore: prefer_initializing_formals
      _baseUrl = baseUrl;
  final http.Client _client;
  final String _baseUrl;
  bool get configured => _baseUrl.isNotEmpty;
  void close() => _client.close();

  Uri _endpoint(String code) {
    final base = Uri.tryParse(_baseUrl);
    if (base == null ||
        !base.hasAuthority ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        (base.path.isNotEmpty && base.path != '/') ||
        (base.scheme != 'https' &&
            !(base.scheme == 'http' &&
                ['127.0.0.1', 'localhost', '[::1]'].contains(base.host)))) {
      throw const ShelterApiException('대피소 데이터 서버 주소를 확인해 주세요.');
    }
    if (!RegExp(r'^\d{5}$').hasMatch(code)) {
      throw const ShelterApiException('지역을 다시 선택해 주세요.');
    }
    return base.replace(
      path: '/api/shelters',
      queryParameters: {'region': code},
    );
  }

  Future<ShelterCatalog> fetch(String code) async {
    final endpoint = _endpoint(code);
    http.Response response;
    try {
      response = await _client
          .get(endpoint)
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      ConnectionMonitor.instance.reportServiceFailure();
      throw const ShelterApiException('데이터 서버에 연결하지 못했습니다. 인터넷 연결을 확인해 주세요.');
    }
    if (response.statusCode == 429) {
      throw const ShelterApiException('조회가 몰리고 있습니다. 1분 뒤 다시 시도해 주세요.');
    }
    if (response.statusCode != 200 || response.bodyBytes.length > 2000000) {
      throw const ShelterApiException(
        '공식 대피시설 자료를 확인하지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
    }
    try {
      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (body['apiVersion'] != 1) throw const FormatException('API 버전');
      final delivery = body['delivery'] as Map<String, dynamic>;
      final state = delivery['state'];
      if (!['hit', 'miss', 'stale'].contains(state) ||
          delivery['stale'] != (state == 'stale') ||
          delivery['ageSeconds'] is! int ||
          (delivery['ageSeconds'] as int) < 0 ||
          (delivery['ageSeconds'] as int) >= 86400 ||
          (state != 'stale' && (delivery['ageSeconds'] as int) >= 900)) {
        throw const FormatException('전달 상태');
      }
      final json = Map<String, dynamic>.from(body['catalog'] as Map);
      if (json['areaCode'] != code ||
          json['sourceUrl'] != officialMapSource ||
          json['status'] != 'verified' ||
          json['retrievedAt'] is! String ||
          json['officialCount'] is! int ||
          json['skippedCount'] is! int) {
        throw const FormatException('출처 정보');
      }
      DateTime.parse(json['retrievedAt'] as String);
      if ((json['skippedCount'] as int) < 0 ||
          (json['officialCount'] as int) < 0 ||
          (json['items'] as List).length + (json['skippedCount'] as int) !=
              json['officialCount']) {
        throw const FormatException('시설 건수');
      }
      json['deliveryStatus'] = state;
      return ShelterCatalog.fromJson(json);
    } catch (_) {
      throw const ShelterApiException('자료의 출처·지역·건수를 검증하지 못했습니다. 다시 시도해 주세요.');
    }
  }
}
