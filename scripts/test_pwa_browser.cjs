// Install development dependency under .tools/pwa-qa; never ships with the app.
const {chromium, webkit} = require('../.tools/pwa-qa/node_modules/playwright');
const assert = require('node:assert/strict');
const origin = process.env.PWA_TEST_URL || 'http://127.0.0.1:8765';
(async () => {
  for (const [name, engine] of Object.entries({chromium, webkit})) {
    const browser = await engine.launch({headless:true});
    try {
      const context = await browser.newContext({viewport:{width:390,height:844}, deviceScaleFactor:1});
      const page = await context.newPage();
      const errors = [], external = [];
      page.on('pageerror', e => errors.push(e.message));
      page.on('request', r => {if (!r.url().startsWith(origin) && /^https?:/.test(r.url())) external.push(r.url());});
      await page.goto(origin);
      await page.locator('.tour-mascot').evaluate(image => image.decode());
      const mascot = await page.locator('.tour-mascot').boundingBox();
      const phone = await page.locator('#preview-open').boundingBox();
      assert(mascot.width > 0 && mascot.x + mascot.width <= phone.x, 'Mascot must not cover the app preview');
      assert.equal(await page.locator('.tour-mascot').getAttribute('alt'), '');
      // Show product value and real screenshots before asking the user to install.
      for (let slide = 0; slide < 3; slide++) {
        assert.equal(await page.locator('[data-slide][aria-current="step"]').count(), 1);
        await page.waitForFunction(() => { const image = document.getElementById('tour-image'); return image.complete && image.naturalWidth > 0; });
        const geometry = await page.locator('#tour-image').evaluate(image => ({width:image.naturalWidth,height:image.naturalHeight,ratio:image.clientWidth/image.clientHeight}));
        assert.equal(geometry.width,1206);
        assert.equal(geometry.height,2622);
        assert(Math.abs(geometry.ratio - 1206/2622) < .005, 'iPhone 17 Pro image must retain its full aspect ratio');
        await page.locator('#preview-open').click();
        assert(await page.locator('#preview-dialog').isVisible());
        assert.equal(await page.locator('#preview-full').getAttribute('src'),await page.locator('#tour-image').getAttribute('src'));
        await page.getByRole('button',{name:'닫기',exact:true}).click();
        if (slide === 1) {
          await page.locator('#tour-back').click();
          assert.equal(await page.locator('#tour-count').textContent(),'01 / 03');
          await page.locator('#tour-next').click();
        }
        await page.screenshot({path:`artifacts/pwa-${name}-intro-${slide+1}.png`,fullPage:true});
        await page.locator('#tour-next').click();
      }
      assert(await page.locator('#setup').isVisible());
      await page.getByRole('button',{name:'추가하는 방법 보기'}).click();
      assert.equal(await page.locator('#install-help').getAttribute('aria-expanded'),'true');
      assert(await page.locator('#install-detail').isVisible());
      await page.getByRole('button',{name:'추가하는 방법 보기'}).click();
      assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
      await page.screenshot({path:`artifacts/pwa-${name}-onboarding.png`,fullPage:true});
      await page.locator('#prepare').click();
      await page.waitForFunction(() => document.getElementById('cache-status').dataset.state === 'ready', {timeout:90000});
      await page.screenshot({path:`artifacts/pwa-${name}-saved.png`,fullPage:true});
      await page.locator('#start').click();
      await page.waitForFunction(() => window.safeFlutterReady === true, {timeout:60000});
      await page.locator('flt-semantics-placeholder').evaluate(element => element.click());
      await page.getByText('어떤 안내가 필요한가요?',{exact:true}).waitFor();
      await page.waitForTimeout(350);
      await page.screenshot({path:`artifacts/pwa-${name}-guidance.png`});
      await page.locator('#reopen').click();
      assert(await page.locator('#onboarding').isVisible());
      // Simulate browser eviction of one resource and verify a retry repairs it.
      await page.evaluate(async () => {
        const name = (await caches.keys()).find(n => n.startsWith('safe-korea-pwa-'));
        await (await caches.open(name)).delete(new URL('assets/assets/guidelines.json',location.href));
      });
      await page.locator('#prepare').click();
      await page.waitForFunction(() => document.getElementById('cache-status').dataset.state === 'ready');
      assert(await page.evaluate(async () => {
        const name = (await caches.keys()).find(n => n.startsWith('safe-korea-pwa-'));
        return !!(await (await caches.open(name)).match(new URL('assets/assets/guidelines.json',location.href)));
      }));
      await page.locator('#start').click();
      // A complete offline reload must start the Dart app and render its Korean UI.
      await context.setOffline(true);
      await page.reload();
      await page.waitForFunction(() => window.safeFlutterReady === true, {timeout:60000});
      await page.locator('flt-semantics-placeholder').evaluate(element => element.click());
      await page.getByText('오프라인 행동요령', {exact:true}).waitFor();
      assert.equal(await page.getByText('지역별 대피소 찾기', {exact:true}).count(), 0);
      await page.getByText('공습경보 가까운 대피시설로 이동하세요', {exact:true}).click();
      await page.getByRole('checkbox', {name:'실내',exact:true}).click();
      await page.getByText('계단으로 이동', {exact:true}).waitFor();
      assert.equal(await page.getByRole('checkbox',{name:'실내',exact:true}).isChecked(),true);
      assert(await page.getByRole('button',{name:'선택 초기화',exact:true}).isEnabled());
      await page.waitForTimeout(350); // Capture after the selection transition.
      await page.screenshot({path:`artifacts/pwa-${name}-offline-detail.png`});
      await page.getByRole('button', {name:'뒤로'}).click();
      await page.getByText('어떤 안내가 필요한가요?',{exact:true}).waitFor();
      await page.waitForTimeout(350);
      await page.screenshot({path:`artifacts/pwa-${name}-offline.png`});
      assert.equal(await page.locator('#boot-error').isVisible(),false);
      await page.locator('#reopen').click();
      await page.locator('#prepare').click();
      await page.waitForFunction(() => !document.getElementById('prepare').disabled);
      assert.equal(await page.locator('#cache-status').getAttribute('data-state'),'ready');
      assert(external.every(url => url === 'https://safe-korea-shelter-api.trovapp.workers.dev/health'), 'Only the configured service health check may leave the local origin: ' + JSON.stringify(external));
      assert.deepEqual(errors,[], 'Browser runtime errors');
      await context.close();
      // Failed storage must remain retryable; skipping must not depend on permissions.
      const failure = await browser.newContext({viewport:{width:320,height:700}});
      await failure.addInitScript(() => {
        Storage.prototype.setItem = function(){ throw new DOMException('Blocked','QuotaExceededError'); };
        if ('serviceWorker' in navigator) navigator.serviceWorker.register = async () => { throw Error('test registration failure'); };
      });
      const p = await failure.newPage();
      await p.goto(origin);
      await p.evaluate(() => document.documentElement.style.fontSize = '34px');
      for (let slide=0; slide<3; slide++) {
        if (slide === 0) await p.screenshot({path:`artifacts/pwa-${name}-intro-large-text.png`,fullPage:true});
        assert(await p.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
        await p.locator('#tour-next').click();
      }
      await p.locator('#prepare').click();
      await p.waitForFunction(() => document.getElementById('cache-status').dataset.state === 'error');
      assert.equal(await p.locator('#prepare').isDisabled(),false);
      await p.evaluate(() => document.documentElement.style.fontSize = '34px');
      assert(await p.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
      await p.screenshot({path:`artifacts/pwa-${name}-large-text.png`,fullPage:true});
      await p.locator('#start').click();
      await p.waitForFunction(() => window.safeFlutterReady === true, {timeout:60000});
      assert.equal(await p.locator('#boot-error').isVisible(),false);
      await failure.close();
      // Wide and landscape layouts, and skipping the tour before any install action.
      for (const viewport of [{width:1280,height:900},{width:568,height:320}]) {
        const preview = await browser.newContext({viewport});
        const tour = await preview.newPage();
        await tour.goto(origin);
        assert(await tour.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
        await tour.screenshot({path:`artifacts/pwa-${name}-intro-${viewport.width}.png`,fullPage:true});
        await tour.locator('#quick-start').click();
        await tour.waitForFunction(() => window.safeFlutterReady === true);
        await tour.locator('#reopen').click();
        await tour.locator('#tour-return').click();
        assert(await tour.locator('#product-tour').isVisible());
        await preview.close();
      }
      const installed = await browser.newContext();
      await installed.addInitScript(() => Object.defineProperty(navigator,'standalone',{value:true}));
      const installedPage = await installed.newPage();
      await installedPage.goto(origin);
      await installedPage.waitForFunction(() => window.safeFlutterReady === true);
      assert.equal(await installedPage.locator('#onboarding').isVisible(),false);
      await installedPage.locator('#reopen').click();
      assert.equal(await installedPage.locator('#install-help').isVisible(),false);
      assert.equal(await installedPage.locator('#install-summary').innerText(),'홈 화면 앱으로 열었어요.');
      await installed.close();
      console.log(`${name}: 3-slide product tour, screenshot zoom, back/skip, mobile/desktop/landscape, install help, cache verification, offline reload/detail, cache repair, health-only external requests, storage failure, skip, standalone detection, responsive layout PASS`);
    } finally { await browser.close(); }
  }
})().catch(error => {console.error(error);process.exitCode=1;});
