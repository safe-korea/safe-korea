// The application has its own runtime directory and worker scope. Existing
// landing-page workers cannot return a different application bundle here.
(() => {
  const $=id=>document.getElementById(id);
  try { localStorage.setItem('safe-korea-onboarding-v1','seen'); } catch (_) {}
  const showApp=()=>{ $('setup').hidden=true; $('app-shell').hidden=false; };
  $('reopen').onclick=()=>{ $('app-shell').hidden=true; $('setup').hidden=false; };
  $('start').onclick=showApp;
  $('tour-return').textContent='← 앱으로 돌아가기';
  $('tour-return').onclick=showApp;
  $('install-summary').textContent='홈 화면 앱으로 열면 이 앱 화면이 바로 나타납니다.';
  if (matchMedia('(display-mode: standalone)').matches || navigator.standalone === true) {
    $('install-summary').textContent='홈 화면 앱으로 열었어요.';
    $('install-help').hidden=true;
  }
  $('install-help').onclick=()=>{
    const expanded=$('install-help').getAttribute('aria-expanded')!=='true';
    $('install-help').setAttribute('aria-expanded',String(expanded));
    $('install-detail').hidden=!expanded;
  };
  $('retry').onclick=()=>location.reload();
  navigator.serviceWorker?.getRegistration(new URL('../',document.baseURI)).then(r=>r?.update()).catch(()=>{});
  const register=async()=>{
    if(!('serviceWorker' in navigator) || !isSecureContext) throw Error('unsupported');
    const existing=await navigator.serviceWorker.getRegistration(document.baseURI);
    if(existing?.active && existing.scope===new URL('./',document.baseURI).href){ existing.update().catch(()=>{}); return existing; }
    const r=await navigator.serviceWorker.register(new URL('safe-worker.js',document.baseURI),{updateViaCache:'none'});
    await r.update().catch(()=>{});
    return await new Promise((resolve,reject)=>{
      const started=Date.now();const check=()=>{
        if(r.active)resolve(r);else if(Date.now()-started>60000)reject(Error('timeout'));else setTimeout(check,100);
      };check();
    });
  };
  const checkWorker=(worker,type)=>new Promise((resolve,reject)=>{
    const channel=new MessageChannel();const timer=setTimeout(()=>reject(Error('timeout')),60000);
    channel.port1.onmessage=e=>{clearTimeout(timer);channel.port1.close();resolve(e.data);};
    worker.postMessage({type},[channel.port2]);
  });
  $('prepare').onclick=async()=>{
    $('prepare').disabled=true;$('cache-status').textContent='앱과 행동요령 저장 상태를 확인하고 있어요.';
    try{
      const r=await register();let result=await checkWorker(r.active,'VERIFY_OFFLINE');
      if(!result.ready)result=await checkWorker(r.active,'REPAIR_OFFLINE');
      if(!result.ready)throw Error('incomplete');
      $('cache-status').dataset.state='ready';$('cache-status').textContent='오프라인 안내 저장 완료';
    }catch(_){$('cache-status').dataset.state='error';$('cache-status').textContent='저장하지 못했어요. 인터넷·저장공간을 확인하고 다시 시도하세요.';}
    finally{$('prepare').disabled=false;}
  };
  register().catch(()=>{});
})();
