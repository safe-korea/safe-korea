import test from "node:test";
import assert from "node:assert/strict";
import { DatabaseSync } from "node:sqlite";
import { readFileSync } from "node:fs";
import { pushRoute, pollGovernment } from "../src/push.ts";
import {
  appleEndpoint,
  encode64,
  sendApplePush,
  digest,
} from "../src/web_push.ts";
import {
  civilKind,
  koreanTimestamp,
  normalizeOfficial,
  regionMatches,
  fetchOfficial,
} from "../src/official_alerts.ts";

function database() {
  const sql = new DatabaseSync(":memory:");
  sql.exec(
    readFileSync(
      new URL("../migrations/0001_push.sql", import.meta.url),
      "utf8",
    ),
  );
  const prepare = (query, values = []) => ({
    bind(...args) {
      return prepare(query, args);
    },
    async first() {
      return sql.prepare(query).get(...values) || null;
    },
    async all() {
      return { results: sql.prepare(query).all(...values) };
    },
    async run() {
      return {
        results: [],
        meta: { changes: Number(sql.prepare(query).run(...values).changes) },
      };
    },
  });
  return {
    prepare,
    batch: (queries) => Promise.all(queries.map((q) => q.run())),
    sql,
  };
}
async function keys() {
  const kp = await crypto.subtle.generateKey(
    { name: "ECDSA", namedCurve: "P-256" },
    true,
    ["sign", "verify"],
  );
  const jwk = await crypto.subtle.exportKey("jwk", kp.privateKey);
  const pub = encode64(
    new Uint8Array(await crypto.subtle.exportKey("raw", kp.publicKey)),
  );
  return {
    privateKey: jwk.d,
    publicKey: pub,
    subject: "mailto:test@example.test",
  };
}
async function subscription() {
  const kp = await crypto.subtle.generateKey(
    { name: "ECDH", namedCurve: "P-256" },
    true,
    ["deriveBits"],
  );
  return {
    kp,
    subscription: {
      endpoint: "https://web.push.apple.com/QA-synthetic-endpoint",
      expirationTime: null,
      keys: {
        p256dh: encode64(
          new Uint8Array(await crypto.subtle.exportKey("raw", kp.publicKey)),
        ),
        auth: encode64(crypto.getRandomValues(new Uint8Array(16))),
      },
    },
  };
}
const origin = "https://safe.example";
function req(path, body, customOrigin = origin) {
  return new Request(origin + "/api/push/" + path, {
    method: body ? "POST" : "GET",
    headers: { Origin: customOrigin, "Content-Type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
}
const capability = "a".repeat(43);
async function fixture() {
  const vapid = await keys(),
    { subscription: sub, kp } = await subscription();
  return {
    kp,
    sub,
    env: {
      PUSH_DB: database(),
      PUSH_REQUEST_LIMIT: { limit: async () => ({ success: true }) },
      VAPID_PUBLIC_KEY: vapid.publicKey,
      VAPID_PRIVATE_KEY: vapid.privateKey,
    },
    body: {
      capability,
      region: "11710",
      consentVersion: "2026-11-02",
      subscription: sub,
    },
  };
}

test("endpoint allowlist rejects FCM, SSRF, credentials, ports and lookalikes", () => {
  assert(appleEndpoint("https://web.push.apple.com/opaque"));
  for (const u of [
    "https://fcm.googleapis.com/send/a",
    "http://web.push.apple.com/a",
    "https://web.push.apple.com.evil.test/a",
    "https://evilpush.apple.com/a",
    "https://user@web.push.apple.com/a",
    "https://127.0.0.1/a",
    "https://web.push.apple.com:444/a",
    "https://web.push.apple.com/a#fragment",
  ])
    assert.equal(appleEndpoint(u), false, u);
});
test("register requires consent, region, valid crypto, origin and ownership; cannot replace another device", async () => {
  const f = await fixture();
  assert.equal(
    (await pushRoute(req("subscribe", f.body, "https://evil.test"), f.env))
      .status,
    403,
  );
  assert.equal(
    (
      await pushRoute(
        req("subscribe", { ...f.body, consentVersion: null }),
        f.env,
      )
    ).status,
    400,
  );
  assert.equal(
    (await pushRoute(req("subscribe", { ...f.body, region: "unknown" }), f.env))
      .status,
    400,
  );
  assert.equal(
    (
      await pushRoute(
        req("subscribe", {
          ...f.body,
          subscription: {
            ...f.sub,
            endpoint: "https://fcm.googleapis.com/send/a",
          },
        }),
        f.env,
      )
    ).status,
    400,
  );
  const r = await pushRoute(req("subscribe", f.body), f.env);
  assert.equal(r.status, 201);
  const result = await r.json();
  assert.equal(result.officialEnabled, false);
  assert.equal(result.transportReady, true);
  assert.equal(
    (
      await pushRoute(
        req("subscribe", { ...f.body, capability: "b".repeat(43) }),
        f.env,
      )
    ).status,
    409,
  );
  const own = { id: result.id, capability };
  assert.equal(
    (
      await pushRoute(
        req("status", { ...own, capability: "b".repeat(43) }),
        f.env,
      )
    ).status,
    403,
  );
  assert.equal((await pushRoute(req("unsubscribe", own), f.env)).status, 200);
  assert.equal((await pushRoute(req("status", own), f.env)).status, 403);
  assert.equal(
    f.env.PUSH_DB.sql.prepare("SELECT count(*) n FROM push_subscriptions").get()
      .n,
    0,
  );
});
test("test push is encrypted, short-lived, bound to one device and receipt distinguishes accepted/received/opened", async () => {
  const f = await fixture(),
    now = Date.now();
  const created = await (
      await pushRoute(req("subscribe", f.body), f.env)
    ).json(),
    own = { id: created.id, capability };
  let envelope,
    called = 0;
  const upstream = async (url, options) => {
    called++;
    assert.equal(url, f.sub.endpoint);
    assert.equal(options.redirect, "manual");
    assert.equal(options.headers["content-encoding"], "aes128gcm");
    assert.equal(options.headers.ttl, "120");
    assert.equal(options.body.length, 4096);
    assert(!Buffer.from(options.body).includes(Buffer.from("safeKor")));
    envelope = options;
    return new Response(null, { status: 201 });
  };
  const response = await pushRoute(req("test", own), f.env, {
    now: () => now,
    upstream,
  });
  assert.equal(response.status, 202);
  const result = await response.json();
  assert.equal(result.received, false);
  assert.equal(called, 1);
  const row = f.env.PUSH_DB.sql.prepare("SELECT * FROM push_deliveries").get();
  assert.equal(row.type, "test");
  assert.equal(row.state, "accepted");
  assert.equal(row.received_at, null);
  assert.equal(row.expires_at, now + 120000);
  assert.equal(
    (
      await pushRoute(req("test", own), f.env, {
        now: () => now + 1000,
        upstream,
      })
    ).status,
    429,
  );
  assert.equal(called, 1);
  // Decrypt exactly as the subscribing browser, proving this is RFC8291 payload encryption.
  const wire = envelope.body,
    salt = wire.slice(0, 16),
    server = wire.slice(21, 86),
    cipher = wire.slice(86);
  const publicKey = await crypto.subtle.importKey(
    "raw",
    server,
    { name: "ECDH", namedCurve: "P-256" },
    false,
    [],
  );
  const shared = await crypto.subtle.deriveBits(
    { name: "ECDH", public: publicKey },
    f.kp.privateKey,
    256,
  );
  const hkdf = async (ikm, salt, info, size) =>
    crypto.subtle.deriveBits(
      { name: "HKDF", hash: "SHA-256", salt, info },
      await crypto.subtle.importKey("raw", ikm, "HKDF", false, ["deriveBits"]),
      size * 8,
    );
  const b64 = (s) => new Uint8Array(Buffer.from(s, "base64url"));
  const info = Buffer.concat([
    Buffer.from("WebPush: info\0"),
    Buffer.from(b64(f.sub.keys.p256dh)),
    Buffer.from(server),
  ]);
  const ikm = await hkdf(shared, b64(f.sub.keys.auth), info, 32),
    cek = await hkdf(
      ikm,
      salt,
      Buffer.from("Content-Encoding: aes128gcm\0"),
      16,
    ),
    nonce = await hkdf(ikm, salt, Buffer.from("Content-Encoding: nonce\0"), 12);
  const plain = new Uint8Array(
    await crypto.subtle.decrypt(
      { name: "AES-GCM", iv: nonce },
      await crypto.subtle.importKey("raw", cek, "AES-GCM", false, ["decrypt"]),
      cipher,
    ),
  );
  let end = plain.length - 1;
  while (plain[end] === 0) end--;
  assert.equal(plain[end], 2);
  const data = JSON.parse(new TextDecoder().decode(plain.slice(0, end)));
  assert.equal(data.type, "test");
  assert.match(data.body, /실제 경보가 아닙니다/);
  const receipt = await pushRoute(
    req("receipt", {
      deliveryId: result.deliveryId,
      receiptToken: data.receiptToken,
    }),
    f.env,
    { now: () => now + 1000 },
  );
  assert.equal((await receipt.json()).received, true);
  const opened = await pushRoute(
    req("notice", { ...own, deliveryId: result.deliveryId }),
    f.env,
    { now: () => now + 2000 },
  );
  assert.equal((await opened.json()).type, "test");
  const status = await (
    await pushRoute(req("status", own), f.env, { now: () => now + 3000 })
  ).json();
  assert(status.lastTest.received_at);
  assert(status.lastTest.opened_at);
  assert.equal(
    (
      await pushRoute(
        req("notice", { ...own, deliveryId: result.deliveryId }),
        f.env,
        { now: () => now + 120001 },
      )
    ).status,
    410,
  );
});
test("410 removes expired subscriptions, and unsigned third-party posts cannot send", async () => {
  const f = await fixture();
  const r = await (await pushRoute(req("subscribe", f.body), f.env)).json();
  let calls = 0;
  const deps = {
    upstream: async () => {
      calls++;
      return new Response(null, { status: 410 });
    },
  };
  assert.equal(
    (
      await pushRoute(
        req("test", { id: r.id, capability }, "https://other.test"),
        f.env,
        deps,
      )
    ).status,
    403,
  );
  assert.equal(calls, 0);
  assert.equal(
    (await pushRoute(req("test", { id: r.id, capability }), f.env, deps))
      .status,
    502,
  );
  assert.equal(calls, 1);
  assert.equal(
    f.env.PUSH_DB.sql.prepare("SELECT count(*) n FROM push_subscriptions").get()
      .n,
    0,
  );
});
test("strict civil-defense parsing excludes training, future context, releases and weather", () => {
  assert.equal(civilKind("서울 공습경보 발령합니다."), "air");
  assert.equal(civilKind("화학공격경보 발령되었습니다"), "chemical");
  for (const t of [
    "훈련 공습경보 발령합니다",
    "공습경보 발령시 대피",
    "공습경보 발령 예정",
    "공습경보 발령되었습니다. 오발령",
    "공습경보 해제",
    "경계경보 공습경보 발령합니다",
    "태풍 경보 발령합니다",
  ])
    assert.equal(civilKind(t), null, t);
  assert.equal(
    koreanTimestamp("2026-11-02 21:30:00"),
    Date.UTC(2026, 10, 2, 12, 30),
  );
  assert.equal(koreanTimestamp("2026-02-30 21:30:00"), null);
  assert(regionMatches("11710", ["11"]));
  assert(!regionMatches("11", ["11710"]));
  assert(!regionMatches("26110", ["11"]));
});
test("official adapter is gated, fresh, exact-region and independent from numeric disaster ID guesses", async () => {
  const now = Date.UTC(2026, 10, 2, 12, 30),
    row = {
      SN: 1,
      CRT_DT: "2026-11-02 21:30:00",
      MSG_CN: "공습경보 발령합니다.",
      RCPTN_RGN_ID: "11710",
      RCPTN_RGN_NM: "서울특별시 송파구",
      DST_SE_NM: "민방공",
      EMRG_STEP_NM: "위급재난",
      MDFCN_YMD: "20261102",
    };
  assert.equal(await normalizeOfficial(row, now, false), null);
  assert.equal((await normalizeOfficial(row, now, true)).kind, "air");
  assert.equal(
    await normalizeOfficial(
      { ...row, RCPTN_RGN_NM: "확인되지 않은 지역" },
      now,
      true,
    ),
    null,
  );
  assert.equal(
    await normalizeOfficial(
      { ...row, MSG_CN: "훈련 공습경보 발령합니다." },
      now,
      true,
    ),
    null,
  );
  assert.equal(await normalizeOfficial(row, now + 120001, true), null);
  assert.equal(
    await normalizeOfficial({ ...row, DST_SE_NM: "태풍" }, now, true),
    null,
  );
});
test("source reads are bounded, do not redirect, and incomplete scans never enable dispatch", async () => {
  const now = Date.now();
  let request;
  const result = await fetchOfficial(
    "synthetic-test-key",
    now,
    async (url, options) => {
      request = url;
      assert.equal(options.redirect, "manual");
      return Response.json({
        header: { resultCode: "00" },
        totalCount: 101,
        body: [{ SN: 1 }],
      });
    },
  );
  assert.equal(request.hostname, "www.safetydata.go.kr");
  assert.equal(request.searchParams.get("numOfRows"), "100");
  assert.equal(result.complete, false);
  assert.equal(
    (
      await fetchOfficial(
        "synthetic",
        now,
        async () => new Response("<returnReasonCode>32</returnReasonCode>"),
      )
    ).state,
    "source_ip_denied",
  );
  const f = await fixture();
  await pollGovernment(f.env, { now: () => now });
  assert.match(
    f.env.PUSH_DB.sql
      .prepare("SELECT value FROM alert_runtime WHERE name='source_status'")
      .get().value,
    /key_required/,
  );
  let sends = 0;
  f.env.GOV_ALERT_API_KEY = "synthetic";
  f.env.GOV_ALERT_SEMANTICS_VERIFIED = "false";
  await pollGovernment(f.env, {
    now: () => now + 120000,
    upstream: async () => {
      sends++;
      return Response.json({ totalCount: 0, body: [] });
    },
  });
  assert.equal(sends, 1);
  assert.equal(
    f.env.PUSH_DB.sql.prepare("SELECT count(*) n FROM push_deliveries").get().n,
    0,
  );
});

test("verified complete source targets the selected region once; repeated snapshot cannot send again", async () => {
  const f = await fixture(),
    now = Date.now();
  await pushRoute(req("subscribe", f.body), f.env, { now: () => now });
  f.env.GOV_ALERT_API_KEY = "synthetic";
  f.env.GOV_ALERT_SEMANTICS_VERIFIED = "true";
  const stamp = new Date(now + 9 * 3600000)
    .toISOString()
    .slice(0, 19)
    .replace("T", " ");
  const row = {
    SN: 123,
    CRT_DT: stamp,
    MDFCN_YMD: "synthetic-revision",
    MSG_CN: "공습경보 발령합니다. 대피하세요.",
    RCPTN_RGN_ID: "11710",
    RCPTN_RGN_NM: "서울특별시 송파구",
    DST_SE_NM: "민방공",
    EMRG_STEP_NM: "위급재난",
  };
  let sourceReads = 0,
    pushes = 0;
  const upstream = async (url, options) => {
    if (new URL(url).hostname === "www.safetydata.go.kr") {
      sourceReads++;
      return Response.json({ totalCount: 1, body: [row] });
    }
    pushes++;
    assert.equal(options.headers["content-encoding"], "aes128gcm");
    return new Response(null, { status: 201 });
  };
  await pollGovernment(f.env, { now: () => now, upstream });
  assert.equal(sourceReads, 1);
  assert.equal(pushes, 1);
  await pollGovernment(f.env, { now: () => now + 100000, upstream });
  assert.equal(sourceReads, 2);
  assert.equal(pushes, 1);
  const delivery = f.env.PUSH_DB.sql
    .prepare("SELECT payload,type FROM push_deliveries")
    .get();
  assert.equal(delivery.type, "civil");
  assert.equal(JSON.parse(delivery.payload).kind, "air");
  assert(!delivery.payload.includes("MSG_CN"));
});
test("source daily budget and declared or streamed oversize stop before delivery", async () => {
  const now = Date.now();
  assert.equal(
    (
      await fetchOfficial(
        "synthetic",
        now,
        async () =>
          new Response("x", { headers: { "Content-Length": "3000000" } }),
      )
    ).state,
    "source_unavailable",
  );
  assert.equal(
    (
      await fetchOfficial(
        "synthetic",
        now,
        async () => new Response("x".repeat(2 * 1024 * 1024 + 1)),
      )
    ).state,
    "source_unavailable",
  );
  const f = await fixture();
  f.env.GOV_ALERT_API_KEY = "synthetic";
  let reads = 0;
  const date = new Date(now + 9 * 3600000).toISOString().slice(0, 10);
  f.env.PUSH_DB.sql
    .prepare("INSERT INTO alert_runtime (name,value) VALUES (?,?)")
    .run("budget/" + date, "900");
  await pollGovernment(f.env, {
    now: () => now,
    upstream: async () => {
      reads++;
      throw Error("must not call");
    },
  });
  assert.equal(reads, 0);
  assert.match(
    f.env.PUSH_DB.sql
      .prepare("SELECT value FROM alert_runtime WHERE name='source_status'")
      .get().value,
    /daily_budget/,
  );
});

test("recipient internal IDs never masquerade as shelter codes; exact trimmed names are resolved", async () => {
  const now = Date.UTC(2026, 10, 2, 12, 30),
    row = {
      SN: 1,
      CRT_DT: "2026/11/02 21:30:00",
      MSG_CN: "공습경보 발령합니다.",
      RCPTN_RGN_ID: "142",
      RCPTN_RGN_NM: "서울특별시 송파구  ",
      DST_SE_NM: "민방공",
      EMRG_STEP_NM: "위급재난",
    };
  assert.deepEqual((await normalizeOfficial(row, now, true)).regions, [
    "11710",
  ]);
  assert.equal(
    await normalizeOfficial(
      { ...row, RCPTN_RGN_NM: "서울특별시 송파구 잠실동" },
      now,
      true,
    ),
    null,
  );
  assert.equal(
    await normalizeOfficial({ ...row, RCPTN_RGN_ID: " " }, now, true),
    null,
  );
  assert.deepEqual(
    (await normalizeOfficial({ ...row, RCPTN_RGN_NM: "전국" }, now, true))
      .regions,
    ["nationwide"],
  );
});

test("JSON gateway IP denial is classified without exposing key or upstream text", async () => {
  const result = await fetchOfficial("synthetic-key", Date.now(), async () =>
    Response.json({ header: { resultCode: "32", resultMsg: "not logged" } }),
  );
  assert.equal(result.state, "source_ip_denied");
  assert.equal(result.gatewayCode, "32");
  assert.deepEqual(result.rows, []);
});

test("persistent IP rejection backs off instead of retrying the same failure each cron", async () => {
  const f = await fixture(),
    now = Date.now();
  f.env.GOV_ALERT_API_KEY = "synthetic";
  let calls = 0;
  f.env.PUSH_DB.sql
    .prepare("INSERT INTO alert_runtime(name,value) VALUES (?,?)")
    .run(
      "source_status",
      JSON.stringify({ state: "source_ip_denied", checkedAt: now }),
    );
  const upstream = async () => {
    calls++;
    return Response.json({ totalCount: 0, body: [] });
  };
  await pollGovernment(f.env, { now: () => now + 120000, upstream });
  assert.equal(calls, 0);
  await pollGovernment(f.env, { now: () => now + 6 * 3600000 + 1, upstream });
  assert.equal(calls, 1);
});
