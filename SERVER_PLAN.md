# SAFE KOREA 서버 구성

## 앱 백엔드: Android와 PWA가 함께 쓰는 데이터 서버

사용자가 말한 앱 서버는 호스팅 설명과 별개인 **앱 백엔드 API**입니다. 목표 구성은 Android와 iPhone PWA가 같은 대피시설 데이터 API를 사용하는 것입니다. **현재 백엔드는 구현·배포되어 있지 않습니다.** Android는 정부 사이트를 직접 조회하고, PWA는 행동요령만 제공합니다.

| 처리 위치 | 역할 | 현재 상태 |
|---|---|---|
| 앱 백엔드 | 공식 대피시설 수집·검증·갱신·지역별 조회·공용 캐시·자료 시각 제공 | 설계 단계. 공식 API/이용 조건 확인 후 구현 |
| 기기 | GPS 일회 확인·거리 계산·가족 계획/사진/체크리스트 저장 | Android 구현, PWA 일부 미전환 |
| 지도 제공자 | 지도 배경·지도 SDK 서비스 | Android 카카오 연동, PWA 미전환 |
| 향후 백엔드 | 로그인/기기 간 동기화, 승인된 실제 경보 연계·푸시 | 현재 범위 밖, 미구현 |

```text
Android 앱 ──────┐
                ├→ 공통 앱 API → 검증된 공식 시설 데이터 / 지역별 공용 캐시
iPhone PWA ──────┘
각 기기: GPS 거리 계산 / 개인 계획 저장 / 오프라인 행동요령
```

앱 데이터 서버의 초기 구현 후보는 Flask 읽기 전용 API입니다. 시설 데이터용 공용 캐시는 개인 정보 DB와 다릅니다. 처음부터 회원/가족 정보를 서버에 저장할 필요는 없습니다. 운영 API의 주소·가용성·갱신/장애 대응·로그 정책과 공식 자료 이용 조건을 확정해야 배포 완료로 볼 수 있습니다. 현재 서버가 동작한다는 의미로 설명하지 않습니다.

## 클라우드 실행 환경: Oracle 무료 VM은 초기 베타 후보

2026-11-01 공식 문서 확인 기준으로 Oracle Always Free A1은 월 1,500 OCPU 시간·9,000 GB 시간, 합계 2 OCPU·12 GB에 해당합니다. 과거의 4 OCPU·24 GB 안내를 현재 계정에 그대로 적용하지 않습니다. 실제 계정 한도·홈 리전·Always Free 표시와 무료 자원 생성 가능 여부를 확인해야 합니다.

초기 배포 제안은 **Oracle VM에서 Flask API/지역별 캐시를 운영하고, Cloudflare Pages에서 PWA 파일을 제공**하는 구성입니다. 현재 규모의 읽기 중심 API를 시험하는 후보이며 부하 테스트 전 처리 용량을 보장하지 않습니다. Oracle VM의 운영체제 업데이트·TLS·접근 제어·백업·상태 확인은 운영자가 관리합니다.

Oracle 공식 문서는 유휴 무료 VM 회수 가능성과 홈 리전의 생성 용량 부족을 명시합니다. 따라서 무료 VM 한 대를 실제 긴급경보 수신/발송의 유일한 기반으로 삼지 않습니다. 베타에서는 캐시·오프라인 대체를 확보하고, 출시 시 필요한 가용성·복구 목표를 정한 뒤 운영 서비스를 선택합니다. 불필요한 부하를 만들어 회수 조건을 회피하지 않습니다. 30일 체험 크레딧과 Always Free 자원을 구분하며 자동 유료 전환이나 자원 생성을 진행하지 않습니다.

현재는 구성 제안만 기록했습니다. Oracle 계정/VM 생성, 결제 정보 입력, 네트워크 설정, 서버 배포는 하지 않았습니다.

공식 근거: [Oracle Always Free 자원과 회수·용량 조건](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm).

## 배포에는 호스팅 서버가 필요합니다

PWA를 공개하려면 사용자의 브라우저에 HTML·JavaScript·앱 파일을 HTTPS로 제공하는 **호스팅 서버가 반드시 필요합니다**. 현재 행동요령 미리보기에는 별도 API·DB 서버가 없지만, 전체 앱의 공통 시설 데이터 API는 위의 백엔드 범위로 준비합니다. 정적 호스팅도 서버 인프라를 사용하는 서비스이며, 서버가 전혀 없는 배포라는 뜻이 아닙니다.

초기 배포안은 **Cloudflare Pages의 정적 호스팅**입니다. 직접 만든 `build/web` 산출물을 Direct Upload로 배포하는 방식으로 준비합니다. Cloudflare가 웹 파일 제공을 운영하고, 앱에 계정/가족 동기화 DB는 두지 않습니다. 배포 계정·도메인·운영 주체·개인정보 정책을 확정한 뒤 사용자 승인으로 실제 업로드합니다. 아직 계정 생성이나 배포는 하지 않았습니다.

- `web/_headers`: 미해시 앱 파일의 재검증과 기본 응답 헤더 설정.
- `web/404.html`: 없는 정적 자원이 HTML 200으로 대체되지 않도록 404 페이지 제공.
- `build/web`만 배포하며 `_headers`는 호스팅 설정이므로 오프라인 캐시 목록에서 제외합니다.
- 무료 플랜 한도와 단일 파일 25 MiB 제한은 실제 배포 전 다시 확인합니다. 현재 빌드 산출물 크기를 검사할 수 있으며 비용/가용성을 보장하지 않습니다.
- [Cloudflare Direct Upload](https://developers.cloudflare.com/pages/get-started/direct-upload/) · [플랫폼 제한](https://developers.cloudflare.com/pages/platform/limits/).

## 현재 구현: 정적 PWA

Android는 기존 Flutter 네이티브 앱을 유지합니다. iPhone PWA는 `lib/pwa_main.dart`를 별도 진입점으로 사용하고, 공유 행동요령·디자인 토큰을 재사용합니다. `./scripts/build_pwa.sh`가 만드는 `build/web`을 HTTPS 정적 호스팅에 올리는 구조입니다. 현재는 localhost 미리보기만 실행했으며 외부 배포는 하지 않았습니다.

PWA의 설치 안내, 행동요령과 오프라인 캐시는 별도 API 서버·계정·서버 DB 없이 작동합니다. 설치 안내 확인 여부는 localStorage, 공개 앱 파일은 Cache Storage에 보관합니다. 이 미리보기에는 가족 저장·GPS·웹 지도·푸시가 없습니다. 향후 가족 저장은 먼저 IndexedDB 등 기기 저장소로 구현하고 동기화가 필요할 때만 서버 DB를 검토합니다.

```text
Android → 현재 공식 시설 조회(기존 기능)
iPhone Safari / 홈 화면 앱 → HTTPS 정적 호스팅 → 앱·글꼴·행동요령
                         ↳ Cache Storage → 사전 저장 후 오프라인 실행
```

## 시설 API: 필요성이 확인됐지만 아직 추가하지 않음

2026-11-01 공개 정부 시설 엔드포인트에 지역 코드 11140으로 직접 HTTP 요청과 브라우저 요청을 각각 1회 확인했습니다. HTTP 200이지만 Access-Control-Allow-Origin 헤더가 없었고, Chromium localhost 페이지의 동일 요청은 TypeError로 실패했습니다. 따라서 네이티브의 직접 조회를 PWA에서 그대로 사용할 수 있다고 가정하지 않습니다. 증거: `artifacts/pwa-cors-check.json`. 운영 도메인 동작과 데이터 이용 조건은 별도 확인 대상입니다.

우선 공식 문서화된 API/키·재배포 조건을 확인합니다. 허용된 정적 시설 스냅샷 배포로 충분하면 별도 API 서버 없이 지역별 JSON을 제공합니다. 실시간 조회가 필요하고 이용 조건이 허용되면 같은 도메인의 작은 읽기 전용 API를 추가합니다. 브라우저 보안 제한 해제, 무조건적인 CORS 프록시, 임의 URL 프록시는 사용하지 않습니다.

예정 API 계약(미구현): `GET /api/shelters?region=11140`. 서버는 허용된 5자리 지역 코드만 받고, 공식 출처·조회 시각·자료 시점·완전성/오래된 자료 여부를 응답합니다. 위도·경도·가족 정보는 요청하지 않으며 거리 계산은 기기에서 합니다. 고정 상위 호스트, 요청 제한, 응답 크기 제한, 시간 제한, 지역별 공용 캐시 및 장애 시 오래된 자료 표시가 필요합니다. 갱신 주기는 원천의 이용 조건/갱신 주기를 확인해 결정합니다. 상위 서비스 키는 서버 환경변수에만 저장합니다.

서버가 실제로 필요해지면 Flask 또는 호스팅에서 지원하는 작은 서버 함수 중 운영 비용·유지보수에 맞는 것을 선택합니다. 현재 단계에서 Flask/Firebase/서버 DB를 설치하지 않습니다. 무료 호스팅도 용량·대역폭 한도가 있으므로 영구 무료를 보장하지 않습니다.

## 정적 호스팅 배포 조건

- HTTPS와 서비스 워커 지원, 배포할 도메인/운영 주체/연락처 확정.
- 산출물 `build/web`만 게시. 저장소, config, 네이티브 키/서명, .tools는 게시하지 않음.
- 원자적 배포로 HTML·JS·글꼴·manifest·worker가 동일 버전이 되게 함.
- `index.html`, `onboarding.js`, `flutter_bootstrap.js`, `safe-worker.js`는 재검증(`Cache-Control: no-cache`). 미해시 파일에 장기 immutable 적용 금지.
- 없는 정적 파일은 404 응답. 모든 경로에 index.html을 200으로 돌려주는 설정 금지. wasm은 application/wasm으로 제공.
- 설치 worker는 앱 파일만 캐시. 지도 타일·제3자 서비스·임의 API 응답을 캐시하지 않음.
- 실행 중인 창은 강제로 새 worker로 전환하지 않음. 새 버전은 앱 창을 모두 닫은 뒤 적용. 오래된 자료의 확인 날짜는 화면에 유지.
- 공개 개인정보처리방침 및 호스팅 로그 처리/보관 조건 확정. 이 문서나 온보딩 안내를 공식 정책으로 대체하지 않음.
- 외부 배포는 사용자 승인 후 진행.

## 푸시 서버

현재 실제 정부 경보 수신은 양쪽 모두 미구현입니다. 공식 API 승인·신뢰성·지연 검증 전에는 푸시 서버를 추가하지 않습니다. iPhone 홈 화면 PWA의 Web Push 지원은 정부 경보 연계나 자동 사이렌 재생 보장을 의미하지 않습니다.

## 로컬 실행

```sh
./scripts/build_pwa.sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory build/web
# Mac 브라우저: http://127.0.0.1:8765
```

이 localhost 주소는 Mac에서 보는 개발용입니다. iPhone 실기기 설치/GPS/서비스 워커 검증은 접근 가능한 HTTPS 환경이 필요합니다. macOS WebKit 자동 테스트와 iPhone 실제 설치 검증은 구분합니다.

## 개발 QA 재현

브라우저 도구는 앱 배포물과 분리해 `.tools/pwa-qa`에 설치합니다.

```sh
npm install --prefix .tools/pwa-qa --no-audit --no-fund playwright
.tools/pwa-qa/node_modules/.bin/playwright install chromium webkit
# 위의 로컬 서버를 실행한 상태에서:
node scripts/test_pwa_browser.cjs
./scripts/verify.sh
```

웹 초기화와 푸시 범위의 공식 근거: [Flutter 초기화](https://docs.flutter.dev/platform-integration/web/initialization), [Flutter 오프라인 FAQ](https://docs.flutter.dev/platform-integration/web/faq), [WebKit 홈 화면 Web Push](https://webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados/).
