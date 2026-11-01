# SAFE KOREA 출시 전 점검 — 2026-11-01

**판정: 공개 출시 보류.** MVP 기능과 로컬 빌드 검증은 진행했지만, 서명·식별자·정책·스토어 자료·실기기 검증이 남아 있습니다. 이 문서는 출시 승인이 아닙니다. 업로드·배포·유료 가입·인증서 생성은 하지 않았습니다.

## 완료한 기술 점검

| 항목 | 근거 / 결과 |
|---|---|
| 자동 검사 | format/analyze 통과, Flutter 147건·Python 10건 통과. iPhone/Android 색상·권한 안내 네이티브 검사 통과 |
| 색상 역할 | 공습/즉시 대응 빨강, 경계/주의 주황, 해제는 중립색으로 추가 안내 강조. 일반 저장/공유 초록. 훈련 문구 유지. 경보해제를 안전 확인으로 표시하지 않음 |
| 색 대비 | 흰색 위 주요 색 및 주의 배경/글자 대비 4.5:1 이상 자동 검사 |
| 데이터와 권한 | 나의 준비에서 기기 저장, GPS·사진·알림, 외부 제공자, 공유·삭제 방법 확인. 게시된 개인정보처리방침의 대체물은 아님 |
| 릴리스 서명 | Android release의 debug 서명 자동 적용 제거. key.properties 없으면 미서명 빌드. 실제 비밀번호/키는 저장소에 추가하지 않음 |
| Android 릴리스 | AAB 생성, targetSdk 36 / minSdk 24, debuggable false / allowBackup false. 서명 없음 |
| iOS 릴리스 | --release --no-codesign 빌드. 최소 iOS 15.0, 실제 배포용 인증서/프로비저닝 미적용 |
| Android 16KB | AAB의 arm64-v8a/x86_64 공유 라이브러리 7개의 ELF LOAD 정렬 검사 통과. 실제 16KB 기기 실행과 생성 APK ZIP 정렬은 별도 |
| 오프라인 핵심 | Android API 36 에뮬레이터 비행기 모드 활성화 및 외부 HTTPS 요청 실패 확인 후 훈련·동봉 행동요령·격리 SQLite 저장/재열기/준비물 체크 통과. 이전 연결 상태 복원 |
| 권한 | 릴리스 Android에 위치·인터넷·알림·진동 및 내부 receiver 권한. 백그라운드 위치/카메라/전체 사진 접근/광고 ID 권한 없음. iOS 위치는 사용 중 요청, 알림 자동 권한 요청 없음 |
| 미완료 판매 기능 | 제휴 판매처 없는 비상용품 미리보기 진입은 debug에서만 노출. 릴리스에서는 제거, 체크리스트/라디오는 유지 |

## 공개 출시 전에 해결할 항목

| 우선순위 | 남은 일 | 필요한 결정/검증 |
|---|---|---|
| 필수 | 앱 소유자와 고유 식별자 | Android kr.example.safe_korea / iOS kr.example.safeKorea는 예제 이름. 실제 소유자 명의·앱 식별자 확정 후 카카오 등록 및 데이터 이전 영향 검토 |
| 필수 | 배포 서명·계정 | 로컬 유효 코드 서명 identity 0개. Apple 개발자 팀/프로비저닝, Android upload key 및 Play App Signing 준비. 현재 미서명 결과는 제출용이 아님 |
| 필수 | 개인정보처리방침과 문의처 | 운영자/연락처/공개 HTTPS 정책 URL 확정, 실제 처리·보관·삭제·외부 SDK를 반영해 검토. 앱 내부 안내만으로 완료 처리하지 않음 |
| 필수 | App Privacy / Data safety | 카카오 SDK manifest가 OtherDataTypes를 기능 목적·사용자 연결·추적 아님으로 선언. 앱 서버가 없다는 이유로 ‘수집 없음’을 선택하면 안 됨. SDK 제공자 문서와 실제 동작을 대조해 작성 |
| 필수 | 앱 아이콘·스토어 정보 | 현재 iOS 앱 아이콘은 Flutter 기본 이미지 확인. Android/iOS 브랜드 아이콘, 스크린샷, 지원 URL, 등급·콘텐츠/광고 여부, 설명 준비 |
| 필수 | 위치 기반 비상 기능의 심사 적합성 | Apple 5.1.5에 위치 API의 emergency services 용도 제한이 있음. 비공식 사전 대비/시설 정보라는 제품 범위와 현재 GPS 대피시설 기능이 해당 정책에 적합한지 공식 심사 문의·검토 필요. 문구 변경만으로 통과한다고 간주하지 않음 |
| 필수 | 배포용 카카오 인증 | 최종 applicationId/bundle ID, 배포/Play 서명 해시를 카카오 설정에 반영하고 설치본에서 인증·핀·확대·로드뷰 재검증. 현재 확인은 개발용 등록/시뮬레이터 |
| 필수 | 실제 기기와 사용자 검증 | Android/iPhone 실기기 GPS 정확도·권한 거부/복구·실내 위치, 테스트 알림 소리/음량·무음모드, TTS 오프라인 음성, 사진 선택/HEIC, 프로세스 종료 복구, VoiceOver/TalkBack, 업데이트/데이터 유지 |
| 확인 필요 | Play 계정 테스트 요건 | 계정 종류/생성일에 따라 폐쇄 테스트 12명·14일 요건 적용. 계정을 확인하지 않았으므로 충족 여부 미확인 |
| 확인 필요 | 자료 운영·이용 조건 | 공식 시설 조회의 문서화되지 않은 엔드포인트, 지역별 불일치, 차단/변경 대응, 행동요령 검토 책임자/갱신 절차 확보. 전국 완전성·시설 개방·이동 경로 안전 보장 금지 |
| 확인 필요 | 향후 SDK 유지보수 | flutter_tts의 향후 SPM/KGP 호환 경고. 현재 빌드 성공과 장기 호환성은 별도. 개인정보 manifest·서명·필수 API 사유 최종 archive 검토 |

실제 정부 경보 수신은 미구현입니다. 이를 포함한 앱으로 출시하려면 API 승인·지연·신뢰성·발송 체계를 별도 검증해야 합니다. 현재 프로토타입 설명에 실시간 경보 수신을 주장하지 않습니다.

## 재현과 증거

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
