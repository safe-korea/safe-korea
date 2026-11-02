# 조회 지역 판별용 경계 자료

출처: 국가공간정보포털(V-World), KnellBalm/kr-admin-geojson.
https://github.com/KnellBalm/kr-admin-geojson
고정 커밋: 3a859f2a45be8acf8237d9eefd9565f99cc603da
원본 sig.geojson SHA-256: 76b2c60ded464e7adeaab36e69b9032ed868845374d53d98186ac22483195b8e

저장소 설명 기준 원천 경계는 2023-07-29 배포이며, WGS84 재투영·0.0005도 단순화·소수점 6자리 좌표입니다. 제공자가 출처 표시 조건으로 이용을 허용한 자료입니다. 원문 README의 출처와 허용 조건: https://github.com/KnellBalm/kr-admin-geojson/blob/main/README.md

앱에서는 속성 축소·경계 상자 계산만 수행하고 좌표를 추가 단순화하지 않았습니다. 지도 표시나 시설 검증 자료가 아닌 조회 지역 선택 보조 자료입니다. 기기에서만 점 포함 검사를 하며 GPS를 전송하지 않습니다. 코드와 시군구명이 현재 조회 지역 목록과 일치하는 경우만 적용하고, GPS 오차+100m 이내에서 판별이 달라지거나 자료가 없는 경우 수동 선택으로 돌아갑니다. 전국 최신 행정경계/가장 가까운 시설의 완전성을 보장하지 않습니다. 인접 시군구는 자동 조회하지 않습니다.
