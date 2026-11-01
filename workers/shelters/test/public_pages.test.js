import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {publicPage} from '../src/public_pages.js';
const pages={'/privacy':readFileSync(new URL('../public/privacy.html',import.meta.url),'utf8'),'/support':readFileSync(new URL('../public/support.html',import.meta.url),'utf8')};
test('policy and contact are public Korean HTML with confirmed identity and no scripts or forms',async()=>{
 for(const [path,html] of Object.entries(pages)) {
  const r=publicPage(new Request('https://api.example'+path,{headers:{Origin:'https://any.example'}}),pages);
  assert.equal(r.status,200);assert.match(r.headers.get('content-type'),/text\/html/);
  const body=await r.text();assert.equal(body,html);assert.match(body,/safeKor/);assert.match(body,/taetaeg@gmail.com/);assert.match(body,/lang="ko"/);
  assert.doesNotMatch(body,/<script|<form|\{\{|TODO|OPERATOR_NAME/i);
  assert.match(r.headers.get('content-security-policy'),/default-src 'none'/);assert.equal(r.headers.get('set-cookie'),null);
 }
});
test('HEAD, trailing slash and unsupported methods preserve API route isolation',async()=>{
 const r=publicPage(new Request('https://api.example/privacy/',{method:'HEAD'}),pages);assert.equal(r.status,200);assert.equal(await r.text(),'');
 assert.equal(publicPage(new Request('https://api.example/privacy',{method:'POST'}),pages).status,405);
 assert.equal(publicPage(new Request('https://api.example/api/shelters?region=11140'),pages),null);
});
