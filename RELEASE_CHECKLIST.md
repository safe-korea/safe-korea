# SAFE KOREA 출시 전 점검 — 2026-11-01

**출시 대상: Android 네이티브 앱(Google Play) + iPhone PWA(웹 배포).** iOS App Store 출시는 범위에서 제외합니다. 기존 iOS 코드와 검증 기록은 보존합니다.

**판정: 공개 출시 보류.** MVP 기능과 로컬 빌드 검증은 진행했지만, SDK 개인정보 최종 검토·카카오 배포 인증·실기기 검증이 남아 있습니다. 공개 개인정보·문의 페이지와 스토어 문구/화면/브랜드 시안은 준비했습니다. 이 문서는 출시 승인이 아닙니다. Workers API와 개인정보·문의 웹페이지는 사용자 승인 범위에서 배포했습니다. PWA 미리보기 배포와 로컬 업로드 서명 키 생성은 완료했습니다. Play 업로드·심사 제출·유료 가입은 하지 않았습니다.

## 완료한 기술 점검

| 항목 | 근거 / 결과 |
|---|---|
| 자동 검사 | format/analyze 통과, Flutter 163건·Python 12건·Workers 15건 통과. iPhone/Android 색상·권한 안내 네이티브 검사 통과 |
| 색상 역할 | 공습/즉시 대응 빨강, 경계/주의 주황, 해제는 중립색으로 추가 안내 강조. 일반 저장/공유 초록. 훈련 문구 유지. 경보해제를 안전 확인으로 표시하지 않음 |
| 색 대비 | 흰색 위 주요 색 및 주의 배경/글자 대비 4.5:1 이상 자동 검사 |
| 데이터와 권한 | 나의 준비에서 기기 저장, GPS·사진·알림, 외부 제공자, 공유·삭제 방법 확인. 게시된 개인정보처리방침의 대체물은 아님 |
| 릴리스 서명 | Android release의 debug 서명 자동 적용 제거. key.properties 없으면 미서명 빌드. 실제 비밀번호/키는 저장소에 추가하지 않음 |
| Android 릴리스 | AAB 생성, targetSdk 36 / minSdk 24, debuggable false / allowBackup false. 사용자 확정 kr.safekor.app, 업로드 키 서명 및 jarsigner 검증 통과 |
| iOS 릴리스 | --release --no-codesign 빌드. 최소 iOS 15.0, 실제 배포용 인증서/프로비저닝 미적용 |
| Android 16KB | AAB의 arm64-v8a/x86_64 공유 라이브러리 7개의 ELF LOAD 정렬 검사 통과. 실제 16KB 기기 실행과 생성 APK ZIP 정렬은 별도 |
| 오프라인 핵심 | Android API 36 에뮬레이터 비행기 모드 활성화 및 외부 HTTPS 요청 실패 확인 후 훈련·동봉 행동요령·격리 SQLite 저장/재열기/준비물 체크 통과. 이전 연결 상태 복원 |
| 권한 | 릴리스 Android에 위치·인터넷·알림·진동 및 내부 receiver 권한. 백그라운드 위치/카메라/전체 사진 접근/광고 ID 권한 없음. iOS 위치는 사용 중 요청, 알림 자동 권한 요청 없음 |
| 미완료 판매 기능 | 제휴 판매처 없는 비상용품 미리보기 진입은 debug에서만 노출. 릴리스에서는 제거, 체크리스트/라디오는 유지 |

## Android 공개 출시 전에 해결할 항목

| 우선순위 | 남은 일 | 필요한 결정/검증 |
|---|---|---|
| 필수 | 앱 소유자와 고유 식별자 | 사용자 확정 kr.safekor.app 적용. 이전 개발 앱과 별도 설치되며 데이터 자동 이전 없음. 카카오 등록 갱신 필요 |
| 필수 | 배포 서명·계정 | 사용자 계정 개설 확인, 로컬 upload key 및 서명 AAB 생성. Console 로그인·Play App Signing 확인 필요 |
| 필수 | 개인정보처리방침과 문의처 | safeKor / taetaeg@gmail.com / 공개 HTTPS 정책·문의 페이지 및 앱 내부 링크 준비. 포함 SDK·위탁/국외 처리의 최종 검토 남음 |
| 필수 | Google Play Data safety | release/legal/DATA_SAFETY_REVIEW.md에 근거별 신고 초안 작성. 카카오 지도 SDK의 세부 자동 전송/보관은 확인 전 보류. 기존 iOS privacy manifest를 Android 신고의 확정 근거로 전용하지 않음. 자체 서버가 없다는 이유만으로 수집 없음으로 판단하지 않음 |
| 필수 | 앱 아이콘·스토어 정보 | 설명 3종·Android 실제 1080×1920 화면 4장·512px 아이콘·1024×500 배너·캐릭터 시안 준비. 아이콘 채택/launcher 적용 완료. 등급·콘텐츠/광고 문항 최종 확인 남음 |
| 필수 | 배포용 카카오 인증 | 최종 Android applicationId, 배포/Play 서명 해시를 카카오 설정에 반영하고 설치본에서 인증·핀·확대·로드뷰 재검증. 현재 확인은 개발용 등록/시뮬레이터 |
| 필수 | 실제 기기와 사용자 검증 | Android 실기기 GPS 정확도·권한 거부/복구·실내 위치, 테스트 알림 소리/음량·무음모드, TTS 오프라인 음성, 사진 선택, 프로세스 종료 복구, TalkBack, 업데이트/데이터 유지 |
| 확인 필요 | Play 계정 테스트 요건 | 계정 종류/생성일에 따라 폐쇄 테스트 12명·14일 요건 적용. 계정을 확인하지 않았으므로 충족 여부 미확인 |
| 확인 필요 | 자료 운영·이용 조건 | 공식 시설 조회의 문서화되지 않은 엔드포인트, 지역별 불일치, 차단/변경 대응, 행동요령 검토 책임자/갱신 절차 확보. 전국 완전성·시설 개방·이동 경로 안전 보장 금지 |
| 확인 필요 | 향후 SDK 유지보수 | flutter_tts의 향후 KGP 호환 경고. 현재 빌드 성공과 장기 호환성은 별도. 최종 AAB 및 Play 배포 설치본 검증 |

실제 정부 경보 수신은 미구현입니다. 이를 포함한 앱으로 출시하려면 API 승인·지연·신뢰성·발송 체계를 별도 검증해야 합니다. 현재 프로토타입 설명에 실시간 경보 수신을 주장하지 않습니다.

## iPhone PWA 출시 준비 — 핵심 미리보기 구현

`web/`와 별도 Flutter Web 진입점에 설치 온보딩·오프라인 행동요령을 구현했습니다. 네이티브 SQLite·파일·지도·알림은 아직 웹으로 전환하지 않았습니다. 상세 범위는 [PWA_PLAN.md](PWA_PLAN.md)를 참고하세요.

- 웹 빌드 기반 및 플랫폼별 저장소·사진·지도·음성·알림 어댑터 구현.
- HTTPS 웹 주소, manifest/홈 화면 아이콘, 오프라인 캐시·갱신·실패 복구 구현.
- iPhone Safari/홈 화면 앱에서 GPS·지도·저장·공유·오프라인·VoiceOver 검증.
- 웹 데이터 처리에 맞는 개인정보 안내와 공개 정책 준비.
- Apple 개발자 계정·네이티브 서명·App Store 심사/5.1.5 검토는 이번 배포 방식의 출시 조건에서 제외. 웹의 권한·보안·개인정보 요구사항은 별도로 검증.

## 재현과 증거 (기존 iOS 네이티브 검증은 이력)


- `./scripts/verify.sh`: 서식·정적 분석·Flutter·Python 회귀 검사.
- `flutter build appbundle --release --dart-define-from-file=config/kakao.local.json`: 실제 명령은 로컬 .tools/flutter/bin/flutter 사용. Android 키 파일이 없으면 unsigned AAB.
- `BYPASS_PERMISSION_LOCATION_ALWAYS=1 .tools/flutter/bin/flutter build ios --release --no-codesign --dart-define-from-file=config/kakao.local.json`: 위치 플러그인의 Always 권한 코드를 제외하는 빌드 플래그이며 보안/샌드박스 해제 옵션이 아님.
- `python3 scripts/inspect_release.py > artifacts/release-artifact-inspection.json`: manifest·서명 entry·ELF 정렬·iOS 포함 privacy manifest의 제한된 정적 검사. 이 결과만으로 스토어 준비 완료를 판정하지 않음.
- 로그: `artifacts/release-aab-build.log`, `release-ios-build.log`, `release-verify.log`, `release-offline-android.log`, `release-offline-mode.log`.
- 앱 바이너리에는 클라이언트용 지도 키가 포함될 수 있음. 바이너리/키 파일은 Git에 올리지 않으며 클라이언트 키를 서버 비밀키처럼 보호된 것으로 설명하지 않음.

## 확인한 공식 기준

- [Google Play target API](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en): 신규/업데이트의 API 36 기준 확인.
- [Android 16KB 지원](https://developer.android.com/guide/practices/page-sizes): ELF·패키징·런타임을 구분해 검증.
- [Apple 제출 요구사항](https://developer.apple.com/news/upcoming-requirements/): Xcode 26/iOS 26 SDK 및 최소 OS 조건 확인.
- [Apple 심사 지침](https://developer.apple.com/app-store/review/guidelines/): 개인정보, 앱 완성도, 5.1.5 위치 API 관련 검토.
- [Apple SDK 개인정보 요건](https://developer.apple.com/support/third-party-SDK-requirements/): 포함 SDK의 개인정보 manifest·서명 검토.
- [Google Play 사용자 데이터 정책](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en): 공개 정책과 앱 내부 안내, 데이터 처리의 정확한 공개 필요.
- [Play 신규 개인 계정 테스트](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en): 해당 계정의 테스트 기간/인원 및 production 신청 확인.

## Workers API 추가 이후 배포 조건

지역 API는 2026-11-01 사용자 승인 후 Workers에 실제 배포했습니다. health·정부 자료 72곳·캐시·CORS 확인 완료. 공개 전 정부 자료 이용 조건, Cloudflare 계정·도메인·고유 rate namespace IDs, 실제 PWA CORS origin, HTTPS API URL 빌드 설정, 운영 CPU/요청량/장애 복구 검증, Cloudflare IP 처리 개인정보 고지를 확인합니다. 운영 URL은 config/api.production.json에 기록했습니다. API 배포와 PWA 사이트 공개·정식 앱 출시는 별개입니다. [상세](workers/shelters/README.md).

## 2026-11-02 보안 점검

- Git 전체 refs의 blob 1,490개에서 알려진 로컬 서비스키 일치 및 주요 GitHub 토큰/개인키 패턴 검사: 일치 없음. key.properties/keystore/local config 추적 없음. 이미지/OCR·알 수 없는 모든 키 형식까지 보증하는 검사는 아님.
- GitHub public 저장소: secret scanning/push protection 활성화, 열린 탐지 0건. 비활성 Dependabot alerts/security updates를 활성화하고 열린 경고 0건 확인. GitHub 로그인 계정 2FA·복구수단 상태는 확인하지 않음.
- npm audit 전체 의존성 알려진 취약점 0건. OSV querybatch Pub 생태계에 공개 패키지명/버전 135개만 전달해 일치 0건. 원본 코드·키·개인정보 전송 없음. 네이티브 Kakao 등 Gradle/CocoaPods 전체 공급망 취약점을 검증한 것으로 확대하지 않음.
- Worker: 고정 정부 URL/지역 허용목록/응답 크기 제한/시간 초과/리다이렉트 금지/외부 원본 헤더 미전달 확인. CORS는 인증이 아니며 공개 시설 API는 origin 없는 요청도 허용. 상위 조회 제한은 위치별 근사치이며 글로벌 과금 상한 보장은 아님.
- Android 소스: 최소 위치/알림/인터넷 권한, 백그라운드 위치·주소록·마이크 없음, 백업 차단. 기존 서명 AAB debuggable=false 검사 기록 유지. 최신 변경을 담은 최종 제출 AAB는 별도로 다시 빌드·확인해야 함.
- PWA에 frame-ancestors/X-Frame-Options/object/base/form 제한과 same-origin geolocation·카메라/마이크 차단 헤더 추가. JS 전체 CSP 제한은 Flutter 호환 검증 없이 임의 적용하지 않음.
- CI 추가: public GitHub-hosted runner, read-only token, checkout 자격증명 미보존, 공식 Action SHA 고정, 운영 키/배포 비밀 없음. Python/Worker 검사와 npm audit, 경량 Git 비밀 탐지. Flutter 전수 검사와 실기기 검증은 이 CI에 포함하지 않음.
- 출시 보류 조건은 유지: 실제 경보 전달 미완성, 카카오 배포 인증·데이터 보안 최종 신고·Play 계정별 테스트·실기기 점검. 보안 검사 통과를 앱 출시 완료로 취급하지 않음.
- GitHub main 보호 실제 적용: PR + security-checks 성공/최신 main 기준 검사, 관리자 포함, force push/삭제 금지. 개인 저장소로 승인 리뷰어 수 0이며 독립 코드 리뷰 완료를 뜻하지 않음. 최초 실제 Actions run 41397857762 통과. 주간 Dependabot 설정 파일은 PR #12 머지 후 기본 브랜치에 반영됨.
- 최신 제출 후보 AAB 재빌드·서명 검증 완료: `build/app/outputs/bundle/release/app-release.aab` (75,608,970 bytes), SHA-256 `dd94003d037b11a90b0a508a6b42bd929d6002608f93e49642b77756969fbd77`. debuggable=false/allowBackup=false 재확인. Play 업로드·카카오 배포 인증·실기기 검증과 별개.
