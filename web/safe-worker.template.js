/* Generated with a content-versioned, same-origin asset allowlist. */
const CACHE_PREFIX = 'safe-korea-pwa-' + encodeURIComponent(new URL(self.registration.scope).pathname) + '-';
const CACHE = CACHE_PREFIX + '__VERSION__';
const FILES = __FILES__;
const urls = Object.keys(FILES).map(file => new URL(file, self.registration.scope).href);
self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    try { await cache.addAll(urls.map(url => new Request(url, {cache:'reload'}))); }
    catch (error) { await caches.delete(CACHE); throw error; }
    // No skipWaiting: an open app must not change version underneath the user.
  })());
});
self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    for (const key of await caches.keys()) {
      if (key.startsWith(CACHE_PREFIX) && key !== CACHE) await caches.delete(key);
    }
    await self.clients.claim();
  })());
});
self.addEventListener('fetch', event => {
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;
  const shell = new URL('index.html', self.registration.scope).href;
  const navigation = event.request.mode === 'navigate';
  const appShell = new URL('app/index.html', self.registration.scope).href;
  const isApp = url.pathname === new URL('app/', self.registration.scope).pathname || url.pathname === new URL(appShell).pathname;
  const entry = isApp || url.pathname === new URL(self.registration.scope).pathname || url.pathname === new URL(shell).pathname;
  // Policy/API/unknown routes must never be replaced by the app shell.
  if (navigation && !entry) return;
  const key = navigation ? (isApp ? appShell : shell) : url.href;
  if (!urls.includes(key)) return;
  event.respondWith((async () => {
    const cached = await (await caches.open(CACHE)).match(key);
    // Hosts may redirect index.html to /. A redirected cached response cannot
    // satisfy a navigation with redirect mode manual; return its verified body.
    if (cached && navigation) return new Response(cached.body, {status:cached.status, headers:cached.headers});
    return cached || fetch(event.request);
  })());
});
self.addEventListener('message', event => {
  if (!['VERIFY_OFFLINE','REPAIR_OFFLINE'].includes(event.data?.type) || !event.ports[0]) return;
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    if (event.data.type === 'REPAIR_OFFLINE') {
      try {
        for (const [file, expected] of Object.entries(FILES)) {
          const url = new URL(file, self.registration.scope).href;
          if (await cache.match(url)) continue;
          const response = await fetch(url, {cache:'reload'});
          if (!response.ok) throw Error('download');
          const hash = Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', await response.clone().arrayBuffer())), byte => byte.toString(16).padStart(2,'0')).join('');
          if (hash !== expected) throw Error('version changed');
          await cache.put(url,response);
        }
      } catch (_) { event.ports[0].postMessage({ready:false,version:CACHE}); return; }
    }
    const results = await Promise.all(urls.map(url => cache.match(url)));
    event.ports[0].postMessage({ready:results.every(Boolean),version:CACHE});
  })());
});

// Web Push must display a notification. Never handle silent pushes or arbitrary URLs.
self.addEventListener('push',event=>{
  event.waitUntil((async()=>{
    let data;try{data=event.data.json();}catch{}
    const valid=data?.protocolVersion===1&&['civil','test'].includes(data.type)&&/^[a-f0-9-]{36}$/.test(data.deliveryId)&&Number.isFinite(data.expiresAt)&&data.expiresAt>Date.now()&&data.expiresAt<=Date.now()+150000;
    const title=valid?(data.type==='test'?'safeKor · 테스트 알림':'safeKor · 민방공 경보 안내'):'safeKor · 알림 확인';
    const body=valid?(data.type==='test'?'실제 경보가 아닙니다. 알림을 눌러 전달을 확인하세요.':'경보 내용을 확인하고 지금 할 행동을 보세요.'):'지난 알림이거나 내용을 확인하지 못했어요. 최신 정부 안내를 확인하세요.';
    await self.registration.showNotification(title,{body,icon:new URL('../icons/icon-192.png',self.registration.scope).href,tag:valid?data.deliveryId:'safeKor-check',data:valid?{deliveryId:data.deliveryId}:{},requireInteraction:false});
    if(valid){
      const windows=await self.clients.matchAll({type:'window',includeUncontrolled:false});
      for(const c of windows)if(c.visibilityState==='visible'&&new URL(c.url).origin===self.location.origin&&new URL(c.url).pathname.startsWith('/app/'))c.postMessage({type:'SAFEKOR_OPEN_NOTICE',deliveryId:data.deliveryId});
    }
    if(valid&&typeof data.receiptToken==='string'){
      try{await fetch(new URL('../api/push/receipt',self.registration.scope),{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({deliveryId:data.deliveryId,receiptToken:data.receiptToken}),credentials:'omit'});}catch{}
    }
  })());
});
self.addEventListener('notificationclick',event=>{
  event.notification.close();
  event.waitUntil((async()=>{
    const id=event.notification.data?.deliveryId;
    const app=new URL(self.registration.scope);
    // Root landing workers never receive a subscription, but preserve a fixed app route.
    if(!app.pathname.endsWith('/app/'))app.pathname=app.pathname.replace(/\/?$/,'/')+'app/';
    const windows=await self.clients.matchAll({type:'window',includeUncontrolled:true});
    const current=windows.find(c=>new URL(c.url).origin===app.origin&&new URL(c.url).pathname.startsWith(app.pathname));
    if(current){await current.focus();if(id)current.postMessage({type:'SAFEKOR_OPEN_NOTICE',deliveryId:id});return;}
    if(id)app.searchParams.set('notice',id);
    await self.clients.openWindow(app.href);
  })());
});
