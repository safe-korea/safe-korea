# safeKor 서버 구성 — 2026-11-02

Android/iPhone PWA 공통 Cloudflare Workers를 운영합니다. 소개와 앱·시설 API·개인정보/문의 페이지가 같은 HTTPS origin을 사용합니다. 무료 범위로 구성했으며 새 유료 서비스나 VM은 도입하지 않았습니다.

- 공유 소개: https://safe-korea-shelter-api.trovapp.workers.dev/intro/
- 설치 아이콘 실행: https://safe-korea-shelter-api.trovapp.workers.dev/app/
- 가족·준비물·시설·지도: Android SQLite 또는 PWA 브라우저 안에 저장. 계정/가족 자료 서버 동기화 없음.
- 시설 조회: 기존 지역별 API·공개 자료 캐시. 요청에는 지역 코드만 포함하며 GPS/가족 계획은 보내지 않음.
- PWA 알림: 명시적 동의 후 구독 주소·암호화 키·선택 지역·관리 해시를 D1에 저장. Apple Web Push로 암호화해 전송. 사용자 기기 테스트/표시/열기와 해제·삭제 구현.
- 서명키: Worker 안에서 생성·보관, 공개 API는 공개키만 반환. 정부 API 키: 사용자 승인 후 Cloudflare Secret에 등록, 앱과 Git에는 없음.
- 정부 API 수집: 2분 cron, 일일 900회 상한, 동시 실행 lease, 전체 건수·분류·시각·지역·중복 검사. 인증 오류는 6시간 재시도 제한.

현재 정부 API는 Workers에서 오류 32(미등록 IP)를 반환하고 Mac에서는 조회됩니다. 운영 출구 IP/이용 조건 해결 전 실제 정부 경보 발송 게이트는 false로 유지합니다. Cloudflare의 변동 가능한 출구를 고정 IP로 가정하거나 전체 IP 허용으로 바꾸지 않았습니다.

푸시 구현/배포는 실제 iPhone의 설치·권한 동의·알림 표시/탭 검증과 다릅니다. 대규모 경보 발송 부하·종단 지연·누락은 검증하지 않았습니다. [운영/복구/검증](workers/shelters/PUSH_OPERATIONS.md)을 참고하세요. 무료 한도에 따른 가용성도 보장하지 않습니다.
