# 데이터 출처와 연결 절차

## 행동강령
- 원문: [행정안전부 국민안전24 비상시 행동요령](https://safekorea.go.kr/safekorea-kor/acts/nacts/action-guide.do?category=stateOfEmergency&menuSn=4)
- 개발 시 원문 확인일: 2026-10-31. 정부 원문의 자체 갱신일은 확인되지 않았음.
- 공습·경계·화학·생물학·해제·사전 준비를 앱용으로 요약. 정부가 이 앱을 검수·승인했다는 뜻이 아님.
- 앱 동봉 JSON은 네트워크가 없어도 읽힘. 이후 지침 변경 시 재검토와 앱 갱신 필요.
- 일반 마스크의 화학작용제 완전 차단을 암시하지 않도록 주의 문구 추가.

## 민방위 대피시설
- 공식 목록: [전국민방위대피시설표준데이터](https://www.data.go.kr/data/15021098/standard.do), 행정안전부/지자체 제공. 무료, 이용허락 제한 없음으로 안내됨.
- 공식 페이지 연결 다운로드: https://file.localdata.go.kr/file/civil_defense_shelter_info/info
- 2026-10-31 접근 검증: HTTP 302 `/error.html` → HTTP 403. 인증정보 이용이나 접근 제한 우회는 시도하지 않음.
- 따라서 앱 동봉 자료는 **0건**, `status: unavailable`. 전국 조회·자동 동기화 완료로 간주하지 않음.
- 원본 설명의 좌표계(EPSG:5174)와 다른 시기의 설명이 혼재하므로 좌표값만 보고 CRS를 추측하지 않음.

### 후속 연결
1. 공식 제공자의 허용된 방법으로 원본 CSV와 컬럼/CRS 설명, 데이터 기준일을 확보하고 보관한다. 개인/비공식 제3자 목록을 운영 데이터로 사용하지 않는다.
2. 지정 상태인 민방위 대피시설만 포함한다. 해제·불명·좌표 없음 항목은 제외하며 제외 수를 별도 기록한다.
3. 원본 CRS를 공식 설명으로 확인한다. EPSG:5174/5179 등의 투영좌표는 검증된 GIS 도구로 WGS84로 변환하고 표본 위치를 공식 지도와 대조한다. 위도·경도 바꾸기나 임의 오프셋은 금지한다.
4. UTF-8 CSV를 다음 열로 정규화한다: `id,name,address,latitude,longitude,updatedAt,status`. 날짜는 원본 갱신일 `YYYY-MM-DD`, 상태는 `designated` 또는 `released`. 이름·주소·날짜를 임의로 채우지 않는다.
5. `python3 scripts/import_shelters.py /path/verified.csv --coverage '실제 지역과 데이터 범위' --confirmed-official` 실행. 전체 검증 실패 시 기존 asset은 보존된다. 이 플래그는 운영자의 수동 출처 검증 선언이며 자동 인증/서명 검증이 아니다.
6. 원본 다운로드 시각/URL/해시, 정규화 및 좌표 변환 근거와 제외 수를 별도 검토 기록으로 남긴다. 앱 데이터의 inputSha256은 정규화 CSV 해시이다.
7. `flutter test`, APK 재빌드 후 시설 위치·갱신일·거리 정렬을 실제 공식 표본과 비교한다. 동봉 자료의 최신성/전국 완전성을 별도로 확인한다.

이 도구는 아직 확보되지 않은 실제 CSV의 자동 파서라고 주장하지 않는다. 정규화된 스키마만 지원한다. 앱은 출처·범위·확보일·시설별 갱신일을 표시하고 개방 여부/수용 여유/이동 경로는 판단하지 않는다.

## 지도 및 위치
- flutter_map + [OpenStreetMap](https://www.openstreetmap.org/copyright). 기본 지도는 온라인, 대량 다운로드/오프라인 타일 수집 없음.
- [OSM 타일 정책](https://operations.osmfoundation.org/policies/tiles/) 준수: HTTPS, 앱 User-Agent, 저작자 표시, flutter_map 8.3의 기본 캐시 사용. 서비스 보장 없음.
- 지도 열기는 명시적 선택. 지도 타일 조회 시 IP와 지도 범위가 OSM에 전달됨. 앱의 GPS 좌표를 서버에 직접 전송하거나 저장하지 않음.
- 기기 위치는 일회 확인, 타임아웃 15초. 권한 거부·서비스 꺼짐·오차/시각 표시. 백그라운드 위치 권한 없음.
- 가족 계획: 앱 내부 SQLite, 분석/서버 전송 없음. 암호화되지 않은 로컬 저장. Android 앱 백업 비활성화; iOS는 SQLite를 열기 전에 앱 Documents 디렉터리를 백업 대상에서 제외하며 실패 시 저장을 중단함. 실제 iCloud 백업 동작은 실기기 검증 필요.

## 실제 정부 경보
실시간 수신 미구현. 공식 API 제공·이용 허가·신뢰성·지연·장애 대응·실기기 검증 전에는 완료로 간주하지 않는다. 서버/FCM/실제 경보 발송 없음.
