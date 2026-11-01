import 'shelter.dart';

/// Editorially matched, licensed building imagery. Never inferred from a name search.
class PublicShelterPhoto {
  const PublicShelterPhoto._();
  static const cityHall = PublicShelterPhoto._();
  String get asset => 'assets/public_photos/seoul_city_hall_2026.jpg';
  String get title => '서울시청 외관 · 뒤편 유리 건물';
  String get takenOn => '2026-06-03';
  String get author => 'Sadopaul (Gyuwon Lee)';
  String get sourceUrl =>
      'https://commons.wikimedia.org/wiki/File:Seoul_City_Hall_in_2026.jpg';
  String get licenseUrl => 'https://creativecommons.org/licenses/by-sa/4.0/';

  static PublicShelterPhoto? match(ShelterCatalog? catalog, Shelter shelter) {
    if (catalog?.sourceUrl != officialMapSource ||
        catalog?.areaCode != '11140' ||
        !shelter.latitude.isFinite ||
        !shelter.longitude.isFinite ||
        shelter.id != 'S201200008' ||
        shelter.name != '서울특별시청 지하1~4층' ||
        !shelter.address.startsWith('서울특별시 중구 세종대로 110,') ||
        shelter.distanceFrom(37.56695, 126.97794166666667) > 150) {
      return null;
    }
    return cityHall;
  }
}
