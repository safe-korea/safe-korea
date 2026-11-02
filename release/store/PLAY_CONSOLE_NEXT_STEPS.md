# safeKor — 앱 생성 이후 입력 자료

앱 생성은 사용자 완료 보고 기준입니다. 아래 항목을 콘솔에 입력하거나 제출했다고 간주하지 않습니다.

## 앱 콘텐츠

| 화면 | 현재 구현에 따른 입력 자료 |
|---|---|
| 개인정보처리방침 | https://safe-korea-shelter-api.trovapp.workers.dev/privacy |
| 광고 | 현재 빌드에 광고 SDK/광고 배너 없음 |
| 앱 액세스 권한 | 로그인/구독 없이 모든 기능 이용, 심사용 계정 불필요 |
| 정부 앱 여부 | 정부 또는 지자체가 제작·운영하는 앱 아님 |
| 데이터 보안 | `release/legal/DATA_SAFETY_REVIEW.md` 검토. 지도 SDK·호스팅 처리 확인 전 ‘수집 없음’ 일괄 선택 금지 |
| 콘텐츠 등급·타깃 연령 | 실제 콘솔 질문과 출시 대상 연령 확인 후 답변. 임의로 전 항목 ‘아니요’ 선택하지 않음 |

## 기본 스토어 등록정보

- 앱 이름: `ko-KR/title.txt`
- 간단한 설명: `ko-KR/short-description.txt`
- 자세한 설명: `ko-KR/full-description.txt`
- 아이콘 512×512: `release/branding/icon-play-512.png`
- 그래픽 이미지 1024×500: `release/branding/feature-graphic-1024x500.png`
- 실제 Android 화면 4장: `release/store/ko-KR/upload-screenshots/`
- 지원 이메일: taetaeg@gmail.com
- 지원 웹사이트: https://safe-korea-shelter-api.trovapp.workers.dev/support

## 번들

최신 서명 AAB: `build/app/outputs/bundle/release/app-release.aab` (76.9MB), package `kr.safekor.app`, version 1.0.0+1, targetSdk 36. 이 파일은 아직 Play Console에 업로드하지 않았습니다. 기존에 같은 버전 코드를 업로드했다면 새 버전 코드로 재생성해야 합니다.

심사·프로덕션 공개에 앞서 데이터 보안 최종 검토, Google Play 앱 서명용 카카오 인증, 실기기 지도·알림·오프라인 검증이 남아 있습니다. iPhone 네이티브 시뮬레이터 영상은 Android 스크린샷이나 iPhone PWA 기능 검증 자료로 대체하지 않습니다. Play의 홍보 동영상 입력란은 YouTube 링크용이며 MP4를 직접 넣는 칸으로 안내하지 않습니다.
