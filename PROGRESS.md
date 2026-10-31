# SAFE KOREA 개발 기록

## 2026-10-31 — 환경 확인 및 계획
- 작업 디렉터리: `/Users/gimtaehyeong/Downloads/safe-korea-starter` (사용자가 지정한 스타터).
- AGENTS.md, CODEX_TASK.md, README.md 확인. 기존 문서 보존.
- Flutter/Dart 미설치, Xcode 26.6 / Git 2.50.1 / Android SDK API 36 / Java 17·21·25 설치 확인.
- 사용자 지시가 문서의 ‘Flutter 없으면 중단’보다 우선하므로 프로젝트 `.tools/flutter`에 stable SDK 설치. 관리자 권한·전역 PATH 설정 변경 없음.
- 계획: (1) Flutter Android/iOS 초기화 (2) 오프라인 한국어 홈·훈련·행동강령 (3) 가족 계획 로컬 저장 (4) GPS·공식 대피시설 조회·OSM 지도 (5) 오류/권한/접근성 테스트 (6) 빌드 및 문서.
- 공식 행동강령: 국민안전24 비상사태 페이지를 조회해 공습/경계/화학/생물학 상황 구분 확인.
- 전국 대피시설: 공공데이터포털 15021098 공식 데이터셋 확인. 연결된 localdata 다운로드 URL이 HTTP 403이므로 실제 자료 확보 방법 추가 조사 중. 미확보 자료는 실제 시설처럼 표시하지 않음.

## 구현 1 — 오프라인 핵심과 검증 경계
- Flutter 3.47.9 / Dart 3.13.7 로컬 설치 완료. flutter doctor: Android/Xcode 정상, 전역 PATH 미등록만 경고(의도적으로 사용자 설정 보존).
- Android/iOS 프로젝트, Material 3 한국어 홈, 명시적인 ‘훈련 / 테스트’ 공습 연습, 6가지 오프라인 행동강령 구현.
- SQLite 가족 연락처·만남 장소·메모 저장/수정/삭제. 실패 시 입력 보존, 읽기 실패 시 덮어쓰기 차단.
- Android 백업 비활성화, iOS SQLite Documents 폴더 백업 제외 호출 추가. 앱 자체 서버·분석·추적 없음.
- 명시적 GPS 요청, 권한 거부/위치 서비스 꺼짐/15초 타임아웃 처리, 좌표·오차·확인시각 표시.
- 공식 시설 asset 검증, 직선거리 정렬/검색/OSM 지도·시설 상세 구현. 실제 공식 시설은 아직 0건이며 미연동 명시.
- 공식 CSV의 수동 검증 후 사용하는 정규화 가져오기 도구와 DATA_SOURCES.md 작성. 투영좌표를 위경도로 오인하지 않도록 거부.
- 첫 analyze: 템플릿 테스트 및 스타일 문제 수정 후 No issues found.
- 첫 Flutter 테스트: 핵심 화면/거리 계산 통과, SQLite FFI를 위젯 가상시간 안에서 기다리는 테스트 1건 타임아웃. 실제 DB 단위 테스트와 메모리 저장소 UI 테스트로 분리하여 수정 중.
- Python 가져오기 도구 테스트 4건 통과.
- Android debug APK 및 iOS simulator build 진행 중. JDK 21을 명령 환경에만 지정(전역 변경 없음).
