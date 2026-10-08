// Jeya Staff: turn new-order alerts on/off in this browser (Web Push). Used from Dart.
'use strict';

(function () {
  const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  const standalone = window.matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;

  function keyBytes(base64url) {
    const padded = (base64url + '='.repeat((4 - (base64url.length % 4)) % 4)).replace(/-/g, '+').replace(/_/g, '/');
    const raw = atob(padded);
    const out = new Uint8Array(raw.length);
    for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
    return out;
  }

  async function registration() {
    return navigator.serviceWorker.register('push-sw.js', { scope: './' });
  }

  window.jeyaAlerts = {
    /** 'ready' | 'home-screen' (iPhone: add to Home Screen first) | 'unsupported' */
    support() {
      if (isIOS && !standalone) return 'home-screen';
      if (!('serviceWorker' in navigator) || !('PushManager' in window) || !('Notification' in window)) return 'unsupported';
      return 'ready';
    },
    /** 'granted' | 'denied' | 'default' */
    permission() {
      return 'Notification' in window ? Notification.permission : 'denied';
    },
    /** This browser's subscription as JSON, or null. */
    async current() {
      if (!('serviceWorker' in navigator)) return null;
      const reg = await navigator.serviceWorker.getRegistration('./');
      const sub = reg && reg.pushManager ? await reg.pushManager.getSubscription() : null;
      return sub ? JSON.stringify(sub.toJSON()) : null;
    },
    /** Asks for permission (call straight from a tap) and subscribes; returns the subscription JSON. */
    async enable(publicKey) {
      const permission = await Notification.requestPermission();
      if (permission !== 'granted') throw new Error(permission === 'denied' ? 'blocked' : 'dismissed');
      const reg = await registration();
      await navigator.serviceWorker.ready;
      let sub = await reg.pushManager.getSubscription();
      if (!sub) sub = await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: keyBytes(publicKey) });
      return JSON.stringify(sub.toJSON());
    },
    /** Unsubscribes; returns the endpoint that was dropped (or null). */
    async disable() {
      const reg = await navigator.serviceWorker.getRegistration('./');
      const sub = reg && reg.pushManager ? await reg.pushManager.getSubscription() : null;
      if (!sub) return null;
      const endpoint = sub.endpoint;
      await sub.unsubscribe();
      return endpoint;
    },
  };
})();
