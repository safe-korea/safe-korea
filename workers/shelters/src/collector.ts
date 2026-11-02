import { decode64 } from "./web_push.ts";
export type CollectorSnapshot = {
  protocolVersion: 1;
  collectedAt: number;
  sourceReadAt: number;
  state: string;
  complete: boolean;
  recordCount: number;
  totalCount: number;
  rows: Record<string, unknown>[];
  gatewayCode?: string;
};
const states = new Set([
  "source_observed",
  "source_incomplete",
  "source_ip_denied",
  "source_auth_error",
  "source_quota",
  "source_network_error",
  "source_timeout",
  "source_http_error",
  "source_invalid_response",
  "source_redirect_rejected",
]);
export class CollectorError extends Error {}
export async function readCollectorSnapshot(
  request: Request,
  secret: string,
  now: number,
): Promise<CollectorSnapshot> {
  const stamp = request.headers.get("X-SafeKor-Timestamp") || "",
    signature = request.headers.get("X-SafeKor-Signature") || "";
  if (
    !/^\d{13}$/.test(stamp) ||
    Math.abs(now - Number(stamp)) > 60000 ||
    !/^[A-Za-z0-9_-]{43}$/.test(signature) ||
    secret.length < 43
  )
    throw new CollectorError("collector_auth_failed");
  if (Number(request.headers.get("Content-Length")) > 2 * 1024 * 1024)
    throw new CollectorError("collector_too_large");
  const reader = request.body?.getReader();
  if (!reader) throw new CollectorError("collector_invalid");
  const chunks: Uint8Array[] = [];
  let count = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    count += value.length;
    if (count > 2 * 1024 * 1024) {
      await reader.cancel();
      throw new CollectorError("collector_too_large");
    }
    chunks.push(value);
  }
  const body = new Uint8Array(count);
  let at = 0;
  for (const p of chunks) {
    body.set(p, at);
    at += p.length;
  }
  const prefix = new TextEncoder().encode(stamp + "\n"),
    signed = new Uint8Array(prefix.length + body.length);
  signed.set(prefix);
  signed.set(body, prefix.length);
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"],
  );
  if (
    !(await crypto.subtle.verify(
      "HMAC",
      key,
      decode64(signature) as BufferSource,
      signed,
    ))
  )
    throw new CollectorError("collector_auth_failed");
  let s: CollectorSnapshot;
  try {
    s = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(body));
  } catch {
    throw new CollectorError("collector_invalid");
  }
  if (
    !s ||
    s.protocolVersion !== 1 ||
    s.collectedAt !== Number(stamp) ||
    !Number.isSafeInteger(s.sourceReadAt) ||
    s.sourceReadAt > s.collectedAt + 30000 ||
    s.sourceReadAt < s.collectedAt - 60000 ||
    !states.has(s.state) ||
    typeof s.complete !== "boolean" ||
    !Number.isSafeInteger(s.recordCount) ||
    s.recordCount < 0 ||
    s.recordCount > 100 ||
    !Number.isSafeInteger(s.totalCount) ||
    s.totalCount < 0 ||
    !Array.isArray(s.rows) ||
    s.rows.length > s.recordCount
  )
    throw new CollectorError("collector_invalid");
  if (
    s.complete &&
    (s.state !== "source_observed" ||
      s.totalCount !== s.recordCount ||
      s.totalCount > 100)
  )
    throw new CollectorError("collector_invalid");
  if (!s.complete && s.rows.length)
    throw new CollectorError("collector_invalid");
  if (
    s.rows.some(
      (r) =>
        !r ||
        typeof r !== "object" ||
        r.DST_SE_NM !== "민방공" ||
        typeof r.MSG_CN !== "string" ||
        r.MSG_CN.length > 4000,
    )
  )
    throw new CollectorError("collector_invalid");
  if (
    s.gatewayCode !== undefined &&
    !/^(01|02|10|11|12|13|20|22|30|31|32|33|34|99)$/.test(s.gatewayCode)
  )
    throw new CollectorError("collector_invalid");
  return s;
}
