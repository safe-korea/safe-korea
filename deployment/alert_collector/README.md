# 정부 API 수집기

기존 Oracle Ubuntu 사용자 폴더에 배치하는 Python3 표준 라이브러리 프로그램입니다. HTTP 수신 포트·Flask·추가 VM·관리자 설정 없이 공식 API를 읽고 기존 Cloudflare Worker로 서명된 결과를 보냅니다. 서버 계정/주소/키를 이 저장소에 기록하지 않습니다.

## 실제 배치

사용자 승인 후 `~/.local/share/safekor-alert-collector/`(700)에 두 프로그램과 `gov-probe.local.json`(600)을 배치했습니다. 설정 필드는 serviceKey, collectorKey이며 앱이나 Git에 넣지 않습니다. collectorKey는 무작위32바이트의 base64url43자이며 Cloudflare의 COLLECTOR_HMAC_KEY Secret과 같습니다. 정부 API 키와 별개의 키입니다.

운영 Worker는 `GOV_ALERT_TRANSPORT=collector`, `GOV_ALERT_SEMANTICS_VERIFIED=false`입니다. POST /api/push/collector는 HMAC SHA256, 정확한 본문·시각,60초 유효 기간, 크기 상한, 단조 증가 스냅샷을 검사합니다. 이 서버 전용 경로만 브라우저 Origin 검사를 대신하며 일반 구독/테스트 경로의 Origin 검사는 유지됩니다. 키 교체는 두 서버를 함께 갱신해야 합니다.

2분마다 한 페이지100건을 읽습니다. 일일900회 상한/오류32·인증·할당량 오류6시간 대기를 SQLite에 기록합니다. 지난7일 이전 예산 기록은 정리합니다. 일반 재난/실종 내용은 버리고 민방공의 문서 필드11개만 전송합니다. 전체 건수 불일치·100건 초과·미해석 지역·오래된 경보·훈련은 발송하지 않습니다. 페이지 수집 확대와 대규모 발송은 아직 검증하지 않았습니다. Worker에서 최종 분류/발령/지역/중복을 다시 확인합니다.

## 허용 IP 등록 후 재검사

국민안전데이터포털 신청25864의 허용 IP를 기존 Oracle 공인 IP로 변경 완료했습니다. 포털은 단일 IPv4 형식만 허용하여 기존 개발 PC 주소 대신 운영 서버를 등록했습니다. 전체 IP 허용으로 바꾸지 않습니다. 서버 재생성으로 IP가 바뀌면 다시 등록해야 합니다.

등록 완료 후 서버의 비관리자 사용자로 실행합니다. 이 명령은 원천 오류 대기를 한 번 해제하며 실제 발송 게이트는 바꾸지 않습니다.

```sh
/usr/bin/python3 ~/.local/share/safekor-alert-collector/collector.py \
  --config ~/.local/share/safekor-alert-collector/gov-probe.local.json \
  --reset-backoff
```

source_observed, complete=true, snapshot_accepted=true와 공개 /api/push/config의 source.transport=signed_collector 및 최근 checkedAt를 확인합니다. 공개 source에는 키·원문·구독 정보가 없습니다. 2026-11-03 실제 원천 source_observed/complete=true와 서명 전송을 확인했고 전날 자료14건/전체14건/필드11개도 검증했습니다. 이것이 실제 정부 경보의 APNs 기기 전달 증거는 아닙니다. 실제 발송 활성화에는 원천 의미/이용 조건/지연과 본인 기기 알림 표시·열기 검증이 더 필요합니다.

## 일정·복구

install_cron.py는 현재 사용자 crontab의 SAFEKOR ALERT COLLECTOR 블록만 설치/교체하고 나머지 내용을 보존합니다. 처음 상태를 폴더의 crontab.before-safekor.txt에600으로 백업합니다. last-run.json은 마지막 고정 상태/건수만 기록하며 원문·키·예외 URL은 출력하지 않습니다. IP 오류 대기 중에는 source_backoff가 표시됩니다.

중단은 crontab -e로 BEGIN/END SAFEKOR ALERT COLLECTOR 사이 블록만 제거합니다. 다른 서비스 작업이 추가됐을 수 있으므로 전체 crontab을 오래된 백업으로 덮어쓰지 않습니다. 폴더나 설정 파일을 삭제할 필요는 없습니다. 같은 파일을 수정할 때 권한600을 유지하고 마지막 상태 시각을 점검하세요. 무료 VM 가용성이나 iPhone 배경 수신을 보장하는 구성은 아닙니다.
