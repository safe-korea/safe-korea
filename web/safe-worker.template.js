/* Generated with a content-versioned, same-origin asset allowlist. */
const CACHE = 'safe-korea-pwa-__VERSION__';
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
      if (key.startsWith('safe-korea-pwa-') && key !== CACHE) await caches.delete(key);
    }
    await self.clients.claim();
  })());
});
self.addEventListener('fetch', event => {
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;
  const shell = new URL('index.html', self.registration.scope).href;
  const key = event.request.mode === 'navigate' && url.href.startsWith(self.registration.scope) ? shell : url.href;
  if (!urls.includes(key)) return;
  event.respondWith((async () => (await (await caches.open(CACHE)).match(key)) || fetch(event.request))());
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
