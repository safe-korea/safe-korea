# SAFE KOREA v0.1

대한민국 시민을 위한 한국어 오프라인 비상 대비 Flutter MVP입니다. **비공식 프로토타입이며 실제 정부 경보를 수신하지 않습니다.** 모의 화면에는 항상 `훈련 / 테스트`가 표시됩니다.

## 구현 상태

| 기능 | 상태 |
|---|---|
| Material 3 한국어 홈 / 큰 버튼 / 글씨 확대 | 구현 |
| 모의 공습경보와 대피 행동 연습 | 구현, 소리·알림·실제 경보 발송 없음 |
| 공습·경계·화학·생물학·해제·사전 준비 | 정부 원문을 요약해 JSON 동봉, 오프라인 이용 |
| 가족 비상연락처·만남 장소·메모 | SQLite 로컬 저장·수정·삭제 |
| GPS | 명시적 요청, 거부·꺼짐·타임아웃 처리 |
| 시설 검색·직선거리순 정렬·OSM 지도 | 코드와 합성 자료 테스트 구현, 실제 시설 자료 미연동 |
| 대한민국 공식 민방위 시설 목록 | 공식 다운로드 HTTP 403. 동봉 0건, 앱에 미연동 표시 |
| 실시간 정부 공습경보 | 미구현. API/권한/지연/이용 조건 검증 전 완료로 간주하지 않음 |

가까운 시설이 현재 개방되어 있거나 이동 경로가 안전하다는 뜻은 아닙니다. 일반 공습과 화학 공격의 대피 방법은 다릅니다. 최신 재난문자·정부 방송·현장 통제를 우선하세요.

## 실행

현재 개발 위치는 `/Users/gimtaehyeong/Downloads/safe-korea-starter`입니다. Mac 전역 설정을 보존하기 위해 Flutter를 프로젝트 `.tools/flutter`에 설치했습니다.

```sh
cd /Users/gimtaehyeong/Downloads/safe-korea-starter
.tools/flutter/bin/flutter pub get
.tools/flutter/bin/flutter devices
JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home .tools/flutter/bin/flutter run -d emulator-5556
```

이 Mac의 Android SDK는 `~/Library/Android/sdk`, API 36/에뮬레이터가 설치되어 있습니다. 다른 Mac에서는 각 기기의 JDK 17 이상 경로와 device ID로 바꾸세요. 실행 중인 에뮬레이터가 없으면 `flutter emulators` 및 `flutter emulators --launch <id>`를 사용하세요.

```sh
# Android 개발용 APK (배포용 서명 아님)
JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home .tools/flutter/bin/flutter build apk --debug --target-platform android-arm64
# iOS 시뮬레이터 (백그라운드/항상 위치 권한 사용 안 함)
BYPASS_PERMISSION_LOCATION_ALWAYS=1 .tools/flutter/bin/flutter run -d FCA9E923-B6DA-4BFF-A955-30B435322CA0
BYPASS_PERMISSION_LOCATION_ALWAYS=1 .tools/flutter/bin/flutter build ios --simulator --debug
```

새 체크아웃에서 Flutter가 없다면 공식 stable SDK를 사용자 소유 디렉터리에 설치하거나 아래처럼 프로젝트 내부에 설치하세요. SDK는 Git 추적에서 제외했습니다. 이 빌드에서 사용한 SDK revision은 `c197ca5199` (3.47.9)입니다.

```sh
git clone --depth 1 --branch stable https://github.com/flutter/flutter.git .tools/flutter
.tools/flutter/bin/flutter --version
.tools/flutter/bin/flutter doctor -v
```

## 검증

```sh
.tools/flutter/bin/dart format --output=none --set-exit-if-changed lib test integration_test
.tools/flutter/bin/flutter analyze
.tools/flutter/bin/flutter test
python3 -m unittest discover -s scripts -p 'test_*.py' -v
# 실제 플랫폼의 화면 이동 및 별도 테스트 SQLite 검증
JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home .tools/flutter/bin/flutter test integration_test/app_test.dart -d emulator-5556
BYPASS_PERMISSION_LOCATION_ALWAYS=1 .tools/flutter/bin/flutter test integration_test/app_test.dart -d FCA9E923-B6DA-4BFF-A955-30B435322CA0
```

2026-10-31 검증 결과: `flutter analyze` 이슈 0, Flutter 테스트 15건, Python 테스트 4건 통과. Android API 36과 iOS 26.5 시뮬레이터 통합 테스트 각각 1건 통과. Android에서 실제 권한 거부/일회 허용 후 모의 GPS 좌표·오차·시각 표시를 확인했습니다. 국내 실기기 GPS 정확도는 아직 검증하지 않았습니다.

Android 개발용 APK: `build/app/outputs/flutter-apk/app-debug.apk`. iOS 시뮬레이터 앱: `build/ios/iphonesimulator/Runner.app`. 결과 로그와 화면은 `artifacts/`에 보관합니다. 전체 검증은 `./scripts/verify.sh`로 다시 실행할 수 있습니다.

검증 결과와 빌드 상태는 [PROGRESS.md](PROGRESS.md)에 기록합니다. 통합 테스트는 사용자 가족 계획 DB와 다른 `safe_korea_integration_only.db`를 사용하고 테스트 후 해당 DB만 정리합니다.

## 데이터·개인정보

[DATA_SOURCES.md](DATA_SOURCES.md)에 정부 원문, 확인일, 대피시설 확보 제한 및 연결 절차를 기록했습니다. 행동강령은 `assets/guidelines.json`, 시설 자료는 `assets/shelters.json`입니다. 원문의 확인일을 정부 자료 갱신일로 혼동하지 않습니다.

GPS는 앱에서 저장하지 않고 서버에 직접 전송하지 않습니다. 온라인 지도는 별도 선택 시 조회하며, 지도 제공자에 IP와 조회 범위가 전달됩니다. 지도는 오프라인 기능에 포함되지 않습니다. OSM 저작자 표시·앱 User-Agent·기본 타일 캐시를 사용하며 대량 다운로드는 하지 않습니다.

가족 계획은 암호화되지 않은 기기 내부 SQLite에 저장합니다. Android 앱 백업은 비활성화했고 iOS Documents는 저장 전 백업 대상에서 제외합니다. 자동 연락, 가족 위치 추적, 로그인, 분석 도구, 서버, Firebase는 없습니다. 기기 분실·고장에 대비해 종이 연락카드도 보관하세요.

## 구조

- `lib/screens`: 홈, 훈련, 행동강령, 시설/지도, 가족 계획
- `lib/models`: 공식 시설 자료 검증 및 거리 계산
- `lib/services`: 일회 위치 요청, SQLite 저장
- `lib/widgets`: 공통 안내·레이아웃
- `assets`: 오프라인 콘텐츠와 시설 메타데이터
- `scripts`: 검증된 공식 CSV 정규화 가져오기 및 테스트
- `test`, `integration_test`: 위젯·저장·위치·시설 검증 및 플랫폼 통합 테스트

출시 전 필요한 작업: 공식 시설 원본 확보 및 CRS/지정 상태 검수, 전국 범위와 갱신 정책 검증, 실기기 GPS·권한·VoiceOver/TalkBack 점검, 정부 행동강령 변경 재검토, iOS 실기기 서명과 앱 아이콘·배포 서명 구성. 원격 push·배포는 수행하지 않습니다.
