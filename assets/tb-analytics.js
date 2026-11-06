/* Tiny Bird, Big Dreams: first-party analytics. Loaded ONLY after the visitor
   grants "analytics" in the cookie banner (see consent.js). Sends small batches
   of events to /track, where they're stored as daily totals. */
(function () {
  "use strict";
  if (window.tb && window.tb._ready) return;

  var vid = null;
  try {
    vid = localStorage.getItem("tb_vid");
    if (!vid) {
      vid = (crypto.randomUUID && crypto.randomUUID()) ||
        "10000000-1000-4000-8000-100000000000".replace(/[018]/g, function (c) {
          return (c ^ (crypto.getRandomValues(new Uint8Array(1))[0] & (15 >> (c / 4)))).toString(16);
        });
      localStorage.setItem("tb_vid", vid);
    }
  } catch (e) { vid = null; }

  var queue = [{ t: "pv", p: location.pathname }];
  var sentRef = false;
  var seen = {};
  var stopped = false;

  function flush() {
    if (stopped || !queue.length) return;
    var body = { vid: vid, events: queue.splice(0, 50) };
    if (!sentRef) { body.ref = document.referrer || ""; sentRef = true; }
    var data = JSON.stringify(body);
    try {
      if (!(navigator.sendBeacon && navigator.sendBeacon("/track", new Blob([data], { type: "text/plain" })))) {
        fetch("/track", { method: "POST", body: data, headers: { "content-type": "text/plain" }, keepalive: true }).catch(function () {});
      }
    } catch (e) { /* ignore */ }
  }

  function track(t, v, once) {
    if (stopped || !t) return;
    if (once) { var key = t + ":" + v; if (seen[key]) return; seen[key] = 1; }
    queue.push({ t: t, v: String(v || "") });
    if (queue.length >= 20) flush();
  }

  // Scroll depth buckets (each once per page view).
  var hit = {};
  addEventListener("scroll", function () {
    var d = (scrollY + innerHeight) / Math.max(1, document.documentElement.scrollHeight);
    [25, 50, 75, 100].forEach(function (b) {
      if (!hit[b] && d >= b / 100 - 0.01) { hit[b] = 1; track("scroll", String(b)); }
    });
  }, { passive: true });

  // Outbound clicks to stores, betas and the web game.
  document.addEventListener("click", function (e) {
    var a = e.target.closest && e.target.closest("a[href]");
    if (!a) return;
    var h = a.getAttribute("href") || "";
    var m = /apps\.apple\.com\/.*?id(\d+)/.exec(h);
    if (m) return track("out", "appstore:" + m[1]);
    if (/testflight\.apple\.com/.test(h)) return track("out", "testflight");
    if (/^\/play\/paperwars/.test(h) || /tinybirdbigdreams\.com\/play\/paperwars/.test(h)) return track("out", "play:paperwars");
  }, true);

  // Put the visitor id on forms that want it (contact form banner).
  Array.prototype.forEach.call(document.querySelectorAll('input[name="vid"]'), function (i) { if (vid) i.value = vid; });

  addEventListener("pagehide", flush);
  document.addEventListener("visibilitychange", function () { if (document.visibilityState === "hidden") flush(); });

  function stop() { stopped = true; queue.length = 0; vid = null; }

  window.tb = { _ready: true, track: track, flush: flush, stop: stop, vid: vid };
  document.dispatchEvent(new CustomEvent("tb:ready"));
})();
