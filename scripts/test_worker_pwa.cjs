// Requires a PWA on 8766 built with the selected API URL.
const {chromium,webkit}=require('../.tools/pwa-qa/node_modules/playwright');
const assert=require('node:assert/strict');
const origin=process.env.PWA_TEST_URL || 'http://127.0.0.1:8766';
const apiBase=process.env.SHELTER_TEST_API_URL || 'http://127.0.0.1:8787';
(async()=>{
 for(const [name,engine] of Object.entries({chromium,webkit})) {
  const browser=await engine.launch({headless:true});
  try {
   const context=await browser.newContext({viewport:{width:402,height:874}, permissions:['geolocation'], geolocation:{latitude:37.5133,longitude:127.1001,accuracy:10}});
   if(name==='webkit') await context.addInitScript(() => {
     // This installed Playwright WebKit mock returns epoch microseconds rather
     // than Geolocation's milliseconds (observed 1000x Date.now()). Normalize
     // only the test fixture; production must still reject stale/future fixes.
     const original=navigator.geolocation.getCurrentPosition.bind(navigator.geolocation);
     navigator.geolocation.getCurrentPosition=(success,error,options)=>original(position=>{
       const timestamp=position.timestamp>Date.now()*100 ? position.timestamp/1000 : position.timestamp;
       success({coords:position.coords,timestamp});
     },error,options);
   });
   const page=await context.newPage();page.setDefaultTimeout(15000); const errors=[];const requests=[];
   page.on('pageerror',e=>errors.push(e.message));
   page.on('request',r=>{if(r.method()==='GET' && r.url().startsWith(apiBase+'/api/')) requests.push(r.url());});
   await page.goto(origin);
   await page.locator('#quick-start').click();
   await page.waitForFunction(()=>window.safeFlutterReady===true,null,{timeout:60000});
   await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
   await page.getByText('어떤 안내가 필요한가요?',{exact:true}).waitFor();
   await page.waitForTimeout(350);
   console.log(name+': app ready');
   await page.mouse.move(220,650);
   await page.mouse.wheel(0,900);
   await page.waitForTimeout(500);
   await page.getByText('지역별 대피소 찾기',{exact:false}).click();
   console.log(name+': region page');
   assert.equal(requests.length,0);
   const responsePromise=page.waitForResponse(r=>r.request().method()==='GET' && r.url().startsWith(apiBase+'/api/shelters'), {timeout:40000});
   await page.getByRole('button',{name:'GPS 현재 위치 확인',exact:true}).click();
   let response;
   try {response=await responsePromise;} catch(error) {
     await page.screenshot({path:`artifacts/nearby-pwa-${name}-failure.png`});
     console.log(await page.locator('flt-semantics').allTextContents()); throw error;
   }
   assert.equal(response.status(),200);
   const heading=page.getByText(/^서울특별시 송파구 · \d+곳$/);
   await heading.waitFor();
   const count=Number((await heading.innerText()).match(/· (\d+)곳/)[1]);
   assert(count>0);
   await page.waitForTimeout(800);
   await page.screenshot({path:`artifacts/nearby-pwa-${name}.png`});
   await page.locator('[aria-label*="직선거리"]').first().waitFor({state:'attached'});
   await page.screenshot({path:`artifacts/nearby-pwa-${name}.png`});
   await page.mouse.move(220,650);
   await page.mouse.wheel(0,500);
   await page.waitForTimeout(400);
   await page.getByRole('button',{name:'카카오 지도로 열기',exact:true}).first().waitFor();
   await page.locator('[aria-label*="현재 위치에서 직선거리"]').first().waitFor({state:'attached'});
   assert.deepEqual(requests,[apiBase+'/api/shelters?region=11710']);
   await page.waitForTimeout(600);
   await page.screenshot({path:`artifacts/worker-pwa-${name}.png`});
   // Request failure must retain the already displayed catalog with a warning.
   // WebKit may serve a valid HTTP cache while offline; explicitly reject the
   // next API request to exercise the error-retention path deterministically.
   await context.route(apiBase+'/api/shelters*', route => route.abort('internetdisconnected'));
   await context.setOffline(true);
   await page.mouse.wheel(0,-1000);
   await page.waitForTimeout(400);
   const change=page.getByRole('button',{name:'다른 지역 직접 선택',exact:true});
   for(let i=0;i<8 && !(await change.count() && await change.isVisible());i++) {
     await page.mouse.wheel(0,250); await page.waitForTimeout(350);
   }
   await change.evaluate(element=>element.click());
   await page.mouse.wheel(0,400); await page.waitForTimeout(250);
   await page.getByRole('button',{name:'대피소 찾기',exact:true}).evaluate(element=>element.click());
   await page.waitForTimeout(350);
   assert.equal(requests.length,2,'Retry must issue the second regional request');
   await page.getByRole('button',{name:'대피소 찾기',exact:true}).waitFor({timeout:30000});
   await page.mouse.wheel(0,-10000); await page.waitForTimeout(700);
   const warning=page.getByText('새 자료를 확인하지 못했어요. 이전 조회 결과입니다.',{exact:true}).or(page.locator('[aria-label*="새 자료를 확인하지 못했어요"]')).first();
   for(let i=0;i<8 && !(await warning.count() && await warning.isVisible());i++) {
     await page.mouse.wheel(0,250); await page.waitForTimeout(350);
   }
   try {await warning.waitFor({timeout:30000});} catch(error) {
     await page.screenshot({path:`artifacts/nearby-pwa-${name}-failure.png`});
     console.log(await page.locator('flt-semantics').allTextContents()); throw error;
   }
   assert.deepEqual(errors,[]);
   console.log(`${name}: real government ${count} facilities, simulated browser geolocation (WebKit fixture timestamp normalized), on-device distance, regional request only, source metadata, retained results on offline failure PASS`);
  } finally {await browser.close();}
 }
})().catch(e=>{console.error(e);process.exit(1)});
