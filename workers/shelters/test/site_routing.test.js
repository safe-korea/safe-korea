import test from 'node:test';
import assert from 'node:assert/strict';
import {routeSite} from '../src/site_routing.js';

test('asset routing cannot swallow API errors or health requests',async()=>{
  const assets={fetch:async()=>new Response('asset')};
  for(const path of ['/health','/api','/api/shelters','/api/missing']){
    const r=await routeSite(new Request('https://app.example'+path),assets,async()=>new Response('api'));
    assert.equal(await r.text(),'api');
  }
  assert.equal(await (await routeSite(new Request('https://app.example/'),assets,async()=>new Response('api'))).text(),'asset');
});
test('static POST is rejected and missing assets preserve API-only mode',async()=>{
  let count=0;
  const assets={fetch:async()=>{count++;return new Response('asset')}};
  assert.equal((await routeSite(new Request('https://app.example/',{method:'POST'}),assets,async()=>new Response('api'))).status,405);
  assert.equal(count,0);
  assert.equal(await (await routeSite(new Request('https://app.example/'),undefined,async()=>new Response('api'))).text(),'api');
});
