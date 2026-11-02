// Requires a PWA on 8766 built with the selected API URL.
const {chromium,webkit}=require('../.tools/pwa-qa/node_modules/playwright');
const assert=require('node:assert/strict');
const apiBase=process.env.SHELTER_TEST_API_URL || 'http://127.0.0.1:8787';
(async()=>{
 for(const [name,engine] of Object.entries({chromium,webkit})) {
  const browser=await engine.launch({headless:true});
  try {
   const context=await browser.newContext({viewport:{width:402,height:874}});
   const page=await context.newPage();page.setDefaultTimeout(15000); const errors=[];const requests=[];
   page.on('pageerror',e=>errors.push(e.message));
   page.on('request',r=>{if(r.url().startsWith(apiBase+'/api/')) requests.push(r.url());});
   await page.goto('http://127.0.0.1:8766');
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
   await page.getByText('시·도',{exact:true}).click();
   await page.waitForTimeout(500);
   await page.getByRole('menuitem',{name:'서울특별시',exact:true}).click();
   console.log(name+': province selected');
   await page.getByText('시·군·구',{exact:true}).click();
   console.log(name+': districts shown');
   await page.getByRole('menuitem',{name:'중구',exact:true}).click();
   const responsePromise=page.waitForResponse(r=>r.url().startsWith(apiBase+'/api/shelters'));
   await page.getByText('대피소 찾기',{exact:true}).click();
   const response=await responsePromise;assert.equal(response.status(),200);
   const data=await response.json();assert(data.catalog.items.length>0);
   await page.getByText(`서울특별시 중구 · ${data.catalog.items.length}곳`,{exact:true}).waitFor();
   await page.mouse.move(220,650);
   await page.mouse.wheel(0,500);
   await page.waitForTimeout(400);
   await page.getByRole('button',{name:'카카오 지도로 열기',exact:true}).first().waitFor();
   assert.deepEqual(requests,[apiBase+'/api/shelters?region=11140']);
   await page.waitForTimeout(600);
   await page.screenshot({path:`artifacts/worker-pwa-${name}.png`});
   // Request failure must retain the already displayed catalog with a warning.
   await context.setOffline(true);
   await page.mouse.wheel(0,-1000);
   await page.waitForTimeout(400);
   await page.getByText('대피소 찾기',{exact:true}).click();
   await page.getByText('새 자료를 확인하지 못했어요. 이전 조회 결과입니다.',{exact:true}).waitFor();
   assert.deepEqual(errors,[]);
   console.log(`${name}: real government ${data.catalog.items.length} facilities, regional request only, source metadata, retained results on offline failure PASS`);
  } finally {await browser.close();}
 }
})().catch(e=>{console.error(e);process.exit(1)});
