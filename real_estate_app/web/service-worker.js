// service-worker.js — Patamjengo PWA
// Handles: caching, offline fallback, Web Push notifications (Supabase-powered)

const CACHE_NAME    = 'patamjengo-v2';
const OFFLINE_URL   = '/index.html';

const PRECACHE_URLS = [
  '/',
  '/index.html',
  '/flutter_bootstrap.js',
  '/assets/AssetManifest.json',
  '/assets/FontManifest.json',
  '/manifest.json',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
];

// ── Install ──────────────────────────────────────────────────────────────────
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(PRECACHE_URLS).catch(() => {}))
      .then(() => self.skipWaiting())
  );
});

// ── Activate ─────────────────────────────────────────────────────────────────
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

// ── Fetch (network-first with cache fallback) ─────────────────────────────────
self.addEventListener('fetch', event => {
  const { request } = event;
  const url = new URL(request.url);

  if (url.origin !== location.origin || request.method !== 'GET') return;

  event.respondWith(
    fetch(request)
      .then(response => {
        if (response && response.status === 200 && response.type !== 'opaque') {
          const clone = response.clone();
          caches.open(CACHE_NAME).then(cache => cache.put(request, clone)).catch(() => {});
        }
        return response;
      })
      .catch(() =>
        caches.match(request).then(cached => cached || caches.match(OFFLINE_URL))
      )
  );
});

// ── Message handler ───────────────────────────────────────────────────────────
self.addEventListener('message', event => {
  if (event.data && event.data.type === 'SKIP_WAITING') self.skipWaiting();
});

// ── Web Push Notifications (Supabase → Edge Function → push → service worker) ─
// This handles push events delivered from the server.
// The server stores VAPID public key in Supabase app_config.
// The Edge Function calls web-push library with the stored subscription.
self.addEventListener('push', event => {
  let data = { title: 'Patamjengo', body: 'You have a new notification.' };
  try {
    data = event.data ? event.data.json() : data;
  } catch (_) {
    data.body = event.data ? event.data.text() : data.body;
  }

  const options = {
    body:    data.body   || '',
    icon:    data.icon   || '/icons/Icon-192.png',
    badge:   data.badge  || '/icons/Icon-192.png',
    image:   data.image,
    data:    data.data   || {},
    actions: data.actions || [],
    vibrate: [200, 100, 200],
    tag:     data.tag    || 'real-estate-notif',
    renotify: true,
  };

  event.waitUntil(
    self.registration.showNotification(data.title, options)
  );
});

// ── Notification click → open/focus app ──────────────────────────────────────
self.addEventListener('notificationclick', event => {
  event.notification.close();

  const urlToOpen = event.notification.data?.url || '/';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(windowClients => {
      // Try to focus an existing window
      for (const client of windowClients) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          client.postMessage({ type: 'NOTIFICATION_CLICK', data: event.notification.data });
          return client.focus();
        }
      }
      // Otherwise open a new window
      if (clients.openWindow) return clients.openWindow(urlToOpen);
    })
  );
});

// ── Background sync (offline-queued actions) ──────────────────────────────────
self.addEventListener('sync', event => {
  if (event.tag === 'sync-properties') {
    event.waitUntil(
      self.clients.matchAll().then(cs => {
        cs.forEach(c => c.postMessage({ type: 'BACKGROUND_SYNC' }));
      })
    );
  }
});

// ── Push subscription helper exposed to Flutter via postMessage ───────────────
// Flutter sends: { type: 'SUBSCRIBE_PUSH', vapidKey: '...' }
// Service worker responds with the PushSubscription JSON
self.addEventListener('message', event => {
  if (event.data && event.data.type === 'GET_PUSH_SUBSCRIPTION') {
    self.registration.pushManager.getSubscription().then(sub => {
      event.ports[0].postMessage({ subscription: sub ? sub.toJSON() : null });
    });
  }

  if (event.data && event.data.type === 'SUBSCRIBE_PUSH' && event.data.vapidKey) {
    self.registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: urlBase64ToUint8Array(event.data.vapidKey),
    }).then(sub => {
      event.ports[0].postMessage({ subscription: sub.toJSON(), error: null });
    }).catch(err => {
      event.ports[0].postMessage({ subscription: null, error: err.message });
    });
  }
});

// Utility: convert VAPID key from base64 to Uint8Array
function urlBase64ToUint8Array(base64String) {
  const padding = '='.repeat((4 - base64String.length % 4) % 4);
  const base64  = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
  const rawData = atob(base64);
  return Uint8Array.from([...rawData].map(c => c.charCodeAt(0)));
}
