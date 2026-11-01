/* No permissions, analytics, notifications, or third-party requests on onboarding. */
(() => {
  const $ = id => document.getElementById(id);
  const standalone = matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;
  if (standalone) {
    $('install-summary').textContent = '홈 화면 앱으로 열었어요.';
    $('install-help').hidden = true;
  }
  $('install-help').onclick = () => {
    const expanded = $('install-help').getAttribute('aria-expanded') !== 'true';
    $('install-help').setAttribute('aria-expanded', String(expanded));
    $('install-detail').hidden = !expanded;
  };
  const status = (message, state = '') => {
    $('cache-status').textContent = message;
    $('cache-status').dataset.state = state;
  };
  const workerCheck = (worker, type = 'VERIFY_OFFLINE') => new Promise((resolve, reject) => {
    const channel = new MessageChannel();
    const timer = setTimeout(() => reject(Error('timeout')), 10000);
    channel.port1.onmessage = event => { clearTimeout(timer); channel.port1.close(); resolve(event.data); };
    worker.postMessage({type}, [channel.port2]);
  });
  $('prepare').onclick = async () => {
    $('prepare').disabled = true;
    status('앱과 행동요령을 저장하고 있어요. 잠시 기다려 주세요.');
    let cachedReady = false;
    try {
      if (!isSecureContext || !('serviceWorker' in navigator)) throw Error('unsupported');
      const existing = await navigator.serviceWorker.getRegistration();
      if (existing?.active) cachedReady = (await workerCheck(existing.active)).ready;
      if (cachedReady) status('저장된 안내를 확인했어요. 새 버전도 확인하고 있어요.', 'ready');
      const registration = await navigator.serviceWorker.register('safe-worker.js', {updateViaCache:'none'});
      await registration.update();
      const ready = await Promise.race([navigator.serviceWorker.ready, new Promise((_, reject) => setTimeout(() => reject(Error('timeout')), 60000))]);
      let result = await workerCheck(ready.active);
      if (!result.ready) result = await workerCheck(ready.active, 'REPAIR_OFFLINE');
      if (!result.ready) throw Error('incomplete');
      status(registration.waiting ? '기존 안내는 저장되어 있어요. 새 버전 적용은 이 앱의 모든 창을 닫은 뒤 다시 열어 주세요.' : '오프라인 안내 저장 완료 · 지도는 인터넷이 필요해요.', 'ready');
      $('prepare').textContent = '저장 상태 다시 확인';
    } catch (_) {
      if (cachedReady) {
        status('기존 오프라인 안내를 확인했어요. 새 버전 확인은 인터넷 연결 후 다시 해주세요.', 'ready');
        return;
      }
      status('저장을 완료하지 못했어요. 인터넷·저장공간을 확인하고 다시 시도하세요. 행동요령은 바로 볼 수 있어요.', 'error');
      $('prepare').textContent = '저장 다시 시도';
    } finally { $('prepare').disabled = false; }
  };
  let loaded = false;
  const start = () => {
    $('onboarding').hidden = true;
    $('app-shell').hidden = false;
    try { localStorage.setItem('safe-korea-onboarding-v1','seen'); } catch (_) { /* Continue without persistence. */ }
    if (!loaded) {
      loaded = true;
      const script = document.createElement('script');
      script.src = 'flutter_bootstrap.js';
      script.onerror = () => { $('boot-error').hidden = false; };
      document.body.append(script);
      setTimeout(() => { if (!window.safeFlutterReady) $('boot-error').hidden = false; }, 45000);
    }
  };
  $('start').onclick = start;
  $('quick-start').onclick = start;
  $('retry').onclick = () => location.reload();
  $('reopen').onclick = () => {
    $('onboarding').hidden = false;
    $('app-shell').hidden = true;
    $('welcome-title').focus();
  };
  try { if (localStorage.getItem('safe-korea-onboarding-v1') === 'seen') start(); } catch (_) {}
})();
