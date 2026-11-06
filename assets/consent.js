/* Tiny Bird, Big Dreams: cookie consent (ClearConsent) + consent-gated analytics.
   Nothing analytic runs until the visitor grants "analytics".
   Without consent we only POST an anonymous tally of the banner choice to /consent. */
(function () {
  "use strict";

  window.clearConsentConfig = {
    policyVersion: 1,
    honorGpc: true,
    model: "opt_in",
    regions: [{ match: ["*"], model: "opt_in" }],
    categories: [
      { id: "essential", label: "Essential", summary: "always on", required: true, defaultGranted: true,
        description: "Needed for the site to work and to remember your privacy choice. Always on." },
      { id: "analytics", label: "Analytics", summary: "help us improve", defaultGranted: false,
        description: "Lets us count visits and see which pages and apps people enjoy, as daily totals. Includes Cloudflare Web Analytics." },
    ],
    storage: { cookieName: "tb_consent", expiryDays: 365 },
    ui: {
      layout: "box", position: "bottom-left", blocking: false, showBadge: false,
      theme: { surface: "#17130e", surfaceAlt: "rgba(255,255,255,.06)", text: "#f6f1e8", textMuted: "#cfc5b4", accent: "#E8A022" },
      text: {
        title: "A quick cookie question",
        body: "We'd like to count visits so we know which apps people love. Nothing is measured unless you say yes, and you can change your mind any time.",
        privacyPolicyUrl: "/privacy",
      },
    },
    receipt: { enabled: false },
  };

  var CF_TOKEN = "b0b9b5a0ff9345038eb0ab5e85b9ac3d";
  var lastChoice = null;

  function post(path, body) {
    try {
      var data = JSON.stringify(body);
      if (navigator.sendBeacon && navigator.sendBeacon(path, new Blob([data], { type: "text/plain" }))) return;
      fetch(path, { method: "POST", body: data, headers: { "content-type": "text/plain" }, keepalive: true }).catch(function () {});
    } catch (e) { /* ignore */ }
  }

  function addScript(src, attrs) {
    var s = document.createElement("script");
    s.src = src; s.defer = true;
    for (var k in attrs || {}) s.setAttribute(k, attrs[k]);
    document.head.appendChild(s);
    return s;
  }

  function choiceOf(state) {
    var cats = (state && state.categories) || {};
    var keys = Object.keys(cats).filter(function (k) { return k !== "essential"; });
    var on = keys.filter(function (k) { return cats[k]; }).length;
    if (on === 0) return "reject";
    return on === keys.length ? "accept" : "custom";
  }

  function wireSettingsLinks(cc) {
    var links = document.querySelectorAll("[data-cookie-settings]");
    if (!links.length) {
      var footer = document.querySelector("footer");
      if (footer) {
        var a = document.createElement("a");
        a.href = "#"; a.textContent = "Cookie settings"; a.setAttribute("data-cookie-settings", "");
        a.style.cssText = "display:inline-block;margin:10px 0;color:inherit;opacity:.75;font-size:13px";
        footer.appendChild(a);
        links = [a];
      }
    }
    Array.prototype.forEach.call(links, function (a) {
      a.addEventListener("click", function (e) { e.preventDefault(); cc.openPreferences(); });
    });
  }

  function start() {
    var cc = window.ClearConsent && window.ClearConsent.instance;
    if (!cc) return;
    wireSettingsLinks(cc);
    document.addEventListener("clearConsent:change", function (e) {
      var c = choiceOf(e.detail && e.detail.state);
      var method = e.detail && e.detail.state && e.detail.state.method;
      if (method === "gpc" || method === "dnt") return; // automatic, not a banner answer
      if (c !== lastChoice) { lastChoice = c; post("/consent", { choice: c }); }
    });
    cc.gate("analytics", function () {
      addScript("/assets/tb-analytics.js");
      addScript("https://static.cloudflareinsights.com/beacon.min.js", { "data-cf-beacon": JSON.stringify({ token: CF_TOKEN }) });
    });
  }

  var lib = addScript("/assets/clearconsent.min.js");
  lib.addEventListener("load", start);
})();
