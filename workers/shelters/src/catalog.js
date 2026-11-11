import regions from '../../../assets/regions.json' with { type: 'json' };

export const SOURCE_URL = 'https://www.safekorea.go.kr/safekorea-kor/flsm/flsm/facilitiesSafteyMap.do?menuSn=234&title=%EB%AF%BC%EB%B0%A9%EC%9C%84%EB%8C%80%ED%94%BC%EC%86%8C';
export const UPSTREAM_URL = 'https://www.safekorea.go.kr/safekorea-kor/flsm/flsm/facilityDataList.do';
export const REGION_NAMES = new Map(regions.provinces.flatMap(p => p.districts.map(d => [d.code, `${p.name} ${d.name}`])));
export const MAX_BYTES = 2 * 1024 * 1024;
const MAX_ROWS = 5000;

/** @param {unknown} value @returns {Record<string, any>} */
function object(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw Error('invalid_object');
  return /** @type {Record<string, any>} */ (value);
}
/** @param {unknown} value */
function text(value) {
  if (typeof value !== 'string' || !value.trim() || value.length > 1000) throw Error('invalid_text');
  return value;
}
/** @param {Record<string, any>} row @param {string} prefix @param {string} axis */
function dms(row, prefix, axis) {
  const values = ['de', 'mi', 'se'].map(suffix => {
    const raw = row[`${prefix}${axis}${suffix}`];
    if ((typeof raw !== 'number' && typeof raw !== 'string') || String(raw).trim() === '') throw Error('missing_coordinate');
    const value = Number(raw);
    if (!Number.isFinite(value)) throw Error('invalid_coordinate');
    return value;
  });
  const [degrees, minutes, seconds] = values;
  if (!Number.isInteger(degrees) || minutes < 0 || minutes >= 60 || seconds < 0 || seconds >= 60) throw Error('invalid_dms');
  return degrees + minutes / 60 + seconds / 3600;
}

/** Number of facilities the full list must hold, or null when rows are missing.
 * Since 2026-11 the source reports every facility twice in `totalCnt` (its
 * paged `list` repeats each one) while `mapList` holds each facility once.
 * Only that exact doubling is accepted, and only when `mapList` has no repeats.
 * @param {unknown[]} rows @param {number} total @returns {number|null} */
export function officialTotal(rows, total) {
  if (rows.length === total) return total;
  if (rows.length === 0 || total !== rows.length * 2) return null;
  const ids = new Set(rows.map(row => row && typeof row === 'object' ? /** @type {any} */ (row).facilCode : undefined));
  return ids.size === rows.length && !ids.has(undefined) ? rows.length : null;
}

/** Official-list validation mirrors the existing native adapter. No synthetic facilities.
 * @param {unknown} input @param {string} region @param {number} now */
export function normalizeCatalog(input, region, now) {
  const payload = object(input);
  const meta = object(payload.facilitiesVO);
  if (meta.tableNm !== 'TFK_CIVIL_EMR_FACL_TEMP' || meta.tableKorNm !== '민방위대피소' || meta.gubun !== '2' || meta.sggCd !== region) throw Error('wrong_source');
  const rows = payload.mapList;
  const total = payload.totalCnt;
  if (!Array.isArray(rows) || !Number.isInteger(total) || total < 0 || total > MAX_ROWS) throw Error('incomplete_list');
  const listed = officialTotal(rows, total);
  if (listed === null) throw Error('incomplete_list');
  /** @type {Map<string, {id:string,name:string,address:string,latitude:number,longitude:number,updatedAt:null,status:string}>} */
  const byId = new Map();
  let skippedCount = 0;
  for (const raw of rows) {
    let record;
    try {
      const row = object(raw);
      const entrance = typeof row.aot === 'string' && row.aot.trim() !== '' && row.aot !== '-';
      const prefix = entrance ? 'aot' : 'facil';
      const latitude = dms(row, prefix, 'La');
      const longitude = dms(row, prefix, 'Lo');
      if (latitude < 33 || latitude > 39.5 || longitude < 124 || longitude > 132) throw Error('outside_korea');
      record = {
        id: text(row.facilCode), name: text(row.facilNm),
        address: text(entrance ? row.aot : (row.facilRdAddr ?? row.facilAddr)),
        latitude, longitude, updatedAt: null, status: 'official_listing',
      };
    } catch (_) { skippedCount++; continue; }
    const existing = byId.get(record.id);
    if (existing) {
      if (JSON.stringify(existing) !== JSON.stringify(record)) throw Error('conflicting_identity');
      skippedCount++;
    } else byId.set(record.id, record);
  }
  if (listed > 0 && byId.size === 0) throw Error('no_valid_records');
  return {
    schemaVersion: 1, sourceName: '행정안전부 국민안전24 · 민방위 대피소', sourceUrl: SOURCE_URL,
    retrievedAt: new Date(now).toISOString(), coverage: REGION_NAMES.get(region), areaCode: region,
    officialCount: listed, skippedCount, status: 'verified', items: [...byId.values()],
  };
}

/** Size limit applies to decoded stream bytes, including chunked/compressed responses.
 * @param {Response} response @returns {Promise<unknown>} */
export async function boundedJson(response) {
  if (!response.ok || !response.body || !(response.headers.get('content-type') || '').toLowerCase().includes('application/json')) throw Error('upstream_unavailable');
  if (Number(response.headers.get('content-length') || 0) > MAX_BYTES) {
    await response.body.cancel();
    throw Error('response_too_large');
  }
  const reader = response.body.getReader();
  let size = 0;
  let data = '';
  const decoder = new TextDecoder('utf-8', {fatal:true});
  try {
    for (;;) {
      const {value, done} = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > MAX_BYTES) throw Error('response_too_large');
      data += decoder.decode(value, {stream:true});
    }
    data += decoder.decode();
    return JSON.parse(data);
  } catch (error) { await reader.cancel().catch(() => {}); throw error; }
  finally { reader.releaseLock(); }
}
