const {chromium, webkit} = require('../.tools/pwa-qa/node_modules/playwright');
const assert = require('node:assert/strict');
const origin = process.env.PWA_TEST_URL || 'http://127.0.0.1:8766';
(async () => {
  for (const [name, engine] of Object.entries({chromium, webkit})) {
    const browser = await engine.launch({headless:true});
    try {
      for (const mode of ['browser', 'installed', 'manifest']) {
        const context = await browser.newContext({viewport:{width:402,height:874}});
        if (mode === 'installed') await context.addInitScript(() => {
          Object.defineProperty(navigator, 'standalone', {get: () => true});
          Storage.prototype.getItem = () => { throw new Error('storage unavailable'); };
          Storage.prototype.setItem = () => { throw new Error('storage unavailable'); };
        });
        const page = await context.newPage();
        const errors=[]; page.on('pageerror', e => errors.push(e.message));
        await page.goto(origin + (mode === 'manifest' ? '/?launch=app' : '/?intro=1'));
        if (mode === 'browser') {
          assert(await page.locator('#onboarding').isVisible());
          assert.equal(await page.locator('#app-shell').isVisible(), false);
          // Emulate a home-screen shortcut saving the current URL before the
          // tour is completed. New install storage and standalone detection are
          // deliberately absent, as on a plain iOS home-screen bookmark.
          const savedUrl=page.url();
          assert(new URL(savedUrl).pathname.endsWith('/app/'));
          assert.equal(new URL(savedUrl).searchParams.has('intro'),false);
          const installed=await browser.newContext({viewport:{width:402,height:874}});
          await installed.addInitScript(()=>{
            Storage.prototype.getItem=()=>{throw Error('new install storage')};
            Storage.prototype.setItem=()=>{throw Error('new install storage')};
          });
          const home=await installed.newPage();
          await home.goto(savedUrl);
          await home.waitForFunction(()=>window.safeFlutterReady===true,null,{timeout:60000});
          assert.equal(await home.locator('#onboarding').isVisible(),false);
          await home.locator('flt-semantics-placeholder').evaluate(e=>e.click());
          await home.getByText('지금 필요한 안내',{exact:true}).waitFor();
          await home.reload();
          await home.waitForFunction(()=>window.safeFlutterReady===true,null,{timeout:60000});
          assert.equal(await home.locator('#onboarding').isVisible(),false);
          await home.locator('flt-semantics-placeholder').evaluate(e=>e.click());
          await home.getByText('지금 필요한 안내',{exact:true}).waitFor();
          await home.screenshot({path:`artifacts/visual-qa/pwa-saved-intro-link-${name}.png`});
          await installed.close();
        } else {
          await page.waitForFunction(() => window.safeFlutterReady === true,null,{timeout:60000});
          assert.equal(await page.locator('#onboarding').isVisible(), false);
          assert(await page.locator('#app-shell').isVisible());
          await page.locator('#reopen').click();
          assert(await page.locator('#setup').isVisible());
          await page.reload();
          await page.waitForFunction(() => window.safeFlutterReady === true,null,{timeout:60000});
          assert.equal(await page.locator('#onboarding').isVisible(), false);
          await page.screenshot({path:`artifacts/pwa-launch-${name}-${mode}.png`});
        }
        assert.deepEqual(errors,[]);
        await context.close();
      }
      console.log(`${name}: first-slide saved URL opens real app with fresh/blocked storage and no standalone detection; installed/manifest launch, relaunch, manual setup PASS`);
    } finally {await browser.close();}
  }
})().catch(e => {console.error(e);process.exit(1);});
