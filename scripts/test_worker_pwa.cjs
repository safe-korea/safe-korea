// Requires a PWA on 8766 built with the selected API URL.
const {chromium,webkit}=require('../.tools/pwa-qa/node_modules/playwright');
const assert=require('node:assert/strict');
const origin=process.env.PWA_TEST_URL || 'http://127.0.0.1:8766';
const apiBase=process.env.SHELTER_TEST_API_URL || 'http://127.0.0.1:8787';
(async()=>{
 for(const [name,engine] of Object.entries({chromium,webkit})) {
  if(process.env.PWA_TEST_ENGINE && process.env.PWA_TEST_ENGINE!==name)continue;
  const browser=await engine.launch({headless:true});
  let page;
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
   page=await context.newPage();page.setDefaultTimeout(15000); const errors=[];const requests=[];
   page.on('pageerror',e=>errors.push(e.message));
   page.on('request',r=>{if(r.method()==='GET' && r.url().startsWith(apiBase+'/api/')) requests.push(r.url());});
   await page.goto(origin+'/app/');
   await page.waitForFunction(()=>window.safeFlutterReady===true,null,{timeout:60000});
   await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
   await page.getByText('지금 필요한 안내',{exact:true}).waitFor();
   await page.getByRole('tab',{name:'대피소',exact:true}).click();
   assert.equal(requests.length,0);
   const responsePromise=page.waitForResponse(r=>r.request().method()==='GET' && r.url().startsWith(apiBase+'/api/shelters'), {timeout:40000});
   await page.getByRole('button',{name:'GPS 현재 위치 확인',exact:true}).click();
   let response;
   try {response=await responsePromise;} catch(error) {
     await page.screenshot({path:`artifacts/nearby-pwa-${name}-failure.png`});
     console.log(await page.locator('flt-semantics').allTextContents()); throw error;
   }
   assert.equal(response.status(),200);
   await page.waitForFunction(()=>localStorage.getItem('safekor.local.v1.catalog')!==null);
   const catalog=await page.evaluate(()=>JSON.parse(localStorage.getItem('safekor.local.v1.catalog')));
   const count=catalog.items.length;
   assert(count>0);
   await page.getByText('서울특별시 송파구 내 가까운 대피소',{exact:true}).waitFor();
   const expected=[...catalog.items].sort((a,b)=>{
     const dist=s=>Math.hypot((s.latitude-37.5133)*111000,(s.longitude-127.1001)*88000);
     return dist(a)-dist(b);
   }).slice(0,3);
   for(const facility of expected) await page.getByRole('button',{name:facility.name,exact:false}).first().waitFor();
   assert.deepEqual(requests,[apiBase+'/api/shelters?region=11710']);
   await page.screenshot({path:`artifacts/nearby-pwa-${name}.png`});
   assert.equal(await page.evaluate(()=>JSON.parse(localStorage.getItem('safekor.local.v1.catalog')).items.length),count);
   // Use a fresh HTTP cache for the failure fixture. WebKit can validly serve
   // a recently fetched catalog without reaching the intercepted network.
   await context.close();
   const failure=await browser.newContext({viewport:{width:402,height:874},permissions:['geolocation'],geolocation:{latitude:37.5133,longitude:127.1001,accuracy:10}});
   if(name==='webkit') await failure.addInitScript(()=>{
     const original=navigator.geolocation.getCurrentPosition.bind(navigator.geolocation);
     navigator.geolocation.getCurrentPosition=(success,error,options)=>original(p=>success({coords:p.coords,timestamp:p.timestamp>Date.now()*100?p.timestamp/1000:p.timestamp}),error,options);
   });
   await failure.route(apiBase+'/api/shelters*', route => route.abort('internetdisconnected'));
   // WebKit service-worker requests can bypass Playwright routing. Reject at
   // the browser fetch boundary in this explicit failure fixture as well.
   await failure.addInitScript(api=>{
     const original=window.fetch.bind(window);
     window.fetch=(input,options)=>{
       const url=typeof input==='string'?input:input.url;
       if(url.startsWith(api+'/api/shelters')) return Promise.reject(new TypeError('QA simulated network failure'));
       return original(input,options);
     };
   },apiBase);
   page=await failure.newPage();page.on('pageerror',e=>errors.push(e.message));
   await page.goto(origin+'/app/');
   await page.waitForFunction(()=>window.safeFlutterReady===true,null,{timeout:60000});
   await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
   await page.evaluate(catalog=>localStorage.setItem('safekor.local.v1.catalog',JSON.stringify(catalog)),catalog);
   await page.getByRole('tab',{name:'대피소',exact:true}).click();
   await page.getByRole('button',{name:'GPS 현재 위치 확인',exact:true}).click();
   await page.waitForFunction(()=>Array.from(document.querySelectorAll('flt-semantics,[aria-label]')).some(e=>(e.textContent+' '+e.getAttribute('aria-label')).includes('현재 지역의 새 자료를 불러오지 못했어요')),null,{timeout:30000});
   assert.equal(await page.evaluate(()=>JSON.parse(localStorage.getItem('safekor.local.v1.catalog')).items.length),count);
   assert.deepEqual(errors,[]);
   console.log(`${name}: real government ${count} facilities, simulated browser geolocation (WebKit fixture timestamp normalized), on-device distance, regional request only, saved catalog retained on failed regional request PASS`);
  } catch(e) { console.log(name+' failed: '+e.message); if(page) { console.log(await page.locator('flt-semantics').allTextContents()); await page.screenshot({path:`artifacts/nearby-pwa-${name}-failure.png`}); } throw e; } finally {await browser.close();}
 }
})().catch(e=>{console.error(e);process.exit(1)});
