const {chromium,webkit}=require('../.tools/pwa-qa/node_modules/playwright');
const assert=require('node:assert/strict');
const origin=process.env.PWA_TEST_URL||'http://127.0.0.1:8766';
(async()=>{
 for(const[name,engine]of Object.entries({chromium,webkit})){
  const browser=await engine.launch({headless:true});
  try{
   for(const url of ['/','/?intro=1','/intro/']){
    const context=await browser.newContext({viewport:{width:402,height:874}});
    await context.addInitScript(()=>localStorage.setItem('safe-korea-onboarding-v1','seen'));
    const page=await context.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
    await page.goto(origin+url);await page.locator('#onboarding').waitFor({state:'visible'});
    assert.equal(new URL(page.url()).pathname,new URL(origin+url).pathname);
    assert.equal(await page.locator('#app-shell').count(),0);
    await page.reload();await page.locator('#onboarding').waitFor({state:'visible'});
    await page.locator('#quick-start').click();await page.locator('#setup').waitFor({state:'visible'});
    await page.locator('#start').click();assert(await page.locator('#install-detail').isVisible());
    assert.equal(await page.locator('#app-shell').count(),0);
    assert.equal(new URL(page.url()).pathname,new URL(origin+url).pathname);
    await page.screenshot({path:`artifacts/visual-qa/pwa-marketing-${name}-${url==='/intro/'?'intro':url==='/'?'root':'query'}.png`,fullPage:true});
    assert.deepEqual(errors,[]);await context.close();
   }
   const context=await browser.newContext({viewport:{width:402,height:874}});
   await context.addInitScript(()=>{
    Object.defineProperty(navigator,'standalone',{get:()=>true});
    Storage.prototype.getItem=()=>{throw Error('storage unavailable')};
    Storage.prototype.setItem=()=>{throw Error('storage unavailable')};
   });
   const page=await context.newPage();
   const manifest=await(await page.request.get(origin+'/manifest.json')).json();
   assert.equal(new URL(manifest.start_url,origin+'/manifest.json').pathname,'/app/');
   await page.goto(new URL(manifest.start_url,origin+'/manifest.json').href);
   await page.waitForFunction(()=>window.safeFlutterReady===true,null,{timeout:60000});
   await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
   await page.getByText('지금 필요한 안내',{exact:true}).waitFor();
   assert.equal(await page.locator('#onboarding').count(),0);
   await page.reload();await page.waitForFunction(()=>window.safeFlutterReady===true,null,{timeout:60000});
   assert.equal(await page.locator('#onboarding').count(),0);
   await page.locator('#reopen').click();assert(await page.locator('#setup').isVisible());
   await context.close();
   console.log(`${name}: marketing stays on intro after previous visit/reload/install-help clicks; manifest-installed launch/relaunch opens actual app with blocked storage PASS`);
  }finally{await browser.close();}
 }
})().catch(e=>{console.error(e);process.exit(1)});
