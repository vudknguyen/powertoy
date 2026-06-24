/* powertoy service worker.
   Strategy:
   - The page (index.html) is NETWORK-FIRST: when online you always get the latest
     version automatically, and the fresh copy is cached. When offline, the last
     cached copy is served. => auto-update with no version bumping.
   - Static assets (icons, manifest) are STALE-WHILE-REVALIDATE: served instantly
     from cache, refreshed in the background.
   Bump CACHE only if you change this file's own logic. */
const CACHE = 'powertoy-v3';
const ASSETS = [
  './',
  './index.html',
  './manifest.webmanifest',
  './icon-192.png',
  './icon-512.png',
  './icon-maskable-512.png',
];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(ASSETS)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET' || new URL(req.url).origin !== self.location.origin) return;

  const isDoc = req.mode === 'navigate' || req.destination === 'document';
  if (isDoc) {
    // network-first → fresh app whenever online; cached app when offline.
    // {cache:'no-store'} bypasses the browser HTTP cache so an updated index.html
    // is always picked up (otherwise a stale cached copy could be served).
    e.respondWith(
      fetch(req, { cache: 'no-store' })
        .then(res => { const copy = res.clone(); caches.open(CACHE).then(c => c.put('./index.html', copy)); return res; })
        .catch(() => caches.match(req).then(hit => hit || caches.match('./index.html')))
    );
  } else {
    // stale-while-revalidate → instant from cache, refreshed in background
    e.respondWith(
      caches.match(req).then(hit => {
        const net = fetch(req)
          .then(res => { if (res.ok) { const copy = res.clone(); caches.open(CACHE).then(c => c.put(req, copy)); } return res; })
          .catch(() => hit);
        return hit || net;
      })
    );
  }
});
