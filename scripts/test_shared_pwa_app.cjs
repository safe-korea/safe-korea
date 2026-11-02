// Exercise the actual shared native app in the browser, including persistence.
const {chromium,webkit}=require('../.tools/pwa-qa/node_modules/playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const origin=process.env.PWA_TEST_URL||'http://127.0.0.1:8766';
const catalog=JSON.parse(fs.readFileSync('assets/offline_maps/jamsil-shelters.json','utf8'));
const station=catalog.items.find(s=>s.name.includes('승강장'));
(async()=>{
 for(const [name,engine] of Object.entries({chromium,webkit})){
  const b=await engine.launch({headless:true});
  let p;
  try{
   const c=await b.newContext({viewport:{width:402,height:874}});
   p=await c.newPage();const errors=[];p.on('pageerror',e=>errors.push(e.message));
   async function ready(){await p.waitForFunction(()=>window.safeFlutterReady===true,null,{timeout:60000});await p.locator('flt-semantics-placeholder').evaluate(e=>e.click());}
   async function restart(){await p.reload();await ready();}
   await p.goto(origin+'/?launch=app');await ready();
   await p.getByText('지금 필요한 안내',{exact:true}).waitFor();
   for(const tab of ['홈','대피소','행동강령','나의 준비'])assert(await p.getByRole('tab',{name:tab,exact:true}).isVisible());
   assert.equal(await p.locator('#onboarding').isVisible(),false);
   await p.screenshot({path:`artifacts/visual-qa/pwa-native-home-${name}.png`}); console.log(name+': native home');
   await p.getByRole('button',{name:'지금 할 행동 보기',exact:true}).click();
   await p.getByRole('button',{name:/받은 경보를 선택하세요/}).click();
   await p.getByRole('menuitem',{name:'공습경보',exact:true}).click();
   await p.getByRole('checkbox',{name:'실내',exact:true}).click();
   await p.getByText('계단으로 이동',{exact:true}).waitFor(); console.log(name+': guidance');
   await restart();
   await p.getByRole('button',{name:'가족 만남 장소',exact:true}).click();
   await p.getByRole('textbox',{name:/첫 번째 만남 장소/}).click();
   await p.waitForTimeout(200); // Flutter attaches its real editing element after focus.
   await p.keyboard.type('QA 가족 약속 · 실제 만남 장소 아님',{delay:15});
   await p.getByRole('button',{name:'기기에 저장',exact:true}).evaluate(e=>e.click());
   await p.waitForFunction(()=>JSON.parse(localStorage.getItem('safekor.local.v1.family')||'{}').meetingPlace==='QA 가족 약속 · 실제 만남 장소 아님');
   await p.getByRole('button',{name:'만남 장소 수정',exact:true}).waitFor();
   console.log(name+': family saved');
   assert.equal(await p.evaluate(()=>JSON.parse(localStorage.getItem('safekor.local.v1.family')).meetingPlace),'QA 가족 약속 · 실제 만남 장소 아님');
   await restart();await p.getByRole('button',{name:'가족 만남 장소',exact:true}).click();
   await p.getByRole('button',{name:'만남 장소 수정',exact:true}).waitFor();
   await p.getByRole('button',{name:'가족에게 공유',exact:true}).click();
   await p.getByText('보낼 장소를 확인하세요.',{exact:true}).waitFor();
   await p.screenshot({path:`artifacts/visual-qa/pwa-family-share-${name}.png`});
   await restart();
   await p.getByRole('button',{name:'비상배낭 체크리스트',exact:true}).click();
   await p.getByRole('checkbox',{name:/생수 · 간편식/}).evaluate(e=>e.click());
   await p.waitForFunction(()=>JSON.parse(localStorage.getItem('safekor.local.v1.preparation')||'[]').includes('water'));
   await restart();await p.getByRole('button',{name:'비상배낭 체크리스트',exact:true}).click();
   assert(await p.getByRole('checkbox',{name:/생수 · 간편식/}).isChecked());
   console.log(name+': checklist persisted');
   await restart();
   await p.evaluate(catalog=>localStorage.setItem('safekor.local.v1.catalog',JSON.stringify(catalog)),catalog);
   await p.getByRole('tab',{name:'대피소',exact:true}).click();
   await p.getByRole('textbox',{name:/시설명 또는 주소 검색/}).click();
   await p.waitForTimeout(150);
   await p.keyboard.type(station.name,{delay:10});
   await p.mouse.move(200,650);await p.mouse.wheel(0,500);await p.waitForTimeout(250);
   await p.getByRole('button',{name:station.name,exact:false}).first().click();
   await p.getByRole('button',{name:'대피소 저장',exact:true}).click();
   await p.waitForFunction(()=>Object.values(JSON.parse(localStorage.getItem('safekor.local.v1.shelters')||'{}')).some(e=>e.offlineMap),null,{timeout:90000});
   await restart();await p.getByRole('button',{name:'저장한 대피소',exact:true}).click();
   await p.getByRole('button',{name:'저장한 주변 지도 보기',exact:true}).waitFor();
   await p.locator('#reopen').click();await p.locator('#prepare').click();
   await p.waitForFunction(()=>document.getElementById('cache-status').dataset.state==='ready',null,{timeout:90000});
   await p.locator('#start').click();
   await c.setOffline(true);await restart();
   await p.getByRole('button',{name:/^저장한 대피소/}).first().click();
   await p.getByRole('button',{name:'저장한 주변 지도 보기',exact:true}).click();
   await p.getByText('저장한 주변 지도',{exact:true}).waitFor();
   await p.getByText(station.name,{exact:true}).waitFor();
   await p.getByRole('button',{name:'지도 확대',exact:true}).click();
   await p.screenshot({path:`artifacts/visual-qa/pwa-stored-map-offline-${name}.png`});
   assert.deepEqual(errors,[]);
   console.log(`${name}: shared native home/tabs, air guidance, family persistence/share preview, checklist persistence, official facility and map saving, cold offline launch and map zoom PASS`);
  }catch(e){if(p){await p.screenshot({path:`artifacts/visual-qa/pwa-shared-failure-${name}.png`}); console.log('failure URL',p.url());}throw e;}finally{await b.close();}
 }
})().catch(e=>{console.error(e);process.exit(1)});
