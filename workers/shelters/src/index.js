import {REGION_NAMES, UPSTREAM_URL, boundedJson, normalizeCatalog} from './catalog.js';

export const FRESH_SECONDS = 15 * 60;
export const MAX_STALE_SECONDS = 24 * 60 * 60;
/** @typedef {{limit: (input:{key:string}) => Promise<{success:boolean}>}} Limiter */
/** @typedef {{ASSETS?:{fetch:(request:Request)=>Promise<Response>}, ALLOWED_ORIGINS?:string, UPSTREAM_REGION_LIMIT:Limiter, UPSTREAM_TOTAL_LIMIT:Limiter}} Env */
/** @typedef {{waitUntil:(promise:Promise<unknown>)=>void}} Context */
/** @typedef {{match:(request:Request)=>Promise<Response|undefined>,put:(request:Request,response:Response)=>Promise<void>}} DataCache */
/** @typedef {ReturnType<typeof normalizeCatalog>} Catalog */
/** @typedef {{catalog:Catalog, fetchedAt:number}} Stored */
/** @type {Map<string, Promise<Stored>>} */
const pending = new Map();

class ApiError extends Error {
  /** @param {number} status @param {string} code @param {string} message */
  constructor(status, code, message) { super(message); this.status = status; this.code = code; }
}
/** @param {Request} request @param {Env} env */
function allowedOrigin(request, env) {
  const origin = request.headers.get('origin');
  const allowed = (env.ALLOWED_ORIGINS || '').split(',').map(value => value.trim()).filter(Boolean);
  if (origin && !allowed.includes(origin)) throw new ApiError(403, 'origin_denied', '허용되지 않은 웹 주소입니다.');
  return origin;
}
/** @param {unknown} value @param {number} status @param {string|null} origin @param {Record<string,string>} [extra] */
function json(value, status, origin, extra = {}) {
  const headers = new Headers({
    'Content-Type':'application/json; charset=utf-8', 'Cache-Control':'no-store',
    'X-Content-Type-Options':'nosniff', 'Vary':'Origin', ...extra,
  });
  if (origin) {
    headers.set('Access-Control-Allow-Origin', origin);
    headers.set('Access-Control-Expose-Headers', 'X-Data-Cache, Retry-After');
  }
  return new Response(JSON.stringify(value), {status, headers});
}
/** @param {Stored} stored @param {string} state @param {number} now @param {string|null} origin */
function delivery(stored, state, now, origin) {
  const ageSeconds = Math.max(0, Math.floor((now - stored.fetchedAt) / 1000));
  return json({
    apiVersion:1, catalog:stored.catalog,
    delivery:{state, ageSeconds, stale:state === 'stale'},
    notice: state === 'stale' ? '원본 재조회가 되지 않아 이전 자료를 표시합니다. 현장 개방 여부를 확인하세요.' : '공식 목록 등재 정보이며 시설 개방·경로 안전을 보장하지 않습니다.',
  }, 200, origin, {'X-Data-Cache':state});
}
/** @param {DataCache} cache @param {Request} key @param {string} region @param {number} now @returns {Promise<Stored|null>} */
async function readCache(cache, key, region, now) {
  try {
    const response = await cache.match(key);
    if (!response) return null;
    const value = /** @type {Stored} */ (await response.json());
    if (!Number.isFinite(value.fetchedAt) || value.fetchedAt > now || now - value.fetchedAt >= MAX_STALE_SECONDS * 1000 || value.catalog.areaCode !== region) return null;
    return value;
  } catch (_) { return null; }
}
/** @param {string} region @param {Env} env @param {typeof fetch} upstream @param {()=>number} now */
async function refresh(region, env, upstream, now) {
  // Only origin misses consume these approximate per-location source budgets.
  if (!env.UPSTREAM_REGION_LIMIT || !env.UPSTREAM_TOTAL_LIMIT) throw new ApiError(503, 'configuration_missing', '데이터 서버 설정을 확인 중입니다.');
  if (!(await env.UPSTREAM_REGION_LIMIT.limit({key:region})).success || !(await env.UPSTREAM_TOTAL_LIMIT.limit({key:'official-facilities'})).success) throw new ApiError(429, 'refresh_limited', '조회가 몰리고 있습니다. 잠시 후 다시 시도하세요.');
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 8000);
  try {
    const response = await upstream(UPSTREAM_URL, {
      method:'POST', redirect:'manual', signal:controller.signal,
      headers:{'Content-Type':'application/x-www-form-urlencoded', 'Accept':'application/json'},
      body:new URLSearchParams({tableNm:'TFK_CIVIL_EMR_FACL_TEMP',tableKorNm:'민방위대피소',sggCd:region,page:'1',size:'5'}),
    });
    const payload = await boundedJson(response);
    const fetchedAt = now();
    return {catalog:normalizeCatalog(payload, region, fetchedAt), fetchedAt};
  } finally { clearTimeout(timeout); }
}

/** Dependency injection makes upstream/cache failures reproducible without cloud writes.
 * @param {Request} request @param {Env} env @param {Context} ctx
 * @param {{cache:DataCache, upstream?:typeof fetch, now?:()=>number}} deps */
export async function handleRequest(request, env, ctx, deps) {
  let origin = null;
  try {
    origin = allowedOrigin(request, env);
    const url = new URL(request.url);
    if (url.pathname !== '/api/shelters' && url.pathname !== '/health') throw new ApiError(404, 'not_found', '지원하지 않는 주소입니다.');
    if (request.method === 'OPTIONS') {
      if (request.headers.get('Access-Control-Request-Method') !== 'GET') throw new ApiError(405,'method_not_allowed','GET 요청만 지원합니다.');
      const headers = new Headers({'Access-Control-Allow-Methods':'GET, OPTIONS','Access-Control-Allow-Headers':'Accept, Content-Type','Access-Control-Max-Age':'600','Vary':'Origin'});
      if (origin) headers.set('Access-Control-Allow-Origin',origin);
      return new Response(null,{status:204,headers});
    }
    if (request.method !== 'GET') throw new ApiError(405, 'method_not_allowed', 'GET 요청만 지원합니다.');
    if (url.pathname === '/health') return json({service:'safe-korea-shelter-api',apiVersion:1,status:'ok',governmentAlertReception:false},200,origin);
    const region = url.searchParams.get('region') || '';
    if (url.searchParams.size !== 1 || !/^\d{5}$/.test(region) || !REGION_NAMES.has(region)) throw new ApiError(400,'invalid_region','목록에 있는 시·군·구를 선택해 주세요.');
    const now = deps.now || Date.now;
    const key = new Request(new URL(`/__cache/v1/shelters/${region}`, url.origin));
    const stored = await readCache(deps.cache, key, region, now());
    if (stored && now() - stored.fetchedAt < FRESH_SECONDS * 1000) return delivery(stored,'hit',now(),origin);
    try {
      const pendingKey = key.url;
      let work = pending.get(pendingKey);
      if (!work) {
        work = refresh(region, env, deps.upstream || fetch, now).finally(() => pending.delete(pendingKey));
        pending.set(pendingKey, work);
      }
      const fresh = await work;
      ctx.waitUntil(deps.cache.put(key, new Response(JSON.stringify(fresh), {headers:{'Content-Type':'application/json','Cache-Control':`public, max-age=${MAX_STALE_SECONDS}`}})).catch(() => {}));
      return delivery(fresh,'miss',now(),origin);
    } catch (error) {
      if (stored && now() - stored.fetchedAt < MAX_STALE_SECONDS * 1000) return delivery(stored,'stale',now(),origin);
      if (error instanceof ApiError) throw error;
      throw new ApiError(502,'source_unavailable','공식 대피시설 자료를 확인하지 못했습니다. 잠시 후 다시 시도하세요.');
    }
  } catch (error) {
    const failure = error instanceof ApiError ? error : new ApiError(503,'temporarily_unavailable','조회 서비스를 일시적으로 이용할 수 없습니다.');
    return json({error:{code:failure.code,message:failure.message}},failure.status,origin,
      failure.status === 429 ? {'Retry-After':'60'} : failure.status === 405 ? {'Allow':'GET, OPTIONS'} : {});
  }
}

export default {
  /** @param {Request} request @param {Env} env @param {Context} ctx */
  fetch(request, env, ctx) {
    const cache = /** @type {CacheStorage & {default:DataCache}} */ (caches).default;
    return handleRequest(request, env, ctx, {cache});
  },
};
