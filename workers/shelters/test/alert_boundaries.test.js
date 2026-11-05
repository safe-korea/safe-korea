import test from "node:test";
import assert from "node:assert/strict";
import {
  civilKind,
  normalizeOfficial,
  regionMatches,
  fetchOfficial,
} from "../src/official_alerts.ts";

const cases = [
  ["합성 공습 발령", "서울지역 공습경보를 발령합니다.", "air"],
  ["합성 경계 발령", "인천지역에 경계경보를 발령하였습니다.", "watch"],
  ["합성 화생방 발령", "화생방 경보를 발령합니다.", "cbrn"],
  ["합성 화학 발령", "화학 공격 경보를 발령합니다.", "chemical"],
  ["합성 생물학 발령", "생물학 공격 경보를 발령합니다.", "biological"],
  ["합성 핵 발령", "핵 경보를 발령합니다.", "nuclear"],
  ["훈련", "공습경보를 발령합니다. 민방위 훈련입니다.", null],
  ["예고", "공습경보 발령 예정입니다.", null],
  ["일반 상황 설명", "공습경보 발령 시 계단으로 대피하세요.", null],
  ["표준 문안 인용", "표준 문안: 공습경보를 발령합니다.", null],
  ["부정 문맥", "공습경보 발령되었습니다 라는 문자는 사실이 아닙니다.", null],
  ["부정 짧은 표현", "공습경보 발령합니다 라는 문자는 사실 아님.", null],
  ["정정", "공습경보 발령합니다. 정정 안내입니다.", null],
  ["해제", "공습경보를 해제합니다.", null],
  ["오발령", "공습경보 발령합니다. 오발령입니다.", null],
  ["날씨", "태풍 경계경보를 발령합니다.", null],
  ["두 종류 혼재", "경계경보 및 공습경보를 발령합니다.", null],
];
for (const [name, body, expected] of cases)
  test("synthetic classification: " + name, () =>
    assert.equal(civilKind(body), expected),
  );

test("province opt-in covers its districts while district opt-in remains local", () => {
  assert(regionMatches("11", ["11710"]));
  assert(regionMatches("11", ["11"]));
  assert(regionMatches("11710", ["11"]));
  assert(regionMatches("11710", ["11710"]));
  assert(regionMatches("11", ["nationwide"]));
  assert(regionMatches("11710", ["nationwide"]));
  assert(!regionMatches("11", ["28"]));
  assert(!regionMatches("11", ["28110"]));
  assert(!regionMatches("11710", ["11110"]));
  assert(!regionMatches("28", ["11710"]));
});
test("near KST midnight, direct source also keeps the previous day inside freshness window", async () => {
  const now = Date.UTC(2026, 10, 2, 15, 0, 30);
  const result = await fetchOfficial("synthetic", now, async (url) => {
    assert.equal(url.searchParams.get("crtDt"), "20261102");
    return Response.json({ totalCount: 0, body: [] });
  });
  assert(result.complete);
});
test("freshness, timezone, exact regions and hold gate keep ambiguous inputs out", async () => {
  const now = Date.UTC(2026, 10, 2, 15, 0, 30);
  const row = {
    SN: 1,
    CRT_DT: "2026/11/03 00:00:00",
    MDFCN_YMD: "synthetic",
    MSG_CN: "공습경보를 발령합니다.",
    RCPTN_RGN_ID: "internal",
    RCPTN_RGN_NM: "서울특별시 송파구",
    DST_SE_NM: "민방공",
    EMRG_STEP_NM: "위급재난",
  };
  assert.equal((await normalizeOfficial(row, now, true))?.kind, "air");
  for (const change of [
    { RCPTN_RGN_NM: "서울특별시 송파구 잠실동" },
    { RCPTN_RGN_NM: "서울특별시 송파구,알 수 없는 지역" },
    { RCPTN_RGN_ID: "" },
    { DST_SE_NM: "기타" },
    { EMRG_STEP_NM: "안전안내" },
    { CRT_DT: "2026/11/02 23:58:00" },
    { CRT_DT: "2026/11/03 00:01:01" },
  ])
    assert.equal(
      await normalizeOfficial({ ...row, ...change }, now, true),
      null,
    );
  assert.equal(await normalizeOfficial(row, now, false), null);
  assert(
    regionMatches("11", (await normalizeOfficial(row, now, true)).regions),
  );
});
