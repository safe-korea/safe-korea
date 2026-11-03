import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFileSync} from 'node:fs';
function audio({blocked=false,missing=false,failed=false}={}){
  const events={},sources=[],requests=[];
  const context={state:'suspended',destination:{},resume:async()=>{if(!blocked)context.state='running';},decodeAudioData:async()=>({duration:8}),createBufferSource:()=>{
    const s={connect(){},start(){s.started=true;},stop(){s.stopped=true;}};sources.push(s);return s;
  }};
  const window={AudioContext:missing?undefined:function(){return context;},addEventListener:(n,f)=>events[n]=f};
  const document={hidden:false,baseURI:'https://app.test/app/',addEventListener:(n,f)=>events[n]=f};
  vm.runInNewContext(readFileSync(new URL('../../../web/test-siren.js',import.meta.url),'utf8'),{window,document,URL,Date,Promise,fetch:async u=>{requests.push(u.href);return {ok:!failed,arrayBuffer:async()=>new ArrayBuffer(1)};}});
  return {window,document,events,sources,requests,api:window.safeKorTestSiren};
}
test('test siren uses the fixed native WAV, plays once, and can be stopped',async()=>{
  const a=audio();assert.equal(a.sources.length,0);
  assert.equal(await a.window.safeKorPlayTestSiren(),true);
  assert.deepEqual(a.requests,['https://app.test/app/audio/drill_siren.wav']);
  assert.equal(a.api.isPlaying(),true);
  a.window.safeKorStopTestSiren();assert.equal(a.sources[0].stopped,true);assert.equal(a.api.isPlaying(),false);
});
test('only an armed test can play automatically; hidden or backgrounded app never starts audio',async()=>{
  const a=audio();await a.api.prepare();
  assert.equal(a.api.onNotice({type:'test'}),false);
  a.api.arm(true);assert.equal(a.api.onNotice({type:'civil'}),false);
  assert.equal(a.api.onNotice({type:'test'}),true);
  assert.equal(a.api.onNotice({type:'test'}),false);
  a.document.hidden=true;a.events.visibilitychange();assert.equal(a.api.isPlaying(),false);
  a.api.arm(true);assert.equal(a.api.onNotice({type:'test'}),false);
  assert.equal(a.sources.length,1);
});
test('blocked autoplay, unsupported audio and missing file are recoverable',async()=>{
  for(const option of [{blocked:true},{missing:true},{failed:true}]){
    const a=audio(option);assert.equal(await a.window.safeKorPlayTestSiren(),false);assert.equal(a.sources.length,0);
  }
});
test('closing the page stops playback and stopping cancels an in-flight start',async()=>{
  const a=audio();const pending=a.window.safeKorPlayTestSiren();a.window.safeKorStopTestSiren();
  assert.equal(await pending,false);assert.equal(a.sources.length,0);
  await a.window.safeKorPlayTestSiren();a.events.pagehide();assert.equal(a.api.isPlaying(),false);
});
