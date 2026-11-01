/* No permissions, analytics, notifications, or third-party requests on onboarding. */
(() => {
  const $ = id => document.getElementById(id);
  const slides = [
    {
      eyebrow: '비상시, 무엇부터 해야 할지 막막할 때',
      title: '당황스러운 순간,<br>할 일은 <em>또렷하게.</em>',
      description: '공습·화생방 등 비상 상황의 행동요령을\n쉽게 꺼내 보는 비상 대비 앱, SAFE KOREA.',
      benefit: '긴 설명보다, 먼저 할 행동부터',
      image: 'previews/air-guidance.png',
      alt: '실제 공습 안내 화면: 실내를 선택하면 계단으로 이동하는 행동을 먼저 안내합니다.',
      caption: '실제 웹 앱 화면 · 공습 행동요령',
      next: '내 상황에 맞는 안내 보기 →',
    },
    {
      eyebrow: '실내인지, 실외인지에 따라 다르니까',
      title: '내가 있는 곳에 맞춰,<br><em>다음 행동을.</em>',
      description: '실내·실외·이동 중, 내 상황을 선택하세요.\n지금 할 일을 짧고 명확하게 확인할 수 있어요.',
      benefit: '위치 권한 없이, 직접 상황 선택',
      image: 'previews/outdoor-guidance.png',
      alt: '실제 공습 안내 화면: 실외 선택 시 가까운 건물로 대피하라는 안내를 보여줍니다.',
      caption: '실제 웹 앱 화면 · 실외 상황 선택',
      next: '오프라인에서도 볼 수 있나요? →',
    },
    {
      eyebrow: '필요할 때 검색부터 하지 않도록',
      title: '연결이 끊겨도,<br>준비한 안내는 <em>곁에.</em>',
      description: '미리 저장한 행동요령은 인터넷 없이도.\n홈 화면에 두고 필요할 때 바로 꺼내 보세요.',
      benefit: '사전 저장 후 오프라인 이용 · 지도 제외',
      image: 'previews/guidance-list.png',
      alt: '실제 행동요령 목록 화면: 공습·경계·화생방 등 상황별 안내를 선택합니다.',
      caption: '실제 웹 앱 화면 · 상황별 행동요령',
      next: '내 폰에 준비하기 →',
    },
  ];
  let slide = 0;
  const showSlide = index => {
    slide = index;
    $('product-tour').dataset.currentSlide = String(index);
    $('setup').hidden = true;
    $('product-tour').hidden = false;
    const data = slides[index];
    $('tour-eyebrow').textContent = data.eyebrow;
    $('welcome-title').innerHTML = data.title; // Fixed local copy, never user input.
    $('tour-description').textContent = data.description;
    $('tour-benefit').textContent = '✓ ' + data.benefit;
    $('tour-image').src = data.image;
    $('tour-image').alt = data.alt;
    $('preview-caption').textContent = data.caption;
    $('tour-next').textContent = data.next;
    $('tour-back').hidden = index === 0;
    $('tour-count').textContent = '0' + (index + 1) + ' / 03';
    document.querySelectorAll('[data-slide]').forEach(button => {
      if (Number(button.dataset.slide) === index) button.setAttribute('aria-current', 'step');
      else button.removeAttribute('aria-current');
    });
    $('welcome-title').focus({preventScroll:true});
    window.scrollTo(0, 0);
  };
  const showSetup = () => {
    $('product-tour').hidden = true;
    $('setup').hidden = false;
    $('setup-title').focus({preventScroll:true});
    window.scrollTo(0, 0);
  };
  document.querySelectorAll('[data-slide]').forEach(button => {
    button.onclick = () => showSlide(Number(button.dataset.slide));
  });
  $('tour-next').onclick = () => slide < slides.length - 1 ? showSlide(slide + 1) : showSetup();
  $('tour-back').onclick = () => showSlide(Math.max(0, slide - 1));
  $('tour-return').onclick = () => showSlide(0);
  $('preview-open').onclick = () => {
    $('preview-full').src = slides[slide].image;
    $('preview-full').alt = slides[slide].alt;
    $('preview-dialog').showModal();
  };
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
    showSetup();
  };
  try { if (!new URL(location.href).searchParams.has('intro') && localStorage.getItem('safe-korea-onboarding-v1') === 'seen') start(); } catch (_) {}
})();
