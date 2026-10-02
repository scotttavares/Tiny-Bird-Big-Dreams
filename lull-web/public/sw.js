const C = 'lull-v110';
const ASSETS = ['/', '/app', '/privacy', '/assets/lull.js', '/assets/orb-glass.webp', '/assets/orb-swirl-b.webp', '/assets/orb-swirl-c.webp', '/assets/orb-swirl-d.webp', '/assets/orb-iris.webp', '/assets/orb-wisp.webp', '/assets/orb-dawn.webp', '/assets/orb-halo.webp', '/assets/orb-prism.webp', '/assets/orb-lagoon.webp', '/assets/orb-dusk.webp', '/assets/orb-seance.webp', '/assets/orb-hallow.mp4', '/assets/orb-hallow.webp', '/assets/orb-thumb-solstice.png', '/assets/orb-thumb-frost.png', '/assets/orb-thumb-nova.png', '/assets/sound-bowls.webp', '/assets/sound-handpan.webp', '/assets/rain.mp3', '/assets/lightrain.wav', '/assets/ocean.wav', '/assets/forest.wav', '/assets/fire.wav', '/manifest.webmanifest', '/icon-192.png', '/icon-512.png', '/apple-touch-icon.png', '/favicon-32.png'];
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
