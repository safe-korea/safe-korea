# 잠실 오프라인 지도

## 지도 원자료

© OpenStreetMap contributors, ODbL 1.0.
- 저작권/출처: https://www.openstreetmap.org/copyright
- 라이선스: https://opendatacommons.org/licenses/odbl/1-0/
- 제공: Geofabrik, https://download.geofabrik.de/asia/south-korea.html
- 고정 파일: https://download.geofabrik.de/asia/south-korea-261101.osm.pbf

`jamsil-map.json`은 이 원자료에서 경도 127.088–127.112, 위도 37.505–37.522와 교차하는 도로·건물 way 및 공원·수역 area geometry를 추출한 ODbL 데이터입니다. 원본 ID, geometry, 이름, 도로 분류를 보관하며 기여자 개인 계정 정보는 포함하지 않습니다. 변환 스크립트는 `scripts/prepare_offline_map.py`, PBF 해시는 지도 JSON에 포함합니다. 추출 결과와 스크립트를 공개 저장소에 제공하며 이 데이터의 재배포에는 ODbL을 적용합니다. 지도 스타일/Flutter 코드는 별도입니다.

온라인 타일을 다운로드하거나 카카오 지도 이미지를 복사하지 않았습니다. 앱 실행 중 지도 공급자에 요청하지 않습니다. 국가 PBF는 개발 도구 폴더에만 있고 앱에는 작은 지역 추출본만 동봉합니다. 공개 Overpass의 단발 조회는 실패하여 사용하지 않았으며, 공개 API를 앱의 운영 백엔드로 연결하지 않았습니다.

## 대피소 레이어

`jamsil-shelters.json`은 기존 행정안전부 국민안전24 공식 시설 조회 결과 중 지도 범위 안의 항목입니다. 원본 sourceUrl/retrievedAt/시설 ID·이름·주소·좌표를 보존한 별도 레이어입니다. OSM의 대피소 태그를 공식 시설로 간주하지 않습니다. 시설별 갱신일·출입구·개방 여부는 확인되지 않았습니다. 조회 날짜를 시설별 갱신일로 대신하지 않습니다.

## 범위와 제한

잠실역 주변 약 2.1 × 1.9km만 제공하며 전국 지도는 아닙니다. OSM 자료에는 누락이나 변경이 있을 수 있습니다. 수역·공원은 multipolygon 외곽과 내부 구멍을 처리하며, 일부 건물 relation과 입체 구조는 표현되지 않을 수 있습니다. 이동 경로와 GPS 점, 실시간 도로 상태를 제공하지 않습니다. 지도상 시설 좌표는 출입구와 다를 수 있고 현장 통제가 우선입니다. 준비 시각은 지도 JSON에서 확인할 수 있습니다. 새 지역은 개발자가 별도의 자료를 준비해야 합니다.

재생성: `.tools/offline-map-python/bin/python scripts/prepare_offline_map.py <south-korea-261101.osm.pbf> <verified-songpa-catalog.json>` (개발용 Python 환경에 osmium 필요).
