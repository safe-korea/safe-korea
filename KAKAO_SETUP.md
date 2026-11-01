# 카카오 지도 연결

지도 연결 코드와 Android/iOS SDK는 포함되어 있습니다. **개발용 네이티브 키는 로컬에 저장했지만 카카오 지도 인증·배경 렌더는 아직 검증하지 않았습니다.** 기존 계정에서는 다른 앱이 무료 쿼터 대상이어서 SAFE KOREA 활성화에 유료 월렛이 필요했습니다. 유료 설정은 진행하지 않았으며 사용자가 다른 계정으로 전환 중입니다. 현재 앱은 기본 OpenStreetMap 지도로 표시하며 이를 화면에 구분합니다. 실제 정부 대피소 조회/목록/핀/오프라인 저장은 그대로 사용할 수 있습니다.

## 나중에 키를 넣는 방법

1. [Kakao Developers](https://developers.kakao.com/console/app)에서 대상 계정의 기존 SAFE KOREA 앱을 선택하고 **카카오맵 > 사용 설정**을 확인합니다. 계정을 바꿀 때는 기존 앱 유무와 무료 쿼터 대상을 먼저 확인합니다. 새 계정에서 발급한 키를 사용해야 하며 이전 계정의 키로 대체하지 않습니다.
2. Android 패키지명은 `kr.example.safe_korea`, iOS Bundle ID는 `kr.example.safeKorea`입니다. Android 개발 서명의 키 해시도 해당 앱에 등록해야 합니다. 배포 서명은 별도 등록 대상입니다.
3. **앱 > 플랫폼 키 > 네이티브 앱 키**에서 Android/iOS 정보를 등록하고 지도 SDK용 **네이티브 앱 키**를 사용합니다. REST API 키·Admin 키·다른 사이트의 키를 사용하지 않습니다.
4. 예제 파일을 로컬 설정으로 복사하고 값을 채웁니다.

```sh
cp config/kakao.example.json config/kakao.local.json
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

## 키 입력 후 필요한 검증

- Android 키 해시/iOS Bundle ID 및 지도 사용 설정 확인
- Android/iOS에서 카카오 배경 지도 인증·로딩, 확대/이동, 대피소 핀과 상세 화면
- 네트워크 단절/인증 실패 시 기본 지도·목록 복귀
- 실제 기기 화면과 성능·접근성 확인

참고: [카카오 지도 개념 및 키 종류](https://developers.kakao.com/docs/en/kakaomap/common), [카카오 지도 iOS SDK](https://apis.map.kakao.com/ios_v2/docs/getting-started/gettingstarted/). Flutter 연결에는 공식 네이티브 SDK를 감싼 오픈소스 `kakao_map_sdk` 1.3.1을 사용합니다.
