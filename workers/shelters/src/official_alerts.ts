import regionData from "../../../assets/regions.json" with { type: "json" };
import { digest } from "./web_push.ts";
export type CivilKind =
  | "air"
  | "watch"
  | "cbrn"
  | "chemical"
  | "biological"
  | "nuclear";
export type Notice = {
  id: string;
  revision: string;
  kind: CivilKind;
  publishedAt: number;
  expiresAt: number;
  agency: string;
  area: string;
  regions: string[];
};
export const regionNames = new Map<string, string>();
for (const p of regionData.provinces) {
  regionNames.set(p.code, p.name);
  for (const d of p.districts) regionNames.set(d.code, `${p.name} ${d.name}`);
}
export function regionMatches(selected: string, targets: string[]): boolean {
  return targets.some(
    (code) =>
      code === "nationwide" ||
      code === selected ||
      (code.length === 2 && selected.startsWith(code)),
  );
}
export function civilKind(body: string): CivilKind | null {
  const t = body.normalize("NFKC").replace(/\s+/g, "").toLowerCase();
  if (
    t.length > 8000 ||
    /훈련|연습|모의|테스트|drill|exercise|test|예정|예고|예시|가정|오발령|잘못발령|정정|취소|해제|종료|발령시|발령할경우|발령될경우|발령된경우|발령하지|발령되지|발령된것이아니|화재|산불|태풍|지진|호우|홍수|폭염|누출|유출|사고/.test(
      t,
    )
  )
    return null;
  if (!/발령(합니다|되었습니다|됐습니다|하였습니다|되었|됨|[.!]|$)/.test(t))
    return null;
  const found: CivilKind[] = [];
  if (t.includes("공습경보")) found.push("air");
  if (t.includes("경계경보")) found.push("watch");
  if (t.includes("화생방경보")) found.push("cbrn");
  if (t.includes("핵경보")) found.push("nuclear");
  if (/화학(무기)?공격경보/.test(t)) found.push("chemical");
  if (/생물학?공격경보/.test(t)) found.push("biological");
  return found.length === 1 ? found[0] : null;
}
export function koreanTimestamp(value: unknown): number | null {
  if (typeof value !== "string") return null;
  const m =
    /^(\d{4})[-/]?(\d{2})[-/]?(\d{2})[ T]?(\d{2}):?(\d{2}):?(\d{2})$/.exec(
      value,
    );
  if (!m) return null;
  const [year, month, day, hour, minute, second] = m.slice(1).map(Number);
  const n = Date.UTC(year, month - 1, day, hour - 9, minute, second),
    k = new Date(n + 9 * 3600000);
  return k.getUTCFullYear() === year &&
    k.getUTCMonth() === month - 1 &&
    k.getUTCDate() === day &&
    hour < 24 &&
    minute < 60 &&
    second < 60
    ? n
    : null;
}
// Never upgrade schema/region/timezone assumptions into verified operation.
export async function normalizeOfficial(
  row: Record<string, unknown>,
  now: number,
  semanticsVerified: boolean,
): Promise<Notice | null> {
  if (
    !semanticsVerified ||
    row.DST_SE_NM !== "민방공" ||
    !["위급재난", "긴급재난"].includes(String(row.EMRG_STEP_NM)) ||
    typeof row.MSG_CN !== "string"
  )
    return null;
  const kind = civilKind(row.MSG_CN),
    published = koreanTimestamp(row.CRT_DT);
  if (
    !kind ||
    published === null ||
    published > now + 30000 ||
    published < now - 120000
  )
    return null;
  if (typeof row.SN !== "string" && typeof row.SN !== "number") return null;
  if (
    typeof row.RCPTN_RGN_ID !== "string" ||
    typeof row.RCPTN_RGN_NM !== "string"
  )
    return null;
  // API recipient IDs are internal IDs, not shelter administrative codes.
  // Resolve only exact official names; unknown subareas fail closed.
  if (!row.RCPTN_RGN_ID.trim()) return null;
  const names = row.RCPTN_RGN_NM.split(/[,|;]/).map((n) =>
    n.trim().replace(/\s+/g, " "),
  );
  const byName = new Map(
    Array.from(regionNames, ([code, name]) => [name, code]),
  );
  const codes = names.map((name) =>
    name === "전국" ? "nationwide" : byName.get(name),
  );
  if (!names.length || codes.some((c) => !c)) return null;
  const revision = await digest(
    JSON.stringify([
      row.SN,
      row.MDFCN_YMD,
      row.MSG_CN,
      row.RCPTN_RGN_ID,
      row.CRT_DT,
    ]),
  );
  return {
    id: await digest(String(row.SN)),
    revision,
    kind,
    publishedAt: published,
    expiresAt: published + 120000,
    agency: "행정안전부 긴급재난문자 공개 API",
    area: names.join(", "),
    regions: codes as string[],
  };
}
export type SourceResult = {
  state: string;
  complete: boolean;
  httpStatus?: number;
  gatewayCode?: string;
  rows: Record<string, unknown>[];
};
export async function fetchOfficial(
  key: string,
  now: number,
  upstream: typeof fetch = fetch,
): Promise<SourceResult> {
  const date = new Date(now + 9 * 3600000)
    .toISOString()
    .slice(0, 10)
    .replaceAll("-", "");
  const url = new URL("https://www.safetydata.go.kr/V2/api/DSSP-IF-00247");
  url.search = new URLSearchParams({
    serviceKey: key.trim(),
    returnType: "json",
    numOfRows: "100",
    pageNo: "1",
    crtDt: date,
  }).toString();
  try {
    const response = await upstream(url, {
      redirect: "manual",
      signal: AbortSignal.timeout(12000),
      headers: {
        Accept: "application/json",
        "User-Agent":
          "safeKor/1.0 (+https://safe-korea-shelter-api.trovapp.workers.dev/support)",
      },
    });
    if (response.status >= 300 && response.status < 400) {
      await response.body?.cancel();
      return {
        state: "source_redirect_rejected",
        httpStatus: response.status,
        complete: false,
        rows: [],
      };
    }
    if (Number(response.headers.get("content-length")) > 2 * 1024 * 1024) {
      await response.body?.cancel();
      return { state: "source_unavailable", complete: false, rows: [] };
    }
    const reader = response.body?.getReader();
    if (!reader)
      return { state: "source_unavailable", complete: false, rows: [] };
    const chunks: Uint8Array[] = [];
    let size = 0;
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.length;
      if (size > 2 * 1024 * 1024) {
        await reader.cancel();
        return { state: "source_unavailable", complete: false, rows: [] };
      }
      chunks.push(value);
    }
    const bytes = new Uint8Array(size);
    let offset = 0;
    for (const chunk of chunks) {
      bytes.set(chunk, offset);
      offset += chunk.length;
    }
    const raw = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
    if (raw.trim().startsWith("<")) {
      const code = /<returnReasonCode[^>]*>\s*(?:<!\[CDATA\[)?\s*(\d+)/i.exec(
        raw,
      )?.[1];
      return {
        state:
          code === "32"
            ? "source_ip_denied"
            : code === "22"
              ? "source_quota"
              : code
                ? "source_auth_error"
                : response.ok
                  ? "source_invalid_response"
                  : "source_http_error",
        gatewayCode: code,
        httpStatus: response.status,
        complete: false,
        rows: [],
      };
    }
    if (!response.ok)
      return {
        state: "source_http_error",
        httpStatus: response.status,
        complete: false,
        rows: [],
      };
    const data = JSON.parse(raw),
      rows: Record<string, unknown>[] = [];
    let total: number | undefined;
    let invalid = false;
    let gatewayCode: string | undefined;
    function visit(v: unknown): void {
      if (Array.isArray(v)) {
        for (const item of v) visit(item);
        return;
      }
      if (!v || typeof v !== "object") return;
      const o = v as Record<string, unknown>;
      if ("SN" in o) {
        rows.push(o);
        return;
      }
      for (const [k, child] of Object.entries(o)) {
        if (
          ["resultCode", "returnReasonCode"].includes(k) &&
          !["0", "00"].includes(String(child))
        ) {
          invalid = true;
          const code = String(child);
          gatewayCode = /^(01|02|10|11|12|13|20|22|30|31|32|33|34|99)$/.test(
            code,
          )
            ? code
            : "unknown";
        }
        if (k === "totalCount" && Number.isSafeInteger(Number(child)))
          total = Number(child);
        visit(child);
      }
    }
    visit(data);
    const complete =
      !invalid && total !== undefined && total === rows.length && total <= 100;
    return {
      state: invalid
        ? gatewayCode === "32"
          ? "source_ip_denied"
          : gatewayCode === "22"
            ? "source_quota"
            : "source_auth_error"
        : complete
          ? "source_observed"
          : "source_incomplete",
      complete,
      rows: invalid ? [] : rows,
      ...(gatewayCode ? { gatewayCode } : {}),
    };
  } catch (error) {
    const state =
      error instanceof Error &&
      ["TimeoutError", "AbortError"].includes(error.name)
        ? "source_timeout"
        : error instanceof SyntaxError
          ? "source_invalid_response"
          : "source_network_error";
    return { state, complete: false, rows: [] };
  }
}
