# SAFE KOREA Play 제출 준비 패키지

운영자 표시명: **safeKor**. 공개 문의: **taetaeg@gmail.com**. 앱 이름: **SAFE KOREA**.

## 스토어 입력 자료

- store/ko-KR/title.txt: 30자 이내 앱 이름 후보
- store/ko-KR/short-description.txt: 80자 이내 짧은 설명
- store/ko-KR/full-description.txt: 4,000자 이내 상세 설명
- store/ko-KR/upload-screenshots/: 제출용 JPEG 4장, 1080×1920. 투명도 없는 형식으로 인코딩만 변환했으며 내용·구도는 변경하지 않음.
- store/ko-KR/screenshots/: 실제 Android API 36 원본 PNG 4장, 1080×1920. AI UI/가상 시설/개인정보/자동 경보 연출 없음. Android integration test로 캡처했고 원본을 편집하지 않음.
- branding/icon-play-512.png: 기존 집 심볼을 정리한 Play 아이콘 시안. 최종 채택/Android launcher 적용 전 후보.
- branding/feature-graphic-1024x500.png: 기능 그래픽 후보, SVG/HTML에서 코드로 렌더링.
- branding/mascot-jindo-v1.png: AI 생성 캐릭터 제안. 앱에 미적용. 원본·프롬프트·적용 범위는 branding/BRIEF.md.

## 공개 페이지

- 개인정보처리방침: https://safe-korea-shelter-api.trovapp.workers.dev/privacy
- 문의/삭제 도움말: https://safe-korea-shelter-api.trovapp.workers.dev/support
- 원본 HTML은 workers/shelters/public/에 있으며 서버 요청 로그/분석·추적 스크립트·외부 폰트를 추가하지 않음.

## 제출 상태

이 패키지를 만들었다고 Play 심사 제출이나 출시를 완료한 것은 아닙니다. `legal/DATA_SAFETY_REVIEW.md`는 근거별 신고 초안이며 SDK 상세 자료와 최종 빌드 확인 후 Console에 입력합니다. 모든 항목을 No로 채운 CSV는 만들지 않습니다. 콘텐츠 등급/연령 대상/정부 앱 여부 문항도 실제 앱 기준으로 운영자가 확인해야 합니다.

- 앱/개발자 표시명·고유 applicationId와 업로드 키/Play 서명, 카카오 배포 해시 등록 남음.
- 카카오 SDK/Cloudflare 등 개인정보·위탁/국외 처리 최종 검토 남음.
- 정책에 정한 문의 종료 후 최대 90일 보관/삭제는 운영자가 Gmail에서 직접 수행해야 하며 자동 삭제 기능은 구현하지 않음. 필요한 법정 보관 예외는 별도로 검토.
- 앱 아이콘 시안은 아직 설치 앱의 launcher 아이콘이 아님. 캐릭터 권리/이름/최종 방향 검토 후 앱에 적용.
- 정부 원천 자료 이용 조건, 실기기 검증과 계정별 폐쇄 테스트 요건 남음.

## 캡처 재현

`integration_test/android_store_capture_test.dart`, `test_driver/android_store_capture.dart` 사용. Android 에뮬레이터 화면 크기를 임시로 1080×1920으로 설정하고 캡처 후 원래 크기로 복구. 위치·연락처·저장된 개인 계획에 접근하지 않고 실제 홈/행동강령/실내/실외 위젯을 캡처. 테스트 실행 뒤 일반 앱 복구 필요.

Google 기준: https://support.google.com/googleplay/android-developer/answer/9866151
