/* ديواني: عامل الخدمة. يتيح فتح الموقع دون إنترنت بعد أول زيارة. */
var V = 'diwan-v1';
var CORE = ['./', 'index.html', 'config.js', 'manifest.webmanifest', 'icons/icon-192.png', 'icons/icon-512.png'];

self.addEventListener('install', function (e) {
  e.waitUntil(caches.open(V).then(function (c) { return c.addAll(CORE); }).then(function () { return self.skipWaiting(); }));
});

self.addEventListener('activate', function (e) {
  e.waitUntil(
    caches.keys().then(function (ks) {
      return Promise.all(ks.filter(function (k) { return k !== V; }).map(function (k) { return caches.delete(k); }));
    }).then(function () { return self.clients.claim(); })
  );
});

self.addEventListener('fetch', function (e) {
  var req = e.request;
  if (req.method !== 'GET') return;
  var url = new URL(req.url);
  /* لا نخزّن طلبات قاعدة البيانات: تبقى طازجة دائمًا */
  if (/supabase\.co$/.test(url.hostname)) return;

  /* ملفات الموقع نفسه: الشبكة أولًا ثم النسخة المخزنة، فيصل التحديث فور توفره */
  if (url.origin === self.location.origin) {
    e.respondWith(
      fetch(req).then(function (res) {
        var copy = res.clone();
        caches.open(V).then(function (c) { c.put(req, copy); });
        return res;
      }).catch(function () {
        return caches.match(req).then(function (m) { return m || caches.match('index.html'); });
      })
    );
    return;
  }

  /* الخطوط والمكتبات الخارجية: المخزن أولًا مع تحديث في الخلفية */
  e.respondWith(
    caches.match(req).then(function (m) {
      var net = fetch(req).then(function (res) {
        if (res && (res.status === 200 || res.type === 'opaque')) {
          var copy = res.clone();
          caches.open(V).then(function (c) { c.put(req, copy); });
        }
        return res;
      }).catch(function () { return m; });
      return m || net;
    })
  );
});
