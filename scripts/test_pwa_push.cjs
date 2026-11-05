// Browser API fixtures verify UX/bridge, not an Apple device's actual delivery.
const {chromium,webkit}=require('../.tools/pwa-qa/node_modules/playwright');
const {createECDH,randomBytes}=require('node:crypto');
const {readFileSync}=require('node:fs');
const assert=require('node:assert/strict');
const origin=process.env.PWA_TEST_URL||'http://127.0.0.1:8766';
const ec=createECDH('prime256v1');ec.generateKeys();
const point=ec.getPublicKey().toString('base64url');
const provinces=require('../assets/regions.json').provinces.map(({code,name})=>({code,name}));
(async()=>{
 for(const[name,engine]of Object.entries({chromium,webkit})){
  const browser=await engine.launch({headless:true,...(name==='chromium'?{chromiumSandbox:true}:{})});
  try{
   const c=await browser.newContext({viewport:{width:402,height:874},userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1'});
   await c.addInitScript(({point,auth,origin})=>{
    Object.defineProperty(navigator,'standalone',{get:()=>true});
    window.__pushCalls=0;window.__unsubscribed=false;
    if(!window.PushManager)window.PushManager=class{};
    Object.defineProperty(window,'Notification',{configurable:true,value:{permission:'default'}});
    const subscription={endpoint:'https://web.push.apple.com/QA-browser-fixture',toJSON:()=>({endpoint:'https://web.push.apple.com/QA-browser-fixture',keys:{p256dh:point,auth}}),unsubscribe:async()=>{window.__unsubscribed=true;return true}};
    const manager={getSubscription:async()=>window.__pushCalls&&!window.__unsubscribed?subscription:null,subscribe:async options=>{
      if(!navigator.userActivation.isActive)throw Error('subscribe lost the user gesture');
      window.__pushCalls++;Notification.permission='granted';return subscription;
    }};
    Object.defineProperty(ServiceWorkerRegistration.prototype,'pushManager',{get:()=>manager,configurable:true});
   },{point,auth:randomBytes(16).toString('base64url'),origin});
   let registered=false,tests=0,lookups=0,rejectFirstSubscribe=true,noticeType='test',opened=false;
   const fixture=async(url,body)=>{
    const path=new URL(url).pathname.split('/').pop();
    if(path==='subscribe'&&rejectFirstSubscribe){rejectFirstSubscribe=false;return {status:503,value:{error:'try_later'}};}
    let value={};let status=200;
    const config={transportReady:true,publicKey:point,officialEnabled:false,source:{state:'key_required'},regions:[...provinces,{code:'11710',name:'서울특별시 송파구'}]};
    if(path==='config')value=config;
    else if(path==='subscribe'){assert.equal(body.consentVersion,'2026-11-02');assert.equal(body.region,'11');assert(body.capability);registered=true;value={...config,id:'1'.repeat(64)};status=201;}
    else if(path==='status')value={...config,lastTest:tests?{state:'accepted',received_at:opened?1:null,opened_at:opened?2:null}:null};
    else if(path==='test'){assert(registered);tests++;value={state:'accepted',deliveryId:'11111111-1111-4111-8111-111111111111',received:false};status=202;}
    else if(path==='notice'){lookups++;opened ||= body.openedFromNotification===true;value={deliveryId:body.deliveryId,type:noticeType,id:'a'.repeat(64),revision:'b'.repeat(64),kind:'air',publishedAt:Date.now(),expiresAt:Date.now()+90000,agency:'합성 QA 입력 · 실제 발령 아님',area:'합성 QA 지역'};}
    else if(path==='unsubscribe'){registered=false;value={deleted:true};}
    else throw Error(path);
    return {status,value};
   };
   // WebKit service-worker interception does not reliably pass through routing;
   // fixture the browser fetch boundary, without changing production code.
   await c.addInitScript(()=>{
    const original=window.fetch.bind(window);
    window.fetch=(input,options)=>{
     const url=typeof input==='string'?input:(input.url||input.href||String(input));
     if(new URL(url,location.href).pathname.startsWith('/api/push/'))return window.__safeKorPushFixture({url,body:options?.body?JSON.parse(options.body):null}).then(r=>new Response(JSON.stringify(r.value),{status:r.status,headers:{'Content-Type':'application/json'}}));
     return original(input,options);
    };
   });
   const audio=await c.request.get(origin+'/app/audio/drill_siren.wav');
   assert.equal(audio.status(),200);
   assert.deepEqual(await audio.body(),readFileSync('android/app/src/main/res/raw/drill_siren.wav'));
   const p=await c.newPage();
   await p.exposeBinding('__safeKorPushFixture',(_,request)=>fixture(request.url,request.body));const errors=[];p.on('pageerror',e=>errors.push(e.message));
   await p.goto(origin+'/app/');await p.waitForFunction(()=>window.safeFlutterReady===true,null,{timeout:60000});
   await p.locator('flt-semantics-placeholder').evaluate(e=>e.click());
   assert.equal(await p.evaluate(()=>window.__pushCalls),0);
   await p.locator('#push-welcome').waitFor({state:'visible'});
   assert.equal(await p.locator('#push-welcome-source,#push-welcome-status,#push-source').count(),0);
   assert.equal(await p.locator('#push-welcome-error').isVisible(),false);
   assert.equal(await p.locator('#app-shell nav').count(),0);
   await p.locator('#push-welcome-region option[value="11"]').waitFor({state:'attached'});
   assert.equal(await p.locator('#boot-splash').isVisible(),false);
   assert.equal(await p.locator('#push-welcome-region option').count(),provinces.length+1);
   assert.equal(await p.locator('#push-welcome-region option[value="11710"]').count(),0);
   assert.equal(await p.locator('#push-welcome-region option[value="11"]').textContent(),'서울시');
   assert.equal(await p.locator('#push-welcome-region option[value="28"]').textContent(),'인천시');
   assert(await p.locator('#push-welcome-confirm').isDisabled());
   await p.locator('#push-welcome-region').selectOption('11');
   await p.waitForFunction(()=>!document.getElementById('push-welcome-confirm').disabled,null,{timeout:90000});
   await p.screenshot({path:`artifacts/visual-qa/pwa-first-notification-prompt-${name}.png`});
   const spacing=await p.locator('#push-welcome').evaluate(dialog=>{
    const consent=dialog.querySelector('.small').getBoundingClientRect(),confirm=dialog.querySelector('#push-welcome-confirm').getBoundingClientRect(),later=dialog.querySelector('#push-welcome-later').getBoundingClientRect();
    return {consentGap:confirm.top-consent.bottom,buttonGap:later.top-confirm.bottom};
   });
   assert(spacing.consentGap>=19.5);assert(spacing.buttonGap>=11.5);
   await p.setViewportSize({width:320,height:568});
   assert(await p.locator('#push-welcome').evaluate(e=>e.scrollWidth<=e.clientWidth));
   await p.locator('#push-welcome-confirm').scrollIntoViewIfNeeded();
   await p.screenshot({path:`artifacts/visual-qa/pwa-notification-spacing-small-${name}.png`});
   await p.setViewportSize({width:402,height:874});
   await p.locator('#push-welcome-confirm').click();
   await p.locator('#push-welcome-error').getByText('잠시 후 다시 시도하세요.',{exact:true}).waitFor();
   assert.equal(await p.locator('#push-welcome').isVisible(),true);
   await p.locator('#push-welcome-confirm').click();
   await p.getByText('알림 연결 완료',{exact:true}).waitFor();
   assert.equal(await p.evaluate(()=>window.__pushCalls),1);assert(registered);
   assert.equal(await p.locator('#push-welcome').isVisible(),false);
   await p.screenshot({path:`artifacts/visual-qa/pwa-clean-header-${name}.png`});
   await p.getByRole('tab',{name:'나의 준비',exact:true}).click();
   await p.getByRole('button',{name:'알림 설정',exact:true}).click();
   await p.locator('#push-panel').waitFor({state:'visible'});
   await p.locator('#push-test-sound').check();
   await p.locator('#push-test').click();await p.getByText('Apple 서버가 접수했어요. 앱을 닫고 알림을 확인하세요.',{exact:true}).waitFor();assert.equal(tests,1);
   await p.locator('#push-close').click();
   async function notify(script,activation='foreground',deliveryId='11111111-1111-4111-8111-111111111111'){await p.evaluate(({scriptURL,activation,deliveryId})=>{const e=new Event('message');Object.defineProperties(e,{source:{value:{scriptURL}},data:{value:{type:'SAFEKOR_OPEN_NOTICE',deliveryId,activation}}});navigator.serviceWorker.dispatchEvent(e);},{scriptURL:script,activation,deliveryId});}
   await notify('https://evil.test/app/safe-worker.js');assert.equal(lookups,0);
   await notify(origin+'/app/safe-worker.js');
   await p.getByText('테스트 중 · 실제 경보 아님',{exact:true}).waitFor();
   await p.getByText('지금 즉시 대피하세요',{exact:true}).waitFor();
   assert.equal(opened,false);assert.equal(await p.locator('#push-panel').isVisible(),false);
   await p.waitForFunction(()=>window.safeKorTestSiren.isPlaying());
   await p.getByRole('button',{name:'소리 끄기',exact:true}).click();
   assert.equal(await p.evaluate(()=>window.safeKorTestSiren.isPlaying()),false);
   await p.getByRole('button',{name:'사이렌 듣기',exact:true}).click();
   await p.waitForFunction(()=>window.safeKorTestSiren.isPlaying());
   await p.getByRole('button',{name:'소리 끄기',exact:true}).click();
   await p.locator('#push-feedback').waitFor({state:'hidden'});
   await p.waitForTimeout(500);
   await p.screenshot({path:`artifacts/visual-qa/pwa-test-response-${name}.png`});
   await p.getByRole('button',{name:'뒤로',exact:true}).click();
   await notify(origin+'/app/safe-worker.js','notificationclick','22222222-2222-4222-8222-222222222222');
   await p.getByText('테스트 중 · 실제 경보 아님',{exact:true}).waitFor();
   assert.equal(opened,true);
   // A new app document receives only the opaque notice ID; authenticated lookup
   // must wait for the Flutter bridge before opening the same test response.
   await p.goto(origin+'/app/?notice=33333333-3333-4333-8333-333333333333');
   await p.waitForFunction(()=>window.safeFlutterReady===true,null,{timeout:60000});
   await p.locator('flt-semantics-placeholder').evaluate(e=>e.click());
   await p.getByText('테스트 중 · 실제 경보 아님',{exact:true}).waitFor();
   assert.equal(new URL(p.url()).searchParams.has('notice'),false);
   await p.getByRole('button',{name:'뒤로',exact:true}).click();noticeType='civil';
   await notify(origin+'/app/safe-worker.js');
   await p.getByText('지금 즉시 대피하세요',{exact:true}).waitFor();assert.equal(lookups,4);
   await p.getByRole('checkbox',{name:'실내',exact:true}).click();await p.getByText('계단으로 이동',{exact:true}).waitFor();
   await p.screenshot({path:`artifacts/visual-qa/pwa-push-response-${name}.png`});
   await p.getByRole('button',{name:'뒤로',exact:true}).click();
   await p.getByRole('tab',{name:'나의 준비',exact:true}).click();
   await p.getByRole('button',{name:'알림 설정',exact:true}).click();await p.locator('#push-disable').click();await p.getByText('이 기기의 알림을 끄고 서버 등록을 삭제했어요.',{exact:true}).waitFor();
   assert.equal(registered,false);assert.equal(await p.evaluate(()=>localStorage.getItem('safekor.push.registration.v1')),null);
   await p.reload();await p.waitForFunction(()=>window.safeFlutterReady===true,null,{timeout:60000});
   assert.equal(await p.locator('#push-welcome').isVisible(),false);
   await p.evaluate(()=>localStorage.removeItem('safekor.push.welcome.v1'));
   await p.reload();await p.locator('#push-welcome').waitFor({state:'visible',timeout:60000});
   await p.locator('#push-welcome-later').click();assert.equal(await p.evaluate(()=>window.__pushCalls),0);
   await p.reload();await p.waitForFunction(()=>window.safeFlutterReady===true,null,{timeout:60000});
   assert.equal(await p.locator('#push-welcome').isVisible(),false);
   assert.deepEqual(errors,[]);
   console.log(`${name}: no automatic permission request; explicit region/consent + gesture subscribe; own-device red test response (foreground, tap and cold launch); forged source rejected; authenticated synthetic notice opens response/indoor actions; unsubscribe/deletion PASS (browser API fixtures)`);
  }finally{await browser.close();}
 }
})().catch(e=>{console.error(e);process.exit(1)});
