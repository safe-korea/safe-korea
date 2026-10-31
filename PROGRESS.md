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

## 구현 2 — 플랫폼 빌드와 저장 신뢰성
- Flutter 테스트 12건 통과 (권한 거부/영구 거부/위치 서비스 꺼짐/명시적 허용 포함), analyze 이슈 0.
- iOS simulator debug 빌드 성공. 시뮬레이터에서 오프라인 훈련/행동강령 이동, 네이티브 백업 제외 채널 호출, 별도 SQLite DB 저장 후 재열기 통합 테스트 1건 통과.
- 첫 Android build 도중 integration_test 의존성을 추가하여 GeneratedPluginRegistrant와 Gradle 의존성 간 불일치 발생. 의존성 확정 후 재빌드하여 debug APK 생성 및 Android API 36 에뮬레이터 설치 성공. 이후 동일 플랫폼 빌드/의존성 변경은 순차 수행.
- 빌드가 필요로 한 NDK 28.2 및 Android API 35가 기존 SDK에 추가 설치됨. 기존 라이선스 승인 사용, 관리자 권한/시스템 설정 변경 없음. CLI SDK XML 버전/플러그인 Java 8 경고는 비치명적.
- 가족 계획에 미저장 변경 이탈 확인 추가. 저장 실패 시 입력 보존과 읽기 실패 시 덮어쓰기 차단 테스트 보강 중.
- 스타터 디렉터리에 로컬 Git 저장소를 생성하고 구현 체크포인트 `75b00d5` 기록. 원격 연결·push 없음. 빌드 중 생성된 Kotlin 세션 메타데이터가 포함되어 다음 커밋에서 추적 해제 및 ignore 처리(파일 자체 삭제 없음).

## 검증 3 — Android/iOS 네이티브 동작
- Android API 36 에뮬레이터 통합 테스트 1건 통과: 훈련 진입·종료, 동봉 행동강령, 네이티브 SQLite 저장 후 파일 재열기.
- iOS 시뮬레이터 통합 테스트 1건 통과. 양 플랫폼 모두 테스트용 별도 DB만 생성·삭제해 사용자 계획 보존.
- 미저장 변경 보호, DB 읽기 실패/쓰기 실패, 홈 접근성 라벨/Android 48dp 터치 크기 테스트 추가. 테스트 프레임 갱신·SemanticsHandle 해제 시점을 수정한 후 Flutter 테스트 15건 전부 통과.
- 재생성한 일반 Android debug APK 빌드 성공(8.1초). release 서명·스토어 제출은 수행하지 않음.
- 지도 조회 지역·IP 전달 안내를 지도 열기 **이전**에 표시. 지도 요청에 대한 사용자 선택을 명확히 함.
- 가족 계획 저장 결과를 화면 안내와 하단 알림으로 함께 표시.

## 검증 4 — 실제 권한 흐름 및 최종 결과
- Android API 36에서 네이티브 권한 대화상자 거부 → 대체 안내 유지, 재요청 → ‘이번만 허용’ 흐름을 직접 확인.
- 기본 Fused 제공자가 Google 기기 전체 위치 정확도 설정 활성화를 요청하는 것을 발견하여 거절. 시스템 설정 보존을 위해 AndroidSettings(forceLocationManager: true)로 기기 기본 위치 관리자 사용으로 변경하고 테스트로 고정.
- 변경 후 네이티브 일회 위치 요청 성공: 에뮬레이터 제공 모의 좌표, 오차 약 5m 및 확인시각 표시 확인. 좌표는 앱 저장소에 기록하지 않음. 국내 실기기 위치 정확도/도심 수신/오프라인 GPS 성능은 후속 실기기 검증 필요.
- 최종 format: 15개 Dart 파일 변경 없음. analyze: No issues found. Flutter 테스트 15건, Python 테스트 4건 통과.
- 최종 코드로 Android/iOS 플랫폼 통합 테스트 각각 1건 재통과. DB 저장/재열기, 오프라인 asset 화면, 훈련 복귀 검증.
- `scripts/verify.sh` 추가. README 실행 방법과 데이터/개인정보/제한 사항 최신화. 화면 및 성공 로그를 artifacts에 보관.

## 미완료 및 다음 단계
1. **공식 시설 원본 확보가 우선**: 현 공식 다운로드 HTTP 403. 실제 시설 0건 유지. 공식 자료 확보·지정/해제 상태와 CRS 변환 검수 후 importer → asset → APK 재빌드 필요. 현재 검색/정렬/마커는 합성 테스트 자료 수준에서만 검증되었으며 전국 실사용 연동 완료가 아님.
2. 국내 Android/iOS 실기기 GPS·권한 거부/영구 거부·저전력·도심 GPS 오차, VoiceOver/TalkBack, iCloud 제외 동작 검증. iOS 시뮬레이터는 위치 권한/GPS 실수신까지 검증하지 않음.
3. 실제 정부 경보는 미구현. 공식 API의 제공·접근권한·지연·이용 조건 확인, 신뢰성/장애 대응 검증 전 구현 완료로 간주하지 않음.
4. 지도 배경은 온라인 전용. 인터넷 없이 동작하는 범위는 훈련·동봉 행동강령·가족 계획·동봉 자료 기반 목록/거리 계산. 지도 타일 및 시설 자동 최신화는 오프라인 기능이 아님.
5. 앱 아이콘/배포 서명/스토어 심사·개인정보 문서 등 출시 준비는 미수행. 개발용 debug 키 사용. 원격 push, 유료 서비스, 배포, 실제 경보 발송 없음.

## 최종 인수 상태
- 일반 `lib/main.dart` 앱으로 Android와 iOS 모두 재빌드·설치·실행 성공. 통합 테스트 실행용 앱이 아닌 일반 홈 화면을 남김.
- Android APK: `build/app/outputs/flutter-apk/app-debug.apk` (약 90MB, 개발용). 해시: `artifacts/apk.sha256`.
- iOS 앱: `build/ios/iphonesimulator/Runner.app`. 실기기/배포용 빌드 아님.
- 검증 근거: `artifacts/verify.log`, `android-integration.log`, `ios-integration.log`, 각 플랫폼 `*-run.log` 및 홈/위치 화면 캡처.
- 프로젝트는 사용자가 지정한 Downloads 스타터에 작성했으며 기존 `/Users/gimtaehyeong/orca/safe-korea` 작업 트리는 변경하지 않음.
- 저장한 실행 로그는 출력 내용은 유지하고 Git 검토를 위해 줄 끝 공백만 정리함. 최종 Git diff 공백 검사 통과.
