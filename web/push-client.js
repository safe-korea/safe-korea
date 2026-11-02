/* Opt-in iPhone Web Push. No notification permission request on page load. */
(() => {
  'use strict';
  const $=id=>document.getElementById(id), key='safekor.push.registration.v1';
  const panel=$('push-panel'), status=$('push-status'), source=$('push-source'), welcome=$('push-welcome');
  const promptKey='safekor.push.welcome.v1';
  let offered=false;
  let config,credential, registration, browserSubscription, pending=new URL(location.href).searchParams.get('notice');
  let busy=false,receiptTimer,ready=typeof window.safeKorPushReceiver==='function';
  const initial=new URL(location.href);initial.searchParams.delete('notice');history.replaceState(null,'',initial.pathname+initial.search+initial.hash);
  const installed=()=>matchMedia('(display-mode: standalone)').matches||navigator.standalone===true;
  const appleDevice=()=>/iPad|iPhone|iPod/.test(navigator.userAgent)||(navigator.platform==='MacIntel'&&navigator.maxTouchPoints>1);
  const appleBrowser=()=>appleDevice()||(/^Apple/.test(navigator.vendor)&&!/Chrome|Chromium|Edg|OPR/.test(navigator.userAgent));
  const supported=()=>appleBrowser()&&isSecureContext&&'serviceWorker'in navigator&&'PushManager'in window&&'Notification'in window;
  const store=value=>{localStorage.setItem(key,JSON.stringify(value));if(localStorage.getItem(key)!==JSON.stringify(value))throw Error('storage_failed');credential=value;};
  try{credential=JSON.parse(localStorage.getItem(key)||'null');}catch{}
  const explain={setup_required:'서버 연결을 준비 중입니다.',apple_subscription_required:'현재 iPhone·Safari의 Apple 알림 연결을 지원합니다.',registration_missing:'등록을 다시 확인해야 해요. 이 기기에서 다시 연결하세요.',different_registration:'이전 등록을 확인하지 못했어요. 연결을 끄고 다시 등록하세요.',try_later:'잠시 후 다시 시도하세요.',test_wait:'테스트는 1분 뒤 다시 보낼 수 있어요.',notice_expired:'지난 알림입니다. 최신 재난문자·정부 안내를 확인하세요.'};
  function message(value,error=false){status.textContent=value;status.dataset.state=error?'error':'ready';}
  async function api(path,body){
    const response=await fetch(new URL('../api/push/'+path,document.baseURI),{method:body?'POST':'GET',headers:body?{'Content-Type':'application/json'}:{},body:body?JSON.stringify(body):undefined,cache:'no-store',credentials:'omit'});
    const value=await response.json();if(!response.ok)throw Error(explain[value.error]||'연결하지 못했어요. 인터넷을 확인하고 다시 시도하세요.');return value;
  }
  const own=extra=>({...credential,...extra});
  function publicState(value){
    source.textContent=value.officialEnabled&&value.source?.complete&&Date.now()-value.source.checkedAt<5*60*1000
      ?'선택 지역의 민방공 경보를 확인합니다. API·통신 상황에 따라 늦거나 누락될 수 있어요.'
      :value.source?.state==='source_ip_denied'?'정부 API의 서버 접근 승인 대기 · 테스트 알림은 가능해요.':'알림 전달을 테스트할 수 있어요. 정부 경보 자동 연동은 아직 운영 검증 중입니다.';
  }
  function controls(){
    $('push-enable').disabled=busy||!config?.transportReady||!$('push-consent').checked||!$('push-region').value||!supported()||!registration?.active||(appleDevice()&&!installed());
    $('push-test').hidden=!credential?.id;$('push-disable').hidden=!credential?.id;$('push-refresh').hidden=!credential?.id;
    $('push-welcome-confirm').disabled=busy||!config?.transportReady||!$('push-welcome-region').value||!supported()||!registration?.active;
    $('push-test').disabled=busy||(typeof Notification!=='undefined'&&Notification.permission!=='granted');$('push-disable').disabled=busy;
  }
  async function refresh(){
    if(!config){config=await api('config');publicState(config);
      for(const region of config.regions||[]){const option=document.createElement('option');option.value=region.code;option.textContent=region.name;$('push-region').append(option);}
    }
    if(supported()){
      const started=Date.now();
      do{
        registration=await navigator.serviceWorker.getRegistration(document.baseURI);
        if(registration?.scope!==new URL('./',document.baseURI).href)registration=null;
        if(registration?.active)break;
        await new Promise(resolve=>setTimeout(resolve,100));
      }while(Date.now()-started<60000);
    }
    if(registration?.pushManager)browserSubscription=await registration.pushManager.getSubscription();
    if(credential?.region)$('push-region').value=credential.region;
    if(credential?.id){
      const value=await api('status',own());publicState(value);
      const r=value.lastTest;
      if(r?.received_at)message(r.opened_at?'테스트 알림 수신·열기 확인 완료':'이 기기에서 테스트 알림 표시를 확인했어요.');
      else if(r?.state==='accepted')message('Apple 서버가 접수했어요. 잠금 화면 알림을 확인하세요.');
      else message('알림 등록 완료 · 테스트 알림으로 전달을 확인하세요.');
    }else if(!supported())message('이 브라우저는 알림 연결을 지원하지 않아요. 홈 화면에 추가한 iPhone 앱에서 열어주세요.');
    else if(appleDevice()&&!installed())message('먼저 홈 화면에 추가한 뒤 그 아이콘으로 열어주세요.');
    else if(Notification.permission==='denied')message('알림이 차단되어 있어요. 기기 설정에서 safeKor 알림을 허용하세요.');
    else message('지역을 선택하고 동의한 뒤 알림을 연결하세요.');
    if(typeof Notification!=='undefined'&&Notification.permission==='denied')message('기기 설정에서 safeKor 알림을 허용해야 수신할 수 있어요.',true);
    controls();
  }
  window.safeKorOpenPushSettings=()=>{welcome.close();panel.showModal();refresh().catch(e=>{message(e.message,true);controls();});};
  $('push-close').onclick=()=>panel.close();
  $('push-consent').onchange=controls;$('push-region').onchange=controls;
  const connect=async(region,fromWelcome=false)=>{
    if(busy)return;
    busy=true;
    try{
      if(Notification.permission==='denied')throw Error('기기 설정에서 safeKor 알림을 허용한 뒤 다시 연결하세요.');
      const capability=credential?.capability||btoa(String.fromCharCode(...crypto.getRandomValues(new Uint8Array(32)))).replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'');
      store({...credential,capability,region});
      if(!registration?.active)throw Error('앱 준비 중입니다. 잠시 뒤 다시 눌러주세요.');
      const publicKey=Uint8Array.from(atob(config.publicKey.replace(/-/g,'+').replace(/_/g,'/')),c=>c.charCodeAt(0));
      // subscribe is called directly during the user gesture, before any await.
      // Safari itself requests notification permission when it is necessary.
      const subscribing=browserSubscription?Promise.resolve(browserSubscription):registration.pushManager.subscribe({userVisibleOnly:true,applicationServerKey:publicKey});
      controls();
      const subscription=await subscribing;browserSubscription=subscription;
      const result=await api('subscribe',{capability,region:credential.region,consentVersion:'2026-11-02',subscription:subscription.toJSON()});
      store({...credential,id:result.id});publicState(result);message('알림 등록 완료 · 테스트 알림을 보내 확인하세요.');
      if(fromWelcome){dismissWelcome();const toast=$('push-feedback');toast.textContent='알림 연결 완료';toast.hidden=false;setTimeout(()=>toast.hidden=true,3500);}
    }catch(e){message(e.message,true);if(fromWelcome)$('push-welcome-status').textContent=e.message;}finally{busy=false;controls();}
  };
  $('push-enable').onclick=()=>connect($('push-region').value);
  function dismissWelcome(){offered=true;try{localStorage.setItem(promptKey,'decided');}catch{}welcome.close();}
  $('push-welcome-later').onclick=dismissWelcome;
  welcome.addEventListener('cancel',()=>{try{localStorage.setItem(promptKey,'decided');}catch{}});
  $('push-welcome-region').onchange=()=>{controls();$('push-welcome-status').textContent=$('push-welcome-region').value?'확인을 누르면 iPhone 알림 허용으로 이어집니다.':'처음 한 번 알림을 받을 지역을 선택하세요.';};
  $('push-welcome-confirm').onclick=()=>connect($('push-welcome-region').value,true);
  async function offerWelcome(){
    let decided=false;try{decided=localStorage.getItem(promptKey)==='decided';}catch{return;}
    if(offered||decided||!navigator.onLine||!installed()||!supported()||credential?.id||pending||Notification.permission==='denied')return;
    offered=true;welcome.showModal();
    try{
      await refresh();
      const selector=$('push-welcome-region');
      for(const region of config.regions||[]){const option=document.createElement('option');option.value=region.code;option.textContent=region.name;selector.append(option);}
      let suggested=credential?.region;
      try{suggested ||= JSON.parse(localStorage.getItem('safekor.local.v1.catalog')||'null')?.areaCode;}catch{}
      if(config.regions.some(r=>r.code===suggested))selector.value=suggested;
      $('push-welcome-source').textContent=config.officialEnabled?'':'정부 경보 연동 준비 중 · 테스트 알림 연결 가능';
      $('push-welcome-status').textContent=selector.value?'확인을 누르면 iPhone 알림 허용으로 이어집니다.':'처음 한 번 알림을 받을 지역을 선택하세요.';
    }catch{ $('push-welcome-status').textContent='인터넷 연결 후 나의 준비 → 알림 설정에서 연결할 수 있어요.'; }
    controls();
  }
  $('push-test').onclick=async()=>{
    if(busy)return;busy=true;controls();
    try{const result=await api('test',own());message(result.state==='accepted'?'Apple 서버가 접수했어요. 앱을 닫고 알림을 확인하세요.':'알림 전달을 확인하지 못했어요.',result.state!=='accepted');
      clearInterval(receiptTimer);let tries=0;receiptTimer=setInterval(()=>{refresh().catch(()=>{});if(++tries>=15)clearInterval(receiptTimer);},2000);
    }catch(e){message(e.message,true);}finally{busy=false;controls();}
  };
  $('push-refresh').onclick=()=>refresh().catch(e=>message(e.message,true));
  $('push-disable').onclick=async()=>{
    if(busy)return;busy=true;controls();
    try{
      const r=await navigator.serviceWorker.getRegistration(document.baseURI);await (await r?.pushManager.getSubscription())?.unsubscribe();
      await api('unsubscribe',own());localStorage.removeItem(key);credential=null;clearInterval(receiptTimer);
      message('이 기기의 알림을 끄고 서버 등록을 삭제했어요.');
    }catch(e){message('알림 해제·서버 삭제를 모두 확인하지 못했어요. 연결 후 다시 눌러주세요.',true);}finally{busy=false;controls();}
  };
  async function openNotice(id){
    if(!/^[a-f0-9-]{36}$/.test(id)||!credential?.id)return;
    try{
      const value=await api('notice',own({deliveryId:id}));
      if(value.type==='test'){panel.showModal();message('테스트 알림을 열었어요. 실제 경보는 아닙니다.');return;}
      if(value.type!=='civil'||!ready){pending=id;return;}
      welcome.close();panel.close();window.safeKorShowApp?.();window.safeKorPushReceiver?.(JSON.stringify(value));
    }catch(e){panel.showModal();message(e.message,true);}
  }
  window.safeKorPushReady=()=>{ready=true;if(pending){const id=pending;pending=null;openNotice(id);}else offerWelcome();};
  navigator.serviceWorker?.addEventListener('message',e=>{
    if(!e.source?.scriptURL||new URL(e.source.scriptURL).origin!==location.origin||!new URL(e.source.scriptURL).pathname.endsWith('/app/safe-worker.js'))return;
    if(e.data?.type==='SAFEKOR_OPEN_NOTICE')openNotice(e.data.deliveryId);
  });
  document.addEventListener('visibilitychange',()=>{if(!document.hidden&&panel.open)refresh().catch(()=>{});});
  controls();
  if(ready&&!pending)queueMicrotask(offerWelcome);
})();
