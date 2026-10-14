// sw.js — Service Worker برای PWA
const CACHE_NAME = 'private-chat-v1';
const CORE_FILES = [
  './',
  './index.html',
  './chat.html',
  './css/style.css',
  './manifest.json'
];

self.addEventListener('install', (e) => {
  e.waitUntil(
    caches.open(CACHE_NAME).then(c => c.addAll(CORE_FILES).catch(() => {}))
  );
  self.skipWaiting();
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then(keys => Promise.all(
      keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k))
    ))
  );
  self.clients.claim();
});

// استراتژی: Network-first برای HTML، Cache-first برای بقیه
self.addEventListener('fetch', (e) => {
  const url = new URL(e.request.url);

  // فقط درخواست‌های همون دامنه
  if (url.origin !== location.origin) return;
  // از Supabase و CDN رد شو
  if (url.pathname.startsWith('/js/') && e.request.destination === 'script') {
    // js files: network-first
  }

  e.respondWith(
    fetch(e.request)
      .then(res => {
        if (res.ok && e.request.method === 'GET') {
          const clone = res.clone();
          caches.open(CACHE_NAME).then(c => c.put(e.request, clone));
        }
        return res;
      })
      .catch(() => caches.match(e.request))
  );
});

// برای اعلان‌های Push (اختیاری)
self.addEventListener('push', (e) => {
  const data = e.data?.json() || {};
  e.waitUntil(
    self.registration.showNotification(data.title || 'پیام جدید', {
      body: data.body || '',
      icon: data.icon || './manifest.json',
      badge: data.badge || './manifest.json'
    })
  );
});

self.addEventListener('notificationclick', (e) => {
  e.notification.close();
  e.waitUntil(
    clients.matchAll({ type: 'window' }).then(list => {
      for (const c of list) {
        if (c.url.includes('chat.html') && 'focus' in c) return c.focus();
      }
      if (clients.openWindow) return clients.openWindow('./chat.html');
    })
  );
});
