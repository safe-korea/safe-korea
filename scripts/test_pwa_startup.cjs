// Hold the runtime: the app brand must render before Flutter, without fake progress.
// Capture the visible system-font splash while unrelated font downloads wait.
process.env.PW_TEST_SCREENSHOT_NO_FONTS_READY='1';
const {chromium,webkit}=require('../.tools/pwa-qa/node_modules/playwright');
const assert=require('node:assert/strict');
const origin=process.env.PWA_TEST_URL||'http://127.0.0.1:8766';
(async()=>{
 for(const[name,engine]of Object.entries({chromium,webkit})){
  const browser=await engine.launch({headless:true});
  try{
   const context=await browser.newContext({viewport:{width:402,height:874},reducedMotion:'reduce',serviceWorkers:'block'});
   const page=await context.newPage();
   let resume;const waiting=new Promise(resolve=>resume=resolve);
   await page.route('**/flutter_bootstrap.js',async route=>{await waiting;await route.continue();});
   await page.goto(origin+'/app/',{waitUntil:'domcontentloaded'});
   const splash=page.locator('#boot-splash');await splash.waitFor({state:'visible'});
   const launchLink=page.locator('link[rel="apple-touch-startup-image"][media*="402px"]');
   assert.equal(await launchLink.count(),1);
   const launch=await page.request.get(await launchLink.evaluate(e=>e.href));
   assert(launch.ok());const png=await launch.body();
   assert.equal(png.readUInt32BE(16),1206);assert.equal(png.readUInt32BE(20),2622);
   assert.equal(await splash.locator('strong').textContent(),'safeKor');
   await page.waitForFunction(()=>{const i=document.querySelector('#boot-splash img');return i.complete&&i.naturalWidth>0;});
   assert.equal(await page.evaluate(()=>window.safeFlutterReady),undefined);
   assert.equal(await page.locator('.boot-spinner').evaluate(e=>getComputedStyle(e).animationName),'none');
   await page.screenshot({path:`artifacts/visual-qa/pwa-brand-startup-${name}.png`});
   resume();await page.waitForFunction(()=>window.safeFlutterReady===true,null,{timeout:60000});
   assert.equal(await splash.isVisible(),false);
   assert.equal(await page.locator('#boot-error').isVisible(),false);
   console.log(`${name}: brand/icon visible while runtime delayed; reduced motion; splash removed on first Flutter frame PASS`);
   await context.close();
  }finally{await browser.close();}
 }
})().catch(e=>{console.error(e);process.exit(1)});
