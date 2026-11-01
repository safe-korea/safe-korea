# SAFE KOREA 브랜드 시안 v1

결정 제안: 기존 초록·흰색 대피 공간 심볼을 앱 아이콘으로 유지하고, 평상시 준비를 돕는 진돗개 캐릭터를 온보딩·준비물·홍보 화면에 제한적으로 사용합니다. 빨강은 긴급 행동 UI에 남겨 둡니다. 캐릭터가 긴급 버튼·경보 종류·출처 설명을 대신하지 않습니다.

- icon-shelter-v1.svg / icon-play-512.png: 기존 web/icon.svg의 집 모티브를 잇는 코드 기반 벡터 시안. 공식 민방위 표지·정부 인증 표시가 아님. 512px PNG는 Google Play 아이콘용 후보, 기존 Android launcher 파일은 교체하지 않음.
- mascot-jindo-v1.png: 내장 image_gen 도구로 생성한 진돗개 캐릭터 시안. 이름·상표는 미확정. 온보딩에 도입할 경우 장식 이미지로 접근성을 처리하고 긴급 화면에는 넣지 않음. 현재 앱에 자동 적용하지 않음.
- feature-graphic-1024x500.png: 실제 제공 기능을 설명하는 스토어 배너 후보. 앱 UI 스크린샷은 별도 실제 Android 캡처로 제공하며 AI로 앱 화면을 만들지 않음.

## 생성 프롬프트와 방식

내장 image_gen 사용(외부 CLI/API 키 사용 없음). 최종 캐릭터 생성 프롬프트:

> Use case: logo-brand. Asset type: proposed SAFE KOREA mobile app mascot for onboarding and everyday emergency preparation, not emergency alert screens. Create one original full-body friendly white Korean Jindo dog character, quietly confident and helpful, mature universal appeal rather than babyish. Rounded upright silhouette, two upright ears, tiny dark forest-green eyes and nose, restrained kind smile, a simple forest green (#086B50) everyday preparedness vest and small backpack, one paw gently pointing to the side. A tiny plain ivory house-shaped emblem on the vest echoes the app shelter icon. Contemporary premium flat editorial illustration, clean broad shapes, restrained two-tone shading, ivory white and forest green with a small warm ochre accent. Centered isolated figure, generously padded edges, genuinely transparent background. No text, no badges of official authority, no government insignia, no red cross, no siren, no military equipment, no dramatic action, no surrounding objects, no ground plane or mockup. This is a design proposal, no implication of official endorsement.

실제 생성 결과는 프롬프트의 평면화 요청보다 입체감·질감이 있는 스타일입니다. UI 일관성을 위한 추가 변형과 이름/권리 검토는 최종 채택 시 수행합니다. 생성 PNG 원본을 복사해 보존했으며 후처리하지 않았습니다.
