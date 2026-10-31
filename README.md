# SAFE KOREA MVP

대한민국 시민을 위한 한국어 오프라인 비상 대비 Flutter MVP입니다. **비공식 프로토타입이며 실제 정부 경보를 수신하지 않습니다.** 모의 화면에는 항상 `훈련 / 테스트`가 표시됩니다.

## 구현 상태

| 기능 | 상태 |
|---|---|
| Material 3 한국어 홈 / 큰 버튼 / 글씨 확대 | 구현 |
| 모의 공습경보와 대피 행동 연습 | 구현, 별도 버튼에서만 로컬 테스트 알림 실행 |
| 공습·경계·화학·생물학·해제·사전 준비 | 정부 원문을 요약해 JSON 동봉, 오프라인 이용 |
| 가족 만남 장소 | 첫 번째/대체 장소 이름·지도 핀·가족 약속·SQLite 저장, 기존 연락처 보존 |
| 나의 준비 | 비상배낭 8개 항목 체크리스트·로컬 저장 |
| GPS | 명시적 요청, 거부·꺼짐·타임아웃 처리, 별도 동작으로 조회 지역 제안 |
| 시설 검색·직선거리순 정렬·지도 | 공식 시설 조회, 핀 묶음·확대·시설 선택, 전체 화면 지도 |
| 저장한 대피소 | 여러 지역의 시설 저장·검색·해제, 공식 정보 재확인·변경 반영·미확인 상태 보존 |
| 카카오 지도 | SDK/연결 코드 준비. 키 미입력으로 실제 인증 미검증, 현재는 기본 OSM 지도 |
| 대한민국 공식 민방위 시설 목록 | 시·도/시·군·구 선택 후 국민안전24 조회, 마지막 조회 지역 SQLite 저장 |
| 실시간 정부 공습경보 | 미구현. API/권한/지연/이용 조건 검증 전 완료로 간주하지 않음 |

가까운 시설이 현재 개방되어 있거나 이동 경로가 안전하다는 뜻은 아닙니다. 일반 공습과 화학 공격의 대피 방법은 다릅니다. 최신 재난문자·정부 방송·현장 통제를 우선하세요.

## 앱 구성

하단 메뉴로 **홈 · 대피소 · 행동강령 · 나의 준비**를 이동합니다. 가족 계획은 저장된 내용을 먼저 읽고 필요할 때 수정합니다. 훈련에는 선택형 연습 체크가 있습니다. 준비물 체크와 가족 계획은 기기에만 저장됩니다.

완료 범위와 남은 검증은 [MVP_CHECKLIST.md](MVP_CHECKLIST.md), 카카오 지도 키 연결은 [KAKAO_SETUP.md](KAKAO_SETUP.md)를 참고하세요. 키를 나중에 넣어도 되며 현재 앱의 기본 기능과 지도는 키 없이 실행됩니다.

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
BYPASS_PERMISSION_LOCATION_ALWAYS=1 .tools/flutter/bin/flutter run -d E3A83EF7-8FD6-4656-AE84-EFA2E3136351
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
JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home .tools/flutter/bin/flutter test integration_test/app_test.dart -d emulator-5556 --no-uninstall
BYPASS_PERMISSION_LOCATION_ALWAYS=1 .tools/flutter/bin/flutter test integration_test/app_test.dart -d E3A83EF7-8FD6-4656-AE84-EFA2E3136351 --no-uninstall
```

2026-11-01 로컬 검증 결과: `flutter analyze` 이슈 0, Flutter 테스트 60건, Python 테스트 6건 통과. Android API 36과 iOS 26.5 시뮬레이터에서 기본 앱 통합 테스트 및 실시간 공식 시설 조회·지도·SQLite 재열기 통합 테스트 통과. 공식 종로구 응답 107건을 확인했습니다. Android에서 실제 권한 거부/일회 허용 후 모의 GPS 좌표·오차·시각 표시를 확인했습니다. 국내 실기기 GPS 정확도는 아직 검증하지 않았습니다.

Android 개발용 APK: `build/app/outputs/flutter-apk/app-debug.apk`. iOS 시뮬레이터 앱: `build/ios/iphonesimulator/Runner.app`. 결과 로그와 화면은 `artifacts/`에 보관합니다. 전체 검증은 `./scripts/verify.sh`로 다시 실행할 수 있습니다.

검증 결과와 빌드 상태는 [PROGRESS.md](PROGRESS.md)에 기록합니다. `--no-uninstall`로 테스트 종료 시 앱과 저장 데이터 삭제를 막습니다. 통합 테스트는 사용자 가족 계획 DB와 다른 `safe_korea_integration_only.db`를 사용하고 테스트 후 해당 DB만 정리합니다.

## 대피소 지도 사용법

1. **주변 대피시설**에서 시·도와 시·군·구를 선택합니다.
2. **선택 지역 대피소 불러오기**를 누르면 공식 국민안전24 지도에서 해당 지역의 민방위 대피소를 조회합니다. 현재 화면의 표시 범위와 조회 시각을 확인하세요.
3. **온라인 지도 열기**를 누르면 실제 시설 핀이 표시됩니다. 숫자는 가까운 시설의 묶음이며 누르면 확대됩니다. 충분히 확대해도 겹치는 시설은 선택 목록에서 고릅니다. 기본 지도에서는 묶음을 길게 눌러 바로 목록을 열 수도 있습니다. 숫자 위치는 실제 출입구가 아닙니다.
4. **현재 위치로 지역 찾기**를 펼쳐 별도 안내를 확인한 뒤 지역 제안을 요청할 수 있습니다. 기기의 주소 변환 서비스가 제공한 이름을 공식 지역 목록과 대조합니다. 시도만 확인되면 시군구는 비워 두며 직접 선택하기 전까지 조회할 수 없습니다. 경계·행정구역 명칭 변경·서비스 미지원 시 직접 선택하세요. **GPS 현재 위치 확인**을 허용하면 받은 지역 안에서 직선거리순으로 정렬합니다. GPS 위치에 따라 다른 지역을 자동 조회하지 않으므로 필요한 인접 지역은 직접 선택하세요.
5. 마지막으로 조회한 지역 한 곳의 목록은 기기에 저장되어 다음 실행부터 인터넷 없이도 검색할 수 있습니다. **대피소 저장**을 누른 개별 시설은 지역을 바꿔도 **저장한 대피소**에서 검색·열람·해제할 수 있습니다. **공식 자료 다시 확인**으로 저장한 시설의 현재 목록 정보를 조회할 수 있습니다. 변경된 이름·주소·좌표를 반영하되 처음 저장한 시각은 보존합니다. 조회에서 찾지 못하거나 일부 행이 누락되면 기존 정보와 미확인 표시를 유지하며 폐쇄로 단정하지 않습니다. 공식 조회 시각·기기 저장 시각·재확인 시각을 구분하며 자동 최신화되지 않습니다. 지도 배경은 온라인 전용입니다.
6. 지도 배경이 실패하거나 15초 이상 응답이 없으면 **지도 다시 시도** 또는 **시설 목록 보기**를 이용하세요. 목록은 현재 조회/저장된 시설 데이터로 열리며 추가 네트워크 요청을 하지 않습니다. 재시도는 지도 위치와 시설 자료를 유지합니다. 이 상태 감지는 현재 기본 OSM 지도에 적용되며 카카오 실제 인증/렌더 검증은 남아 있습니다.
7. 조회 후에는 지역 입력이 접힙니다. **지역 변경**을 눌러 다른 지역을 조회하세요. UI 설계와 접근성 검토는 [DESIGN.md](DESIGN.md)에 기록합니다.

추가 지역 검증에서 부산 중구는 전체/지도 51건 일치를 확인했고, 제주시는 전체 812건과 지도 479건이 달랐습니다. 이런 지역은 앱이 교체를 거부하고 오류 안내 옆의 정부 공식 검색으로 연결합니다. 모든 지역의 자료 완전성을 검증한 것은 아닙니다.

처음 설치할 때 동봉 시설은 0건입니다. 전국 전체 시설을 미리 수집하거나 자동 최신화하지 않습니다. 조회 실패 시 기존 자료를 유지하며 잘못된 좌표·중복은 제외 수를 표시합니다. 공식 지도 응답에 시설별 갱신일이 없어 `제공되지 않음`으로 표시합니다. 조회 시각을 시설 갱신일로 대신하지 않습니다.

공식 사이트의 내부 조회 경로를 사용하는 MVP이며, 공개 API로서의 버전·가용성·운영 이용 조건은 보장되지 않습니다. 사이트 변경/장애 시에는 **정부 공식 시설 검색 열기**를 이용하세요. 상세한 관측 근거는 DATA_SOURCES.md에 기록했습니다.

```sh
# 외부 공식 사이트에 지역 단위 요청 1회를 보내는 명시적 통합 검증
JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home .tools/flutter/bin/flutter test integration_test/shelters_test.dart -d emulator-5556 --no-uninstall
BYPASS_PERMISSION_LOCATION_ALWAYS=1 .tools/flutter/bin/flutter test integration_test/shelters_test.dart -d E3A83EF7-8FD6-4656-AE84-EFA2E3136351 --no-uninstall
```

## 데이터·개인정보

[DATA_SOURCES.md](DATA_SOURCES.md)에 정부 원문, 확인일, 대피시설 확보 제한 및 연결 절차를 기록했습니다. 행동강령은 `assets/guidelines.json`, 시설 자료는 `assets/shelters.json`입니다. 원문의 확인일을 정부 자료 갱신일로 혼동하지 않습니다.

GPS는 앱에서 저장하지 않습니다. **거리 계산**은 기기 안에서 처리합니다. **위치로 조회 지역 제안받기**는 별도 안내 후 사용자가 누를 때만 좌표를 Apple/Google 등 기기 주소 변환 서비스에 전달할 수 있습니다. 이 서비스는 [geocoding 공식 패키지](https://pub.dev/packages/geocoding)의 OS 기능을 사용하며 앱 자체 서버·유료 API 키는 추가하지 않습니다. 2분 이상 오래되거나 오차가 1km를 넘는 위치로는 지역 변환을 요청하지 않습니다. 공식 시설 조회에는 선택 지역 코드와 IP만 정부 사이트에 전달됩니다. 온라인 지도는 별도 선택 시 조회하며, 지도 제공자에 IP와 조회 범위가 전달됩니다. 지도는 오프라인 기능에 포함되지 않습니다. OSM 저작자 표시·앱 User-Agent·기본 타일 캐시를 사용하며 대량 다운로드는 하지 않습니다.

가족 계획은 암호화되지 않은 기기 내부 SQLite에 저장합니다. Android 앱 백업은 비활성화했고 iOS Documents는 저장 전 백업 대상에서 제외합니다. 자동 연락, 가족 위치 추적, 로그인, 분석 도구, 서버, Firebase는 없습니다. 기기 분실·고장에 대비해 종이 연락카드도 보관하세요.

## iPhone 17 Pro 미리보기

```sh
./scripts/preview_iphone.sh
```

미리보기 파일은 artifacts/iphone17-pro-*.png에 저장합니다. 이 명령은 화면 확인용이며 공식 시설 조회 1회를 보낼 수 있습니다. 스크립트는 촬영 테스트 후 일반 `lib/main.dart` 앱을 다시 실행해 직접 누르는 입력이 막히지 않도록 합니다. 다른 시뮬레이터는 첫 번째 인자로 device ID를 전달하세요.

## 구조

- `lib/screens`: 홈, 훈련, 행동강령, 시설/지도, 가족 계획
- `lib/models`: 공식 시설 자료 검증 및 거리 계산
- `lib/services`: 일회 위치 요청, SQLite 저장
- `lib/widgets`: 공통 안내·레이아웃
- `assets`: 오프라인 콘텐츠와 시설 메타데이터
- `scripts`: 검증된 공식 CSV 정규화 가져오기 및 테스트
- `test`, `integration_test`: 위젯·저장·위치·시설 검증 및 플랫폼 통합 테스트

출시 전 필요한 작업: 공식 웹사이트 조회 경로의 운영 이용 조건·안정성 확인, 다른 지역별 결과/갱신 정책 검증, 실기기 GPS·권한·VoiceOver/TalkBack 점검, 정부 행동강령 변경 재검토, iOS 실기기 서명과 앱 아이콘·배포 서명 구성. 원격 push와 초안 PR #1 게시까지 승인 후 수행했으며, 앱 배포·스토어 제출은 수행하지 않았습니다.

## 테스트 알림

홈 하단 **테스트 알림 설정 → 지금 테스트 알림 보내기**에서 기기 알림 권한을 요청합니다. 앱 시작 시에는 권한을 요청하거나 알림을 보내지 않습니다. 소리와 Android 진동은 기본 꺼짐이며 직접 켤 수 있습니다. iPhone 진동은 OS 설정을 따릅니다. 알림 제목·본문은 훈련임을 표시하며 누르면 훈련 화면을 엽니다. 앱 종료 후 알림을 눌러 실행하는 경로도 연결했습니다. 테스트 알림 지우기는 이 앱의 테스트 알림 1개만 지웁니다.

[flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) 22.3.3 사용. Android 채널은 소리/진동 조합별로 분리합니다. 사용자가 OS에서 바꾼 채널 설정, 무음/집중 모드, 알림 차단은 우회하지 않습니다. 예약·원격 푸시·실제 정부 경보 자동 수신 기능은 없습니다. 네트워크 없이 동작하는 수동 테스트입니다. 실제 기기의 소리·진동, 알림 센터 탭 및 종료 상태 실행은 추가 수동 검증이 필요합니다.

경보 훈련 진입 화면은 **먼저 대피 → 준비된 배낭 → 대피 후 정부 안내** 순서입니다. 빨간 경보 영역에 대피시설 버튼을 크게 보여주며 손 닿는 물품만 챙기고 없으면 바로 대피하도록 안내하며, 행동요령은 펼쳐서 봅니다. 테스트 알림을 눌러도 같은 화면으로 연결됩니다. 실제 정부 경보 수신 상태는 변하지 않았습니다.

연습 경과 타이머는 훈련 화면을 연 때부터 계산합니다. 지도를 열거나 앱이 백그라운드에 있는 동안에도 같은 세션의 경과 시간을 반영합니다. 훈련 화면을 닫고 다시 열거나 앱 프로세스가 종료되면 새로 시작하며 기록은 저장하지 않습니다. 공격 도달 시각·남은 안전 시간·대피 제한시간을 의미하지 않습니다.

### 사이렌 테스트와 화면 구성

홈 → 테스트 알림 설정 → **사이렌 켜기** → **지금 테스트 알림 보내기**. 기본 알림음 대신 앱에 동봉한 6초 상승·하강 사이렌을 요청합니다. Android raw 리소스와 iOS 앱 번들에 같은 PCM WAV를 포함하며 외부 다운로드는 없습니다. Android의 기존 기본음 채널과 새 사이렌 채널은 분리했습니다. 무음/집중 모드와 사용자가 변경한 OS 채널 설정은 그대로 적용됩니다. 켜기 스위치 자체나 훈련 화면 진입만으로 소리를 재생하지 않습니다.

음원은 scripts/generate_drill_siren.py로 직접 합성한 앱 훈련용이며 공식 정부 사이렌 녹음이 아닙니다. 자동 검증에서는 소리 설정·번들 포함·음원 길이/클리핑만 확인했고 실제 기기 청취는 미검증입니다.

홈, 행동강령, 나의 준비, 대피소 검색 도입부, 가족 계획, 알림 설정에도 공통 제목·아이콘·카드 디자인을 적용했습니다. 지도 데이터 및 지도 제공자 자체는 변경하지 않았습니다.

## 가족 만남 장소

홈 또는 나의 준비 → **가족 만남 장소**에서 첫 번째 장소, 대체 장소, 가족 약속을 저장합니다. 연락처 입력은 제거했으며 기존 연락처 값은 수정/삭제하지 않습니다. ‘저장된 계획 삭제’는 장소 이름·좌표·약속만 지웁니다.

**첫 번째 장소 지도에서 지정 / 대체 장소 지도에서 지정** → 지도를 확대하고 원하는 지점을 누르거나 ‘지도 중앙에 핀 놓기’ → **이 위치 선택** → 가족 화면에서 **기기에 저장**. 선택 뒤 가족 화면을 저장하기 전에는 임시 변경입니다. 뒤로 가면 미저장 확인이 뜹니다. 장소 이름은 직접 입력하며 주소 검색·자동 좌표 변환은 수행하지 않습니다.

저장된 각 장소는 **지도 보기**로 핀을 다시 확인할 수 있습니다. 지도는 현재 OSM 온라인 지도이며 카카오 전용 만남 장소 선택은 연결하지 않았습니다. 열 때 지도 제공자에게 IP와 조회 범위가 전달됩니다. 앱 서버에는 이름/좌표를 보내지 않고 GPS도 자동 요청하지 않습니다. 지도 배경 실패 시 재시도하거나 이름만 저장할 수 있습니다. 이름·좌표는 오프라인 열람 가능하며 가족에게 자동 공유되지 않습니다. 가족 만남 장소는 공식 대피시설 또는 안전한 경로를 의미하지 않습니다.
