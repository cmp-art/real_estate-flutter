// web/firebase-messaging-sw.js
// Firebase Cloud Messaging service worker — handles background push on web/PWA.
// Firebase automatically discovers this file at /firebase-messaging-sw.js.

importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey:            'AIzaSyD8mNbSVz3uEiRj-lVR8P3hREHMNl8GxW4',
  authDomain:        'patamjengo.firebaseapp.com',
  projectId:         'patamjengo',
  storageBucket:     'patamjengo.firebasestorage.app',
  messagingSenderId: '953302924189',
  appId:             '1:953302924189:web:069f84de9dddf8c6910d74',
  measurementId:     'G-3713QW0R36',
});

const messaging = firebase.messaging();

// ── Background message handler ────────────────────────────────────────────────
// Called when a push arrives and the tab is closed, in the background, or the
// PWA is not running. Shows an OS notification via the service worker.
messaging.onBackgroundMessage(function(payload) {
  console.log('[FCM SW] Background message received:', payload);

  const title   = payload.notification?.title ?? 'Patamjengo';
  const body    = payload.notification?.body  ?? '';
  const notifType = payload.data?.type ?? 'general';

  const options = {
    body:     body,
    icon:     '/icons/Icon-192.png',
    badge:    '/icons/Icon-192.png',
    tag:      'patamjengo-' + notifType,
    renotify: true,
    vibrate:  [200, 100, 200],
    data:     payload.data ?? {},
  };

  return self.registration.showNotification(title, options);
});

// ── Notification click handler ────────────────────────────────────────────────
self.addEventListener('notificationclick', function(event) {
  event.notification.close();

  const url = event.notification.data?.url || '/';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(windowClients => {
      for (const client of windowClients) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          client.postMessage({ type: 'NOTIFICATION_CLICK', data: event.notification.data });
          return client.focus();
        }
      }
      if (clients.openWindow) return clients.openWindow(url);
    })
  );
});
