# 카카오 지도 연결

**카카오 대피소 지도 연결 완료:** 2026-11-01 새 계정의 `safe-korea` 앱에서 지도 ON과 일간 무료 쿼터 제공을 확인했습니다. 개발용 네이티브 키와 Android/iOS 정보를 등록하고 Android 에뮬레이터·iPhone 17 Pro에서 인증, 배경 지도, 공식 대피소 핀, 확대 후 표시를 검증했습니다. 키는 이 Mac의 Git 제외 파일에만 저장했습니다. 월렛·유료 API를 설정하지 않았고 이전 계정의 앱과 키도 삭제하지 않았습니다.

다른 체크아웃에는 키가 포함되지 않아 기본 OpenStreetMap 지도가 표시됩니다. 가족 만남 장소 선택 지도는 현재 OSM을 유지합니다.

## 이 Mac에서 실행

```sh
./scripts/run_app.sh emulator-5556
./scripts/run_app.sh E3A83EF7-8FD6-4656-AE84-EFA2E3136351
```

실행 스크립트는 로컬 키 파일이 있으면 적용하고, 없으면 키 없는 기본 지도로 실행합니다. iPhone 미리보기 촬영 후 일반 앱 복구에도 이 스크립트를 사용합니다. 기존 미리보기 촬영 테스트 자체는 OSM 화면을 캡처하며, 카카오 실제 화면은 `artifacts/kakao-iphone17-pro.png`와 `artifacts/kakao-android.png`에서 확인합니다.

## 다른 개발 환경에서 키를 넣는 방법

1. [Kakao Developers](https://developers.kakao.com/console/app)에서 대상 계정의 기존 SAFE KOREA 앱을 선택하고 **카카오맵 > 사용 설정**을 확인합니다. 계정을 바꿀 때는 기존 앱 유무와 무료 쿼터 대상을 먼저 확인합니다. 새 계정에서 발급한 키를 사용해야 하며 이전 계정의 키로 대체하지 않습니다.
2. Android 패키지명은 `kr.example.safe_korea`, iOS Bundle ID는 `kr.example.safeKorea`입니다. Android 개발 서명의 키 해시도 해당 앱에 등록해야 합니다. 배포 서명은 별도 등록 대상입니다.
3. **앱 > 플랫폼 키 > 네이티브 앱 키**에서 Android/iOS 정보를 등록하고 지도 SDK용 **네이티브 앱 키**를 사용합니다. REST API 키·Admin 키·다른 사이트의 키를 사용하지 않습니다.
4. 로컬 설정이 없는 경우에만 예제 파일을 복사하고 값을 채웁니다. 이 Mac에는 이미 설정되어 있습니다.

```sh
cp -n config/kakao.example.json config/kakao.local.json
```

```json
{
  "KAKAO_NATIVE_APP_KEY": "발급받은 네이티브 앱 키"
}
```

`config/kakao.local.json`은 Git에서 제외했습니다. 실제 키를 문서·로그·커밋에 넣지 마세요.

```sh
JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home .tools/flutter/bin/flutter run -d emulator-5556 --dart-define-from-file=config/kakao.local.json
BYPASS_PERMISSION_LOCATION_ALWAYS=1 .tools/flutter/bin/flutter run -d E3A83EF7-8FD6-4656-AE84-EFA2E3136351 --dart-define-from-file=config/kakao.local.json
```

## 무료 사용 범위 확인

2026-11-01 확인한 [공식 카카오맵 안내](https://developers.kakao.com/docs/ko/kakaomap/common)에 따르면, 2026-07-21부터 개발자 계정에서 처음 카카오맵 API를 활성화한 앱에만 무료 쿼터를 제공합니다. 앱 정보의 **카카오맵 무료 쿼터** 배지를 확인해야 합니다. 다른 앱의 활성화를 해제하면 무료 대상이 옮겨진다고 가정하지 않습니다. 두 번째 활성화 앱이나 무료 한도 초과 사용은 유료 설정이 필요하므로 자동으로 비즈월렛·결제를 연결하지 않습니다.

플랫폼 정보의 현재 설정 위치는 [앱 설정 문서](https://developers.kakao.com/docs/ko/app-setting/app)의 네이티브 앱 키 절을 따릅니다.

## 동작

- 지도 열기를 선택했을 때만 SDK 인증과 지도 생성을 시작합니다. 앱 시작이나 오프라인 행동강령 열람에 키가 필요하지 않습니다.
- 인증/지도 준비가 실패하면 기본 지도로 전환합니다. 인증 완료가 아닌 상태에서 카카오 지도가 동작했다고 표시하지 않습니다.
- 공식 민방위 시설의 좌표로 ‘대피소’ 그림이 있는 전용 핀을 생성합니다. 핀을 누르면 시설 이름·주소·자료 갱신 여부와 현장 확인 안내를 표시합니다.
- 카카오 SDK의 로고를 가리지 않습니다. 기본 지도에서는 OpenStreetMap 저작자 표시를 지도 안에 표시합니다.
- 조회 지역과 IP 등 지도 요청에 필요한 정보는 선택한 지도 제공자에 전달됩니다. 앱 자체가 가족 연락처나 계획을 지도 서버에 전송하지 않습니다.
- Kakao SDK의 사용 한도·이용 조건은 해당 프로젝트 계정에서 확인하세요. 별도 유료 서비스 가입·결제를 수행하지 않았습니다.

## 검증 결과와 남은 항목

- 완료: Android 개발 서명/iOS Bundle ID, 무료 지도 사용 설정, 양쪽 시뮬레이터 인증·배경 지도·대피소 핀·카메라 확대.
- 네이티브 통합 테스트는 실제 카메라 응답과 확대를 확인합니다. Android는 핀 ID 등록/갱신도 검사합니다. iOS 플러그인은 자체 핀 ID를 발급하므로 같은 ID 검사를 적용하지 않고 캡처에서 핀을 확인했습니다.
- 남음: 실제 기기에서 핀 터치·상세 화면 전체 흐름, 통신 단절·복구, 성능·접근성 및 배포 서명 확인.

```sh
# 명시적 온라인 검증: 공식 종로구 조회 1회와 카카오 지도 요청 포함
BYPASS_PERMISSION_LOCATION_ALWAYS=1 .tools/flutter/bin/flutter test integration_test/kakao_map_test.dart -d E3A83EF7-8FD6-4656-AE84-EFA2E3136351 --no-uninstall --dart-define-from-file=config/kakao.local.json
# 테스트 후 일반 앱 복구
./scripts/run_app.sh E3A83EF7-8FD6-4656-AE84-EFA2E3136351
```

참고: [카카오 지도 개념 및 키 종류](https://developers.kakao.com/docs/en/kakaomap/common), [카카오 지도 iOS SDK](https://apis.map.kakao.com/ios_v2/docs/getting-started/gettingstarted/). Flutter 연결에는 공식 네이티브 SDK를 감싼 오픈소스 `kakao_map_sdk` 1.3.1을 사용합니다.
