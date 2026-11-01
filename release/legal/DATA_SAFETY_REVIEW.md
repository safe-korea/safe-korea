# Google Play 데이터 보안 신고 작업지 — Android 1.0.0+1

**초안이며 Play Console에 제출하지 않았습니다.** 앱 코드 확인과 제공자 정책을 대조한 상태입니다. “수집 없음”, “모든 정보 임시 처리”, “공유 없음”을 일괄 선택하지 않습니다. 마지막 SDK 확인 항목을 해결한 뒤 실제 배포 바이너리 기준으로 신고합니다. 운영자 safeKor / 문의 taetaeg@gmail.com.

## 작성 원칙

Google은 기기 밖으로 전송하는 SDK 처리도 개발자가 신고하도록 안내합니다. 기기 안에서만 처리하는 자료는 수집 신고 대상에서 제외될 수 있지만 권한 보유 여부만으로 판단하지 않습니다. IP는 실제 이용 목적에 따라 위치 또는 기기 식별자 등으로 분류할 수 있습니다. 아래 보류 항목은 “아니요”가 아닙니다.

| 실제 데이터 흐름 | 앱 코드 근거 | 신고 초안 / 최종 확인 |
|---|---|---|
| GPS 한 번 확인·거리 정렬 | location_service.dart, shelter.dart | 단독 기기 계산은 수집으로 신고하지 않는 범위. 지도/주소변환으로 이어지면 별도 판단 |
| 현재 위치를 중심으로 지도 표시 | shelter_map.dart, map_sdk.dart | 정확한 위치/대략적 위치: optional, 앱 기능 목적 후보. 지도 요청 범위와 카카오 SDK가 보내는 세부 좌표·정밀도 확인 후 항목 확정 |
| 현재 위치로 지역 제안 | region_suggestion_service.dart → Android Geocoder | 기기 시스템 서비스 처리 예외가 실제 구현에 적용되는지 확인. 앱이 직접 서버를 호출하는 흐름과 혼동하지 않음 |
| 수동 선택 지역 코드·요청 주소 | shelter_api_client.dart → Workers → 정부 사이트 | region은 선택 조회 지역이며 현재 위치라고 단정하지 않음. 지역 조회 기능 목적. 서비스 사용 정보/검색 이력 분류는 실제 보관·SDK 동작과 대조 |
| 요청 IP·기기 요청 정보 | Cloudflare/CDN, 지도 타일 | IP는 네트워크가 처리. 앱 코드에서 정밀 GPS/개인 DB 저장 안 함. 제공자의 위치 추론·식별·보안 목적/보관과 대조해 대략적 위치·기기 또는 기타 ID·진단 분류 확정. observability off를 “수집 없음” 근거로 사용하지 않음 |
| 카카오 지도 SDK 자동 전송 | kakao_map_sdk 1.3.1 → com.kakao.maps.open:android:2.15.2 (설치 패키지 Gradle 확인) | 기기/기타 ID, 앱 정보/성능·진단, 위치, 사용정보의 수집/공유 여부 **보류**. 일반 카카오 계정·광고 SDK 설명을 지도 SDK의 확정 자료로 전용하지 않음 |
| 가족 약속·만남 장소·이전 연락처·메모 | local_store.dart | 기기 내 SQLite, 운영자 업로드 없음. 지도 중심 변경은 별도 외부 처리. 사용자 선택 공유는 Google의 user-initiated transfer 예외 적용 가능 여부를 확인 |
| 선택한 사진 복사본 | local_store.dart, shelter_record_screen.dart | 앱 전용 파일. 운영자 업로드 없음. 전체 사진 접근·카메라 권한 없음. 외부 공유/문의 첨부는 사용자가 선택한 별도 처리 |
| 준비물 체크 | local_store.dart | 기기 내 저장만, 수집 신고 대상에서 제외 가능한 범위 |
| 테스트 알림·읽어주기 | drill_notifications.dart, action_speech.dart | 로컬 알림, 원격 푸시 토큰 없음. Android는 네트워크 불필요 한국어 음성만 선택. 마이크 녹음 없음 |
| 문의 메일 | mailto 링크 → 선택 이메일 앱 → Gmail | 사용자가 보내는 이메일/표시 이름/본문/첨부 처리. 외부 이메일 기능의 신고 범위·Google 예외를 확인. 공개 정책에는 별도 고지. 앱의 자동 이메일 수집이라고 쓰지 않음 |

## Play Console 공통 문항 초안

- 데이터 수집·공유 여부: **최종 선택 보류**. 온라인 지도/서버/SDK 흐름을 이유로 “아니요”로 확정하지 않음.
- 광고: 현재 앱에 광고 SDK·배너·제휴 광고 없음. 현 빌드 기준 “광고 없음” 후보. 향후 수익 기능을 넣으면 갱신.
- 계정 생성: 없음. 앱 계정 삭제 URL 요건의 적용 대상 여부는 계정 생성이 없는 현 빌드 기준으로 답변. 기기 데이터 삭제 안내는 /support 제공.
- 전송 중 암호화: 직접 제어하는 API/타일/원문 URL은 HTTPS. **포함 SDK 모든 트래픽 검증 전 전체 Yes 확정 금지**.
- 삭제 요청: 기기 자료는 앱 내 삭제/Android 데이터 삭제, 운영자 문의 정보는 공개 이메일로 삭제 요청. 계정 삭제와 구분.
- 선택 여부: GPS·지역 제안·사진·공유는 사용자 선택. 지도 화면 로딩 시 SDK 자체 요청은 GPS 권한과 독립적일 수 있음.
- 처리 목적: 앱 기능, 온라인 서비스 보안/장애 대응 후보. 광고·판매·맞춤광고·개발자 분석은 구현하지 않았음. 제공자 자체 목적은 별도 확인.
- 일시 처리(ephemeral): 메모리에서 잠깐 썼다는 이유로 CDN/SDK 로그까지 일시 처리라고 신고하지 않음. provider retention 확인 전 보류.
- 제3자 공유: 단순 외부 통신과 Play의 sharing 정의는 동일하지 않음. 서비스 제공자 예외는 계약/조건으로 확인해야 하며 임의 확정하지 않음.

## 제출 전 남은 증거

1. 최종 카카오 지도 SDK/native 버전의 개인정보·Play Data safety 문서 또는 제공자 답변 확보. 자동 전송 항목, 목적, 필수/선택, 보관, 공유/처리자 관계 확인.
2. 최종 서명 AAB 설치본에서 지도·지역 제안·사진·공유·알림 경로 검증. 트래픽 검증이 필요해도 TLS/보안 제한을 해제하지 않음.
3. Cloudflare 계약/로그 설정 및 Google·지도 서비스 처리 조건에 맞춘 위탁·국외 처리 고지의 상세 검토. 현 공개 정책은 알려진 흐름을 안내하며 법적 적합성 인증이 아님.
4. safeKor 운영자가 문의 종료 후 90일 내 수동 삭제 운영과 요청 대응을 수행. 앱 계정 DB 없음과 문의 이메일 보관은 별개.
5. Play 개발자 표시명과 운영자 표기 일치, 앱 ID·최종 서명·정책 URL·스토어 문구·앱 내부 링크 대조.

## 공식 근거 (2026-11-01 확인)

- https://support.google.com/googleplay/android-developer/answer/10787469 — 수집/공유, 기기 내 처리, 임시 처리, IP·SDK 설명
- https://support.google.com/googleplay/android-developer/answer/10144311 — 공개 개인정보처리방침 및 앱 내부 안내
- https://apis.map.kakao.com/android_v2/docs/ — 지도 SDK. 본 페이지에서 세부 Data safety 표는 확인하지 못함
- https://privacy.kakao.com/policy?lang=ko — 일반 제공자 정책, 지도 SDK 항목을 확정하는 자료는 아님
- https://www.cloudflare.com/privacypolicy/ — IP/네트워크 요청 처리, 로그·제공자 처리
- https://osmfoundation.org/wiki/Privacy_Policy — 타일 서비스의 IP·기기·요청 정보

공개 정책 원본: workers/shelters/public/privacy.html. 문의 원본: workers/shelters/public/support.html.
