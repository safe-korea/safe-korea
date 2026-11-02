import {
  buildPushPayload,
  type PushSubscription,
} from "@block65/webcrypto-web-push";

export type Vapid = { publicKey: string; privateKey: string; subject: string };
export function decode64(value: string): Uint8Array {
  if (!/^[A-Za-z0-9_-]+$/.test(value)) throw Error("invalid_encoding");
  return Uint8Array.from(
    atob(value.replace(/-/g, "+").replace(/_/g, "/")),
    (c) => c.charCodeAt(0),
  );
}
export function encode64(value: Uint8Array): string {
  return btoa(String.fromCharCode(...value))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}
export async function digest(value: string): Promise<string> {
  return Array.from(
    new Uint8Array(
      await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)),
    ),
    (b) => b.toString(16).padStart(2, "0"),
  ).join("");
}
export function token(): string {
  return encode64(crypto.getRandomValues(new Uint8Array(32)));
}
export function appleEndpoint(value: unknown): value is string {
  if (typeof value !== "string" || value.length > 2048) return false;
  try {
    const u = new URL(value);
    return (
      u.protocol === "https:" &&
      !u.username &&
      !u.password &&
      !u.port &&
      !u.hash &&
      /^[a-z0-9-]+\.push\.apple\.com$/.test(u.hostname) &&
      u.pathname.length > 1
    );
  } catch {
    return false;
  }
}
export async function validateSubscription(
  value: unknown,
): Promise<PushSubscription> {
  const s = value as Partial<PushSubscription> | null;
  if (
    !s ||
    !appleEndpoint(s.endpoint) ||
    !s.keys ||
    typeof s.keys.p256dh !== "string" ||
    typeof s.keys.auth !== "string"
  )
    throw Error("unsupported_subscription");
  const point = decode64(s.keys.p256dh),
    auth = decode64(s.keys.auth);
  if (point.length !== 65 || point[0] !== 4 || auth.length !== 16)
    throw Error("invalid_keys");
  await crypto.subtle.importKey(
    "raw",
    point as BufferSource,
    { name: "ECDH", namedCurve: "P-256" },
    false,
    [],
  );
  return {
    endpoint: s.endpoint,
    expirationTime: null,
    keys: { p256dh: s.keys.p256dh, auth: s.keys.auth },
  };
}
// Apple recommends reusing a VAPID JWT rather than refreshing on every message.
let authorization:
  | { aud: string; key: string; value: string; until: number }
  | undefined;
export async function sendApplePush(
  subscription: PushSubscription,
  data: Record<string, unknown>,
  vapid: Vapid,
  ttl: number,
  topic: string,
  upstream: typeof fetch = fetch,
): Promise<number> {
  if (!appleEndpoint(subscription.endpoint))
    throw Error("unsupported_endpoint");
  const payload = await buildPushPayload(
    {
      data: JSON.stringify(data),
      options: {
        ttl: Math.max(1, Math.min(ttl, 120)),
        topic: topic.slice(0, 32),
        urgency: "high",
      },
    },
    subscription,
    vapid,
  );
  const aud = new URL(subscription.endpoint).origin,
    now = Date.now();
  if (
    authorization &&
    authorization.aud === aud &&
    authorization.key === vapid.publicKey &&
    authorization.until > now
  )
    payload.headers.authorization = authorization.value;
  else
    authorization = {
      aud,
      key: vapid.publicKey,
      value: payload.headers.authorization,
      until: now + 60 * 60 * 1000,
    };
  const response = await upstream(subscription.endpoint, {
    ...payload,
    redirect: "manual",
    signal: AbortSignal.timeout(8000),
  });
  // Never log the endpoint, capability, keys or APNs response body.
  await response.body?.cancel();
  return response.status;
}
