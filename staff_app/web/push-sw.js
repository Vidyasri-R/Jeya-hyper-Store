// New-order alerts for Jeya Staff while the app is closed (Web Push; iPhone needs the app on the
// Home Screen, iOS 16.4+). The server sends {title, body, url, tag}.
'use strict';

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

self.addEventListener('push', (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (_) {
    data = { body: event.data ? event.data.text() : '' };
  }
  event.waitUntil(
    self.registration.showNotification(data.title || 'New order', {
      body: data.body || 'Open Jeya Staff',
      tag: data.tag || 'orders',
      renotify: true,
      requireInteraction: true,
      vibrate: [400, 150, 400, 150, 800],
      icon: 'icons/Icon-192.png',
      badge: 'icons/Icon-192.png',
      data: { url: data.url || '/orders' },
    }),
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = new URL((event.notification.data && event.notification.data.url) || '/orders', self.location.origin).href;
  event.waitUntil(
    (async () => {
      const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
      for (const client of windows) {
        if (new URL(client.url).origin === self.location.origin && 'focus' in client) return client.focus();
      }
      return self.clients.openWindow(url);
    })(),
  );
});
