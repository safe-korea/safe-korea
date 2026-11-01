const {chromium,webkit}=require('../.tools/pwa-qa/node_modules/playwright');
const assert=require('node:assert/strict');
const base=process.env.PUBLIC_INFO_BASE || 'http://127.0.0.1:8787';
(async()=>{
 for(const [name,engine] of Object.entries({chromium,webkit})) {
  const browser=await engine.launch({headless:true});
  try {
   const context=await browser.newContext({viewport:{width:360,height:800}});
   const page=await context.newPage();const external=[];
   page.on('request',r=>{if(!r.url().startsWith(base))external.push(r.url());});
   for(const route of ['/privacy','/support']) {
    const r=await page.goto(base+route);assert.equal(r.status(),200);
    await page.getByRole('heading',{level:1}).waitFor();
    assert(await page.locator('body').textContent().then(t=>t.includes('safeKor')));
    assert(await page.locator('a[href="mailto:taetaeg@gmail.com"]').count()>0);
    assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
    await page.addStyleTag({content:'body{font-size:25.5px}'});
    assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
    await page.screenshot({path:`artifacts/public-${route.slice(1)}-${name}.png`,fullPage:true});
    assert.equal(await page.locator('script,form,input,iframe').count(),0);
   }
   assert.deepEqual(external,[]);assert.deepEqual(await context.cookies(),[]);
   console.log(`${name}: ${base} policy/contact HTTP200, confirmed operator/email, narrow/large text, no extra requests/cookies PASS`);
  } finally {await browser.close();}
 }
})().catch(e=>{console.error(e);process.exit(1)});
