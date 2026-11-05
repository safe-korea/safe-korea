// Check actual HTML border geometry, not Flutter semantics wrappers.
const {chromium,webkit}=require('../.tools/pwa-qa/node_modules/playwright');
const assert=require('node:assert/strict');
const origin=process.env.PWA_TEST_URL||'http://127.0.0.1:8766';
(async()=>{for(const[name,engine]of Object.entries({chromium,webkit})){
 const browser=await engine.launch();
 try{
  for(const width of [320,402,844]){
   const page=await browser.newPage({viewport:{width,height:width===844?390:874}});
   await page.goto(origin+'/intro/');await page.locator('#quick-start').click();
   const verify=async()=>{
    const g=await page.locator('#setup').evaluate(setup=>{
     const cards=[...setup.querySelectorAll('.step')],rects=cards.map(e=>e.getBoundingClientRect());
     return {overflow:document.documentElement.scrollWidth>innerWidth,gaps:rects.slice(1).map((r,i)=>r.top-rects[i].bottom),controls:cards.flatMap(card=>[...card.querySelectorAll('button')].filter(e=>!e.closest('[hidden]')).map(e=>{const p=card.getBoundingClientRect(),b=e.getBoundingClientRect();return {left:b.left-p.left,right:p.right-b.right,height:b.height};}))};
    });
    assert(!g.overflow);assert(g.gaps.every(x=>x>=15.5));
    for(const b of g.controls){assert(b.left>=19.5);assert(Math.abs(b.left-b.right)<1);assert(b.height>=48);}
   };
   await verify();
   if(width===402)await page.screenshot({path:`artifacts/visual-qa/spacing-after-install-${name}.png`,fullPage:true});
   await page.evaluate(()=>document.documentElement.style.fontSize='34px');await verify();
   if(width===320)await page.screenshot({path:`artifacts/visual-qa/spacing-large-text-${name}.png`,fullPage:true});
   await page.close();
  }
  const app=await browser.newPage({viewport:{width:402,height:874}});
  await app.goto(origin+'/app/');await app.waitForFunction(()=>window.safeFlutterReady===true,null,{timeout:60000});
  await app.evaluate(()=>window.safeKorOpenInstallSettings());
  const bounds=await app.locator('#setup').boundingBox();
  assert(bounds.x>=19.5);assert(bounds.x+bounds.width<=382.5);
  await app.screenshot({path:`artifacts/visual-qa/spacing-after-app-install-${name}.png`,fullPage:true});
  await app.close();
  console.log(`${name}: 320/402/844px, 200% text, card gaps >=16px, balanced button insets, 48px controls and no horizontal overflow PASS`);
 }finally{await browser.close();}
}})().catch(e=>{console.error(e);process.exit(1)});
