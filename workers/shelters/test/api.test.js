import test from 'node:test';
import assert from 'node:assert/strict';
import {handleRequest,FRESH_SECONDS,MAX_STALE_SECONDS} from '../src/index.js';
import {normalizeCatalog,boundedJson,MAX_BYTES,UPSTREAM_URL} from '../src/catalog.js';

// Synthetic records are isolated to tests and are never bundled into the Worker.
const row = (id='test-a') => ({facilCode:id,facilNm:'테스트 시설',facilRdAddr:'테스트 주소',facilLade:37,facilLami:30,facilLase:0,facilLode:127,facilLomi:0,facilLose:0});
const payload = (rows=[row()]) => ({facilitiesVO:{tableNm:'TFK_CIVIL_EMR_FACL_TEMP',tableKorNm:'민방위대피소',gubun:'2',sggCd:'11110'},totalCnt:rows.length,mapList:rows});
const response = data => new Response(JSON.stringify(data),{headers:{'Content-Type':'application/json'}});
function harness() {
  let now = Date.parse('2026-11-01T00:00:00Z');
  let calls = 0;
  const data = new Map();
  const writes=[];
  const allowed = {limit:async()=>({success:true})};
  const env = {ALLOWED_ORIGINS:'https://app.example,http://localhost:8766',UPSTREAM_REGION_LIMIT:allowed,UPSTREAM_TOTAL_LIMIT:allowed};
  const deps = {
    now:()=>now,
    cache:{match:async req=>data.get(req.url)?.clone(),put:async(req,res)=>{data.set(req.url,res.clone());}},
    upstream:async(url,init)=>{
      calls++;
      assert.equal(url,UPSTREAM_URL);
      assert.equal(init.redirect,'manual');
      assert.equal(init.method,'POST');
      assert.deepEqual(Object.fromEntries(init.body),{tableNm:'TFK_CIVIL_EMR_FACL_TEMP',tableKorNm:'민방위대피소',sggCd:'11110',page:'1',size:'5'});
      assert(!('Cookie' in init.headers));
      return response(payload());
    },
  };
  const request = (query='region=11110',origin='https://app.example',method='GET')=>handleRequest(new Request(`https://api.example/api/shelters?${query}`,{method,headers:origin?{Origin:origin}:{}}),env,{waitUntil:p=>writes.push(p)},deps);
  return {request,env,deps,data,writes,get calls(){return calls},advance:seconds=>{now+=seconds*1000}};
}

test('fixed official request, source date, canonical region and missing source update date',async()=>{
  const h=harness(); const r=await h.request(); const body=await r.json();
  assert.equal(r.status,200); assert.equal(body.catalog.coverage,'서울특별시 종로구');
  assert.equal(body.catalog.items[0].updatedAt,null); assert.equal(body.delivery.stale,false);
  assert.equal(body.catalog.retrievedAt,'2026-11-01T00:00:00.000Z');
  assert.equal(r.headers.get('access-control-allow-origin'),'https://app.example');
  assert.equal(r.headers.get('cache-control'),'no-store');
});
test('cache hits reuse timestamp without sharing CORS origin',async()=>{
  const h=harness(); await h.request();await Promise.all(h.writes);h.advance(60);
  const r=await h.request('region=11110','http://localhost:8766');const b=await r.json();
  assert.equal(h.calls,1);assert.equal(b.delivery.state,'hit');assert.equal(b.delivery.ageSeconds,60);
  assert.equal(b.catalog.retrievedAt,'2026-11-01T00:00:00.000Z');
  assert.equal(r.headers.get('access-control-allow-origin'),'http://localhost:8766');
});
test('no coordinates, arbitrary proxy URL, duplicate or unknown region accepted',async()=>{
  const h=harness();
  for(const q of ['region=99999','region=11110&region=11110','region=11110&lat=37','region=11110&url=https://evil.example','region=../11110','']) assert.equal((await h.request(q)).status,400);
  assert.equal(h.calls,0);
});
test('unknown browser origin denied, native requests allowed, POST rejected',async()=>{
  const h=harness();assert.equal((await h.request('region=11110','https://evil.example')).status,403);
  assert.equal(h.calls,0);assert.equal((await h.request('region=11110',null)).status,200);
  assert.equal((await h.request('region=11110',null,'POST')).status,405);
});
test('CORS preflight and health never contact upstream',async()=>{
  const h=harness();
  const r=await handleRequest(new Request('https://api.example/api/shelters',{method:'OPTIONS',headers:{Origin:'https://app.example','Access-Control-Request-Method':'GET'}}),h.env,{waitUntil(){}},h.deps);
  assert.equal(r.status,204);
  const health=await handleRequest(new Request('https://api.example/health'),h.env,{waitUntil(){}},h.deps);
  assert.equal((await health.json()).governmentAlertReception,false);assert.equal(h.calls,0);
});
test('upstream failure returns explicitly stale bounded data, never renews retrieval date',async()=>{
  const h=harness();await h.request();await Promise.all(h.writes);h.advance(FRESH_SECONDS+1);
  h.deps.upstream=async()=>{throw Error('offline')};
  const old=await h.request();const b=await old.json();
  assert.equal(b.delivery.state,'stale');assert.equal(b.delivery.stale,true);
  assert.equal(b.catalog.retrievedAt,'2026-11-01T00:00:00.000Z');
  h.advance(MAX_STALE_SECONDS);assert.equal((await h.request()).status,502);
});
test('invalid source never populates a cache or exposes raw upstream errors',async()=>{
  const h=harness();h.deps.upstream=async()=>response({...payload(),totalCnt:100});
  const r=await h.request();assert.equal(r.status,502);assert.equal(h.data.size,0);
  assert.equal((await r.json()).error.code,'source_unavailable');
});
test('source limiter returns Retry-After and is not consulted for valid cache hits',async()=>{
  const h=harness();h.env.UPSTREAM_REGION_LIMIT={limit:async()=>({success:false})};
  const limited=await h.request();assert.equal(limited.status,429);assert.equal(limited.headers.get('retry-after'),'60');assert.equal(h.calls,0);
  h.env.UPSTREAM_REGION_LIMIT={limit:async()=>({success:true})};await h.request();await Promise.all(h.writes);
  h.env.UPSTREAM_REGION_LIMIT={limit:async()=>{throw Error('must not call')}};
  assert.equal((await h.request()).status,200);
});
test('same-isolate concurrent source misses share one upstream request',async()=>{
  const h=harness();const run=h.deps.upstream;h.deps.upstream=async(...args)=>{await new Promise(resolve=>setTimeout(resolve,10));return run(...args)};
  const results=await Promise.all([h.request(),h.request(),h.request()]);assert(results.every(r=>r.status===200));assert.equal(h.calls,1);
});
test('cache storage failure does not hide fresh valid data',async()=>{
  const h=harness();h.deps.cache.put=async()=>{throw Error('cache unavailable')};
  assert.equal((await h.request()).status,200);await Promise.all(h.writes);
});
test('normalization preserves entrance, counts exclusions and rejects identity conflict',()=>{
  const entrance={...row(),aot:'테스트 출입구',aotLade:37,aotLami:31,aotLase:30,aotLode:127,aotLomi:1,aotLose:0};
  const c=normalizeCatalog(payload([entrance,entrance,{...row('bad'),facilLase:99}]),'11110',0);
  assert.equal(c.items.length,1);assert.equal(c.skippedCount,2);assert.equal(c.officialCount,3);assert.equal(c.items[0].latitude,37.525);
  assert.throws(()=>normalizeCatalog(payload([row(),{...row(),facilNm:'상충 이름'}]),'11110',0));
  assert.throws(()=>normalizeCatalog({...payload(),facilitiesVO:{...payload().facilitiesVO,sggCd:'26110'}},'11110',0));
  assert.throws(()=>normalizeCatalog(payload([{...row(),facilLade:0}]),'11110',0));
  assert.equal(normalizeCatalog(payload([]),'11110',0).items.length,0);
});
test('bounded upstream body rejects HTML, declared/chunked oversize and invalid UTF-8',async()=>{
  await assert.rejects(boundedJson(new Response('<html>',{headers:{'content-type':'text/html'}})));
  await assert.rejects(boundedJson(new Response('{}',{headers:{'content-type':'application/json','content-length':String(MAX_BYTES+1)}})));
  await assert.rejects(boundedJson(new Response(new Uint8Array(MAX_BYTES+1),{headers:{'content-type':'application/json'}})));
  await assert.rejects(boundedJson(new Response(new Uint8Array([255]),{headers:{'content-type':'application/json'}})));
});

test('upstream redirects are rejected without following another host',async()=>{const h=harness();h.deps.upstream=async()=>new Response(null,{status:302,headers:{Location:'https://other.example'}});assert.equal((await h.request()).status,502);assert.equal(h.data.size,0)});
