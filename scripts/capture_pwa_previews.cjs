// Product screenshots from an isolated browser; no user records or drill inputs.
const {webkit}=require('../.tools/pwa-qa/node_modules/playwright');
const fs=require('node:fs');
(async()=>{const b=await webkit.launch();try{
 const c=await b.newContext({viewport:{width:402,height:874},deviceScaleFactor:3,isMobile:true,userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1'});
 const p=await c.newPage();await p.goto('http://127.0.0.1:8766/app/');
 await p.waitForFunction(()=>window.safeFlutterReady===true,null,{timeout:60000});
 // Leave the same content-safe area used in a portrait iPhone product frame.
 await p.addStyleTag({content:'#app-shell{padding-top:62px;padding-bottom:34px}'});
 await p.locator('flt-semantics-placeholder').evaluate(e=>e.click());
 const capture=async name=>{await p.waitForTimeout(650);await p.screenshot({path:`web/previews/${name}.png`});};
 await capture('app-home');
 await p.getByRole('button',{name:'지금 할 행동 보기',exact:true}).click();
 await p.getByRole('button',{name:/받은 경보를 선택하세요/}).click();
 await p.getByRole('menuitem',{name:'공습경보',exact:true}).click();
 await p.getByRole('checkbox',{name:'실내',exact:true}).click();await p.getByText('계단으로 이동',{exact:true}).waitFor();await capture('air-guidance');
 await p.getByRole('checkbox',{name:'실외',exact:true}).click();await p.getByText('가까운 건물로 대피',{exact:true}).waitFor();await capture('outdoor-guidance');
 await p.getByRole('button',{name:'뒤로',exact:true}).click();await p.getByRole('tab',{name:'행동강령',exact:true}).click();await capture('guidance-list');
 console.log('Updated four 1206x2622 product previews from the current app.');
}finally{await b.close();}})().catch(e=>{console.error(e);process.exit(1)});
