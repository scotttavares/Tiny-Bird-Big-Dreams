const C = 'lull-v2';
const ASSETS = ['/', '/app', '/privacy', '/assets/lull.js', '/manifest.webmanifest', '/icon-192.png', '/icon-512.png', '/apple-touch-icon.png', '/favicon-32.png'];
self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(C).then((c) => c.addAll(ASSETS)).then(() => self.skipWaiting()).catch(() => {}));
});
self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys().then((ks) => Promise.all(ks.map((k) => k === C ? null : caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  if (req.mode === 'navigate') {
    e.respondWith(
      fetch(req).then((resp) => { const c = resp.clone(); caches.open(C).then((ch) => ch.put(req, c)); return resp; })
        .catch(() => caches.match(req).then((r) => r || caches.match('/app')))
    );
    return;
  }
  e.respondWith(
    caches.match(req).then((r) => r || fetch(req).then((resp) => { const c = resp.clone(); caches.open(C).then((ch) => ch.put(req, c)); return resp; }))
  );
});
