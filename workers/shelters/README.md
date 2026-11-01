# SAFE KOREA 지역 시설 API

Cloudflare Workers용 읽기 전용 API. **2026-11-01 사용자 승인 후 실제 배포 완료**했습니다. 공개 주소: https://safe-korea-shelter-api.trovapp.workers.dev . 개인 DB, 로그인, 실제 경보 수신·발송은 없습니다. 공개 정부 웹사이트의 기존 비문서화 조회를 고정 호스트로 호출합니다. 비문서화 원천 자료의 이용·재배포 조건은 아직 확정하지 못했으며 정식 서비스 출시 점검에 남아 있습니다.

## 실행과 검증

저장소 루트에서 Node 22 이상 사용:

```sh
npm --prefix workers/shelters ci
npm --prefix workers/shelters test
npm --prefix workers/shelters run check
npm --prefix workers/shelters run build  # 로컬 bundle dry-run, 업로드 없음
npm --prefix workers/shelters run dev    # 127.0.0.1:8787
```

```sh
curl 'http://127.0.0.1:8787/api/shelters?region=11140'
./scripts/build_pwa.sh --dart-define=SHELTER_API_BASE_URL=http://127.0.0.1:8787
python3 -m http.server 8766 --bind 127.0.0.1 --directory build/web
```

로컬 Worker/PWA가 실행 중이면 `node scripts/test_worker_pwa.cjs`로 Chromium/WebKit의 실제 연결·오프라인 오류 표시를 검사할 수 있습니다(Playwright는 `.tools/pwa-qa` 개발 환경 필요).

브라우저 `http://127.0.0.1:8766`에서 행동요령 → 지역별 대피소 찾기. Android도 `--dart-define=SHELTER_API_BASE_URL=https://운영-API-도메인`으로 동일 API를 사용합니다. 공개 API URL은 `config/api.production.json`에 저장했습니다. `./scripts/build_pwa.sh --dart-define-from-file=config/api.production.json` 또는 `./scripts/run_app.sh DEVICE --dart-define-from-file=config/api.production.json`으로 사용합니다. 별도 설정 없는 빌드는 기존 동작을 유지하며 이미 설치한 앱은 자동으로 바뀌지 않습니다. 배포 빌드에 localhost를 사용하지 마세요.

## 계약과 장애 처리

- `GET /api/shelters?region=11140`: `assets/regions.json`에 있는 지역 코드 하나만 허용. 위도/경도·임의 URL·중복 파라미터는 400.
- 응답: `apiVersion:1`, 기존 `ShelterCatalog` 구조인 `catalog`, `delivery:{state,ageSeconds,stale}`. `state`는 `miss`, `hit`, `stale`.
- 출처·지역·전체 건수 검증, 국내 유효 좌표·고유 시설 ID 확인. 출입구 좌표가 제공되면 우선 사용. 잘못된 행은 제외 건수 공개; 같은 ID에 다른 정보가 있으면 전체 거부. 원본 갱신일은 제공되지 않아 `updatedAt:null`이며 조회 시각과 혼동하지 않습니다.
- 15분 이내 자료는 캐시 응답. 그 이후 요청에서 재조회, 실패하면 24시간 미만 캐시만 `stale:true`로 제공. 재조회 실패로 원래 조회 시각을 새로 쓰지 않습니다. 캐시가 없거나 만료되면 502/429/503. 클라이언트에는 `no-store`.
- `GET /health`는 실행 상태만 의미합니다. 원천 가용성/전국 데이터 완전성 보장이 아닙니다. `governmentAlertReception:false`.
- 원천 읽기 8초, 응답 스트림 2 MiB, 최대 5,000행. 리다이렉트를 수동 처리하고 3xx를 거부합니다. 쿠키/인증/클라이언트 헤더를 전달하지 않습니다.
- 원천 재조회에만 지역당 1회/분, 전체 20회/분 rate binding 적용. **Cloudflare 위치별 근사 제한이며 전 세계 합산 제한이 아닙니다.** 캐시 응답에는 적용하지 않습니다. 제한 시 429와 Retry-After:60, 또는 유효한 이전 자료 제공.
- 같은 isolate 내 동시 재조회 합침. Cache API는 위치별 임시 캐시로 영구 DB·전국 복제·백업이 아닙니다. 데이터센터/인스턴스 간 중복 조회는 가능하며 캐시 소실은 정상 조건입니다. 예약 수집 없음.

## 배포 상태와 정식 출시 전에 남은 작업

1. 정부 자료 이용·재배포·요청량 조건 확인, 필요 시 문서화된 공식 API로 교체.
2. 사용자 배포 승인 완료. `wrangler.production.jsonc`의 `workers_dev:true`로 기본 도메인 배포, preview URL/observability는 끔. 개발 설정은 그대로 보존. 배포 명령: `WRANGLER_SEND_METRICS=false workers/shelters/node_modules/.bin/wrangler deploy --config workers/shelters/wrangler.production.jsonc`. 현재 버전 `f878347c-ddd7-4c94-bfa7-0f2e599effe8`.
3. PWA 사이트는 아직 미배포입니다. 현재는 로컬 브라우저 검증을 위한 정확한 localhost origin 4개만 허용하며 와일드카드는 없습니다. PWA 사이트 배포 시 실제 origin을 등록하고 localhost 제거 여부를 결정합니다. HTTPS 운영 API 주소로 앱 재빌드. CORS는 인증이 아니며 네이티브/Origin 없는 요청은 허용합니다.
4. 기존 Worker 2개의 rate binding과 ID 충돌 없음 확인. 배포 시 Cloudflare API로 Free 플랜 확인. CPU 사용자 지정 한도는 무료 플랜에서 지원하지 않아 제거했고 무료 플랜 기본 제한을 사용합니다. 유료 플랜/결제 변경 없음.
5. 배포된 URL에서 health 200, 정부 자료 72곳과 cache hit, 잘못된 파라미터 400, 미허용 Origin 403 확인. 대규모 CPU/메모리/무료 요청량·다중 리전 부하/장애 복구 검증은 남음. 로컬 성공은 무료 플랜 CPU 한도나 운영 SLA 보장이 아닙니다.
6. 운영자/문의처/개인정보 안내와 롤백 버전 마련. Cloudflare는 IP와 요청 메타데이터를 처리합니다. 앱은 자체 사용자/위치 로그를 만들지 않으며 Workers observability는 꺼져 있습니다. 플랫폼 전체 로그 보관 정책까지 없다는 의미는 아닙니다.

PWA 파일 호스팅과 이 API는 별개입니다. 이 패키지는 PWA 사이트를 호스팅하지 않습니다. 사용자 가족 정보·사진·GPS 저장용 D1/R2/KV를 만들지 않습니다.

근거: [Cache API](https://developers.cloudflare.com/workers/runtime-apis/cache/), [rate binding](https://developers.cloudflare.com/workers/runtime-apis/bindings/rate-limit/), [Wrangler 설정](https://developers.cloudflare.com/workers/wrangler/configuration/).
