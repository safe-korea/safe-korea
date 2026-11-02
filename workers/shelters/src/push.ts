import { readCollectorSnapshot, CollectorError } from "./collector.ts";
import { type PushSubscription } from "@block65/webcrypto-web-push";
import {
  digest,
  sendApplePush,
  token,
  validateSubscription,
  type Vapid,
} from "./web_push.ts";
import {
  fetchOfficial,
  normalizeOfficial,
  regionMatches,
  regionNames,
  type Notice,
} from "./official_alerts.ts";

type Result<T> = { results: T[]; meta?: { changes?: number } };
interface Statement {
  bind(...args: unknown[]): Statement;
  first<T>(): Promise<T | null>;
  all<T>(): Promise<Result<T>>;
  run(): Promise<Result<unknown>>;
}
export interface Database {
  prepare(sql: string): Statement;
  batch(queries: Statement[]): Promise<Result<unknown>[]>;
}
export type PushEnv = {
  PUSH_DB?: Database;
  PUSH_REQUEST_LIMIT?: {
    limit: (input: { key: string }) => Promise<{ success: boolean }>;
  };
  VAPID_PUBLIC_KEY?: string;
  VAPID_PRIVATE_KEY?: string;
  GOV_ALERT_API_KEY?: string;
  GOV_ALERT_SEMANTICS_VERIFIED?: string;
  GOV_ALERT_TRANSPORT?: string;
  COLLECTOR_HMAC_KEY?: string;
};
type Sub = {
  id: string;
  secret_hash: string;
  endpoint: string;
  p256dh: string;
  auth: string;
  region: string;
  expires_at: number;
  last_test_at: number;
};
type Delivery = {
  id: string;
  subscription_id: string;
  type: string;
  payload: string;
  expires_at: number;
  receipt_hash: string;
  state: string;
  received_at: number | null;
  opened_at: number | null;
};
export type PushDeps = { now?: () => number; upstream?: typeof fetch };
// Keep an explicitly enabled registration until opt-out/provider expiry.
const ACTIVE_UNTIL = 8640000000000000;
class PushError extends Error {
  status: number;
  code: string;
  constructor(status: number, code: string) {
    super(code);
    this.status = status;
    this.code = code;
  }
}
function json(value: unknown, status = 200): Response {
  return Response.json(value, {
    status,
    headers: {
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
      "Referrer-Policy": "no-referrer",
    },
  });
}
function db(env: PushEnv): Database {
  if (!env.PUSH_DB) throw new PushError(503, "setup_required");
  return env.PUSH_DB;
}
async function vapid(env: PushEnv): Promise<Vapid> {
  if (env.VAPID_PUBLIC_KEY && env.VAPID_PRIVATE_KEY)
    return {
      publicKey: env.VAPID_PUBLIC_KEY,
      privateKey: env.VAPID_PRIVATE_KEY,
      subject: "mailto:taetaeg@gmail.com",
    };
  const database = db(env);
  const existing = await database
    .prepare("SELECT value FROM alert_runtime WHERE name='vapid_key_v1'")
    .first<{ value: string }>();
  if (existing) return JSON.parse(existing.value) as Vapid;
  // Generate the private key inside the Worker. It never passes through the
  // browser, repository or CLI, and the public config exposes only publicKey.
  const pair = await crypto.subtle.generateKey(
    { name: "ECDSA", namedCurve: "P-256" },
    true,
    ["sign", "verify"],
  );
  const privateJwk = await crypto.subtle.exportKey("jwk", pair.privateKey);
  const bytes = new Uint8Array(
    await crypto.subtle.exportKey("raw", pair.publicKey),
  );
  const publicKey = btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
  await database
    .prepare(
      "INSERT OR IGNORE INTO alert_runtime(name,value) VALUES ('vapid_key_v1',?)",
    )
    .bind(
      JSON.stringify({
        publicKey,
        privateKey: privateJwk.d,
        subject: "mailto:taetaeg@gmail.com",
      }),
    )
    .run();
  const winner = await database
    .prepare("SELECT value FROM alert_runtime WHERE name='vapid_key_v1'")
    .first<{ value: string }>();
  if (!winner) throw new PushError(503, "setup_required");
  return JSON.parse(winner.value) as Vapid;
}
async function input(request: Request): Promise<Record<string, unknown>> {
  if (
    !/^application\/json(?:;|$)/i.test(
      request.headers.get("content-type") || "",
    )
  )
    throw new PushError(415, "json_required");
  const reader = request.body?.getReader();
  if (!reader) throw new PushError(400, "invalid_input");
  const parts: Uint8Array[] = [];
  let size = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.length;
    if (size > 8192) {
      await reader.cancel();
      throw new PushError(413, "too_large");
    }
    parts.push(value);
  }
  const bytes = new Uint8Array(size);
  let at = 0;
  for (const p of parts) {
    bytes.set(p, at);
    at += p.length;
  }
  try {
    const obj = JSON.parse(
      new TextDecoder("utf-8", { fatal: true }).decode(bytes),
    );
    if (!obj || typeof obj !== "object" || Array.isArray(obj)) throw Error();
    return obj;
  } catch {
    throw new PushError(400, "invalid_input");
  }
}
function capability(value: unknown): value is string {
  return typeof value === "string" && /^[A-Za-z0-9_-]{43}$/.test(value);
}
async function owned(
  env: PushEnv,
  body: Record<string, unknown>,
  now: number,
): Promise<Sub> {
  if (
    typeof body.id !== "string" ||
    !/^[a-f0-9]{64}$/.test(body.id) ||
    !capability(body.capability)
  )
    throw new PushError(403, "registration_missing");
  const sub = await db(env)
    .prepare("SELECT * FROM push_subscriptions WHERE id=? AND expires_at>?")
    .bind(body.id, now)
    .first<Sub>();
  if (!sub || sub.secret_hash !== (await digest(body.capability)))
    throw new PushError(403, "registration_missing");
  return sub;
}
async function state(env: PushEnv): Promise<Record<string, unknown>> {
  const row = env.PUSH_DB
    ? await env.PUSH_DB.prepare(
        "SELECT value FROM alert_runtime WHERE name='source_status'",
      ).first<{ value: string }>()
    : null;
  let source: Record<string, unknown> = { state: "not_connected" };
  try {
    if (row) source = JSON.parse(row.value);
  } catch {}
  const keys = env.PUSH_DB ? await vapid(env) : null;
  return {
    protocolVersion: 1,
    transportReady: !!keys,
    publicKey: keys?.publicKey || null,
    officialEnabled:
      env.GOV_ALERT_SEMANTICS_VERIFIED === "true" &&
      (env.GOV_ALERT_TRANSPORT === "collector"
        ? !!env.COLLECTOR_HMAC_KEY
        : !!env.GOV_ALERT_API_KEY) &&
      source.complete === true &&
      typeof source.checkedAt === "number" &&
      Date.now() - source.checkedAt < 300000,
    source,
    regions: Array.from(regionNames, ([code, name]) => ({ code, name })),
    provider: "apple_web_push",
  };
}
async function deliver(
  env: PushEnv,
  sub: Sub,
  noticeId: string,
  type: "test" | "civil",
  data: Record<string, unknown>,
  now: number,
  deps: PushDeps,
): Promise<{ id: string; state: string }> {
  const id = crypto.randomUUID(),
    receipt = token(),
    expires = type === "test" ? now + 120000 : Number(data.expiresAt);
  const inserted = await db(env)
    .prepare(
      "INSERT OR IGNORE INTO push_deliveries (id,subscription_id,notice_id,type,payload,expires_at,receipt_hash) VALUES (?,?,?,?,?,?,?)",
    )
    .bind(
      id,
      sub.id,
      noticeId,
      type,
      JSON.stringify(data),
      expires,
      await digest(receipt),
    )
    .run();
  if (!inserted.meta?.changes) return { id: "", state: "duplicate" };
  const subscription: PushSubscription = {
    endpoint: sub.endpoint,
    expirationTime: null,
    keys: { p256dh: sub.p256dh, auth: sub.auth },
  };
  let outcome = "failed";
  try {
    const status = await sendApplePush(
      subscription,
      {
        protocolVersion: 1,
        type,
        deliveryId: id,
        receiptToken: receipt,
        expiresAt: expires,
        ...data,
      },
      await vapid(env),
      Math.ceil((expires - now) / 1000),
      id.replaceAll("-", ""),
      deps.upstream,
    );
    outcome =
      status === 201
        ? "accepted"
        : status === 404 || status === 410
          ? "expired"
          : "failed";
    if (outcome === "expired")
      await db(env)
        .prepare("DELETE FROM push_subscriptions WHERE id=?")
        .bind(sub.id)
        .run();
  } catch {}
  await db(env)
    .prepare("UPDATE push_deliveries SET state=? WHERE id=?")
    .bind(outcome, id)
    .run();
  return { id, state: outcome };
}
export async function pushRoute(
  request: Request,
  env: PushEnv,
  deps: PushDeps = {},
): Promise<Response | null> {
  const path = new URL(request.url).pathname;
  if (!path.startsWith("/api/push/")) return null;
  const now = (deps.now ?? Date.now)();
  try {
    if (path === "/api/push/config" && request.method === "GET")
      return json(await state(env));
    if (request.method !== "POST") throw new PushError(405, "post_required");
    if (path === "/api/push/collector") {
      if (env.GOV_ALERT_TRANSPORT !== "collector" || !env.COLLECTOR_HMAC_KEY)
        throw new PushError(503, "collector_not_enabled");
      if (
        !env.PUSH_REQUEST_LIMIT ||
        !(
          await env.PUSH_REQUEST_LIMIT.limit({
            key: await digest(
              request.headers.get("CF-Connecting-IP") || "unknown",
            ),
          })
        ).success
      )
        throw new PushError(429, "try_later");
      let snapshot;
      try {
        snapshot = await readCollectorSnapshot(
          request,
          env.COLLECTOR_HMAC_KEY,
          now,
        );
      } catch (error) {
        throw new PushError(
          403,
          error instanceof CollectorError ? error.message : "collector_invalid",
        );
      }
      const claim = await db(env)
        .prepare(
          "INSERT INTO alert_runtime(name,value) VALUES ('collector_last',?) ON CONFLICT(name) DO UPDATE SET value=excluded.value WHERE CAST(alert_runtime.value AS INTEGER)<?",
        )
        .bind(String(snapshot.collectedAt), snapshot.collectedAt)
        .run();
      if (!claim.meta?.changes)
        return json({ accepted: true, duplicate: true });
      const verified = env.GOV_ALERT_SEMANTICS_VERIFIED === "true";
      await db(env)
        .prepare(
          "INSERT INTO alert_runtime(name,value) VALUES ('source_status',?) ON CONFLICT(name) DO UPDATE SET value=excluded.value",
        )
        .bind(
          JSON.stringify({
            state: snapshot.state,
            complete: snapshot.complete,
            records: snapshot.recordCount,
            checkedAt: snapshot.sourceReadAt,
            receivedAt: now,
            transport: "signed_collector",
            semanticsVerified: verified,
            ...(snapshot.gatewayCode
              ? { gatewayCode: snapshot.gatewayCode }
              : {}),
          }),
        )
        .run();
      if (snapshot.complete && verified)
        await dispatchRows(env, snapshot.rows, now, deps);
      return json({
        accepted: true,
        officialEnabled: verified && snapshot.complete,
      });
    }

    if (request.headers.get("origin") !== new URL(request.url).origin)
      throw new PushError(403, "origin_denied");
    if (
      !env.PUSH_REQUEST_LIMIT ||
      !(
        await env.PUSH_REQUEST_LIMIT.limit({
          key: await digest(
            request.headers.get("CF-Connecting-IP") || "unknown",
          ),
        })
      ).success
    )
      throw new PushError(429, "try_later");
    const body = await input(request);
    if (path === "/api/push/subscribe") {
      await vapid(env);
      if (
        body.consentVersion !== "2026-11-02" ||
        !capability(body.capability) ||
        typeof body.region !== "string" ||
        !regionNames.has(body.region)
      )
        throw new PushError(400, "consent_or_region_required");
      let subscription: PushSubscription;
      try {
        subscription = await validateSubscription(body.subscription);
      } catch {
        throw new PushError(400, "apple_subscription_required");
      }
      const id = await digest(subscription.endpoint),
        hash = await digest(body.capability);
      const previous = await db(env)
        .prepare("SELECT secret_hash FROM push_subscriptions WHERE id=?")
        .bind(id)
        .first<{ secret_hash: string }>();
      if (previous && previous.secret_hash !== hash)
        throw new PushError(409, "different_registration");
      const expiration = ACTIVE_UNTIL;
      const saved = await db(env)
        .prepare(
          "INSERT INTO push_subscriptions (id,secret_hash,endpoint,p256dh,auth,region,created_at,expires_at) VALUES (?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET region=excluded.region,p256dh=excluded.p256dh,auth=excluded.auth,expires_at=excluded.expires_at WHERE push_subscriptions.secret_hash=excluded.secret_hash",
        )
        .bind(
          id,
          hash,
          subscription.endpoint,
          subscription.keys.p256dh,
          subscription.keys.auth,
          body.region,
          now,
          expiration,
        )
        .run();
      if (!saved.meta?.changes)
        throw new PushError(409, "different_registration");
      return json({ id, expiresAt: expiration, ...(await state(env)) }, 201);
    }
    if (path === "/api/push/receipt") {
      if (typeof body.deliveryId !== "string" || !capability(body.receiptToken))
        throw new PushError(403, "invalid_receipt");
      const result = await db(env)
        .prepare(
          "UPDATE push_deliveries SET received_at=COALESCE(received_at,?) WHERE id=? AND receipt_hash=? AND expires_at>?",
        )
        .bind(now, body.deliveryId, await digest(body.receiptToken), now)
        .run();
      return json({ received: !!result.meta?.changes });
    }
    const sub = await owned(env, body, now);
    if (path === "/api/push/unsubscribe") {
      await db(env).batch([
        db(env)
          .prepare("DELETE FROM push_deliveries WHERE subscription_id=?")
          .bind(sub.id),
        db(env)
          .prepare("DELETE FROM push_subscriptions WHERE id=?")
          .bind(sub.id),
      ]);
      return json({ deleted: true });
    }
    if (path === "/api/push/status") {
      const latest = await db(env)
        .prepare(
          "SELECT id,state,received_at,opened_at FROM push_deliveries WHERE subscription_id=? AND type='test' ORDER BY rowid DESC LIMIT 1",
        )
        .bind(sub.id)
        .first();
      return json({
        region: sub.region,
        expiresAt: sub.expires_at,
        lastTest: latest,
        ...(await state(env)),
      });
    }
    if (path === "/api/push/notice") {
      const d = await db(env)
        .prepare(
          "SELECT * FROM push_deliveries WHERE id=? AND subscription_id=? AND expires_at>?",
        )
        .bind(body.deliveryId, sub.id, now)
        .first<Delivery>();
      if (!d) throw new PushError(410, "notice_expired");
      await db(env)
        .prepare(
          "UPDATE push_deliveries SET opened_at=COALESCE(opened_at,?) WHERE id=?",
        )
        .bind(now, d.id)
        .run();
      return json({ type: d.type, deliveryId: d.id, ...JSON.parse(d.payload) });
    }
    if (path === "/api/push/test") {
      const claimed = await db(env)
        .prepare(
          "UPDATE push_subscriptions SET last_test_at=? WHERE id=? AND last_test_at<?",
        )
        .bind(now, sub.id, now - 60000)
        .run();
      if (!claimed.meta?.changes) throw new PushError(429, "test_wait");
      const result = await deliver(
        env,
        sub,
        `test/${crypto.randomUUID()}`,
        "test",
        {
          title: "safeKor · 테스트 알림",
          body: "실제 경보가 아닙니다. 이 기기의 알림 전달을 확인합니다.",
        },
        now,
        deps,
      );
      return json(
        { deliveryId: result.id, state: result.state, received: false },
        result.state === "accepted" ? 202 : 502,
      );
    }
    throw new PushError(404, "not_found");
  } catch (error) {
    return json(
      {
        error: error instanceof PushError ? error.code : "service_unavailable",
      },
      error instanceof PushError ? error.status : 503,
    );
  }
}
export async function pollGovernment(
  env: PushEnv,
  deps: PushDeps = {},
): Promise<void> {
  if (!env.PUSH_DB) return;
  const now = (deps.now ?? Date.now)(),
    database = env.PUSH_DB;
  if (env.GOV_ALERT_TRANSPORT === "collector") {
    await database.batch([
      database
        .prepare("DELETE FROM push_subscriptions WHERE expires_at<=?")
        .bind(now),
      database
        .prepare("DELETE FROM push_deliveries WHERE expires_at<?")
        .bind(now - 86400000),
    ]);
    return;
  }

  const prior = await database
    .prepare("SELECT value FROM alert_runtime WHERE name='source_status'")
    .first<{ value: string }>();
  if (prior) {
    try {
      const previous = JSON.parse(prior.value);
      if (
        ["source_ip_denied", "source_auth_error", "source_quota"].includes(
          previous.state,
        ) &&
        typeof previous.checkedAt === "number" &&
        now - previous.checkedAt < 6 * 3600000
      )
        return;
    } catch {}
  }
  const lease = await database
    .prepare(
      "INSERT INTO alert_runtime(name,value) VALUES ('poll_lease',?) ON CONFLICT(name) DO UPDATE SET value=excluded.value WHERE CAST(alert_runtime.value AS INTEGER)<?",
    )
    .bind(String(now + 90000), now)
    .run();
  if (!lease.meta?.changes) return;
  const save = async (value: Record<string, unknown>) => {
    await database
      .prepare(
        "INSERT INTO alert_runtime(name,value) VALUES ('source_status',?) ON CONFLICT(name) DO UPDATE SET value=excluded.value",
      )
      .bind(JSON.stringify({ ...value, checkedAt: now }))
      .run();
  };
  try {
    await database.batch([
      database
        .prepare("DELETE FROM push_subscriptions WHERE expires_at<=?")
        .bind(now),
      database
        .prepare("DELETE FROM push_deliveries WHERE expires_at<?")
        .bind(now - 86400000),
    ]);
    if (!env.GOV_ALERT_API_KEY) {
      await save({ state: "key_required", complete: false });
      return;
    }
    const date = new Date(now + 9 * 3600000).toISOString().slice(0, 10),
      budget = `budget/${date}`;
    const used = await database
      .prepare(
        "INSERT INTO alert_runtime(name,value) VALUES (?, '1') ON CONFLICT(name) DO UPDATE SET value=CAST(CAST(alert_runtime.value AS INTEGER)+1 AS TEXT) WHERE CAST(alert_runtime.value AS INTEGER)<900",
      )
      .bind(budget)
      .run();
    if (!used.meta?.changes) {
      await save({ state: "daily_budget", complete: false });
      return;
    }
    const source = await fetchOfficial(
      env.GOV_ALERT_API_KEY,
      now,
      deps.upstream,
    );
    const verified = env.GOV_ALERT_SEMANTICS_VERIFIED === "true";
    await save({
      state: source.state,
      complete: source.complete,
      records: source.rows.length,
      ...(source.gatewayCode ? { gatewayCode: source.gatewayCode } : {}),
      ...(source.httpStatus ? { httpStatus: source.httpStatus } : {}),
      semanticsVerified: verified,
    });
    // Incomplete pagination and unverified semantics can never create an alert.
    if (!source.complete || !verified) return;
    await dispatchRows(env, source.rows, now, deps);
  } catch {
    await save({ state: "source_unavailable", complete: false });
  }
}

async function dispatchRows(
  env: PushEnv,
  rows: Record<string, unknown>[],
  now: number,
  deps: PushDeps,
): Promise<void> {
  const notices: Notice[] = [];
  for (const row of rows) {
    const n = await normalizeOfficial(row, now, true);
    if (n) notices.push(n);
  }
  const subs = await db(env)
    .prepare("SELECT * FROM push_subscriptions WHERE expires_at>? LIMIT 1000")
    .bind(now)
    .all<Sub>();
  for (const notice of notices)
    for (const sub of subs.results) {
      if (
        regionMatches(sub.region, notice.regions) &&
        notice.expiresAt > Date.now()
      )
        await deliver(
          env,
          sub,
          `${notice.id}/${notice.revision}`,
          "civil",
          notice as unknown as Record<string, unknown>,
          now,
          deps,
        );
    }
}
