/* Tiny Bird, Big Dreams: home page behaviour. No dependencies. */
(function () {
  "use strict";
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
  var RM = matchMedia("(prefers-reduced-motion: reduce)").matches;
  var TOUCH = matchMedia("(hover: none)").matches;
  // analytics only exists after cookie consent; every call is optional
  var track = function (t, v) { if (window.tb && window.tb.track) window.tb.track(t, v); };
  var once = {};
  // Run an element's animation only while it's on screen (saves battery on phones).
  function whenVisible(el, cb) {
    var on = false;
    new IntersectionObserver(function (es) { on = es[0].isIntersecting; if (on) cb(); }, { rootMargin: "100px" }).observe(el);
    return function () { return on && !document.hidden; };
  }
  var trackOnce = function (t, v) { var k = t + v; if (once[k]) return; once[k] = 1; track(t, v); };

  /* ---------- greeting + hero sky: by the visitor's own clock (their device's time zone) ---------- */
  var localH = (function () { var d = new Date(), h = d.getHours() + d.getMinutes() / 60; return h < 5 ? 24 : h; })();
  (function () {
    var g = $("#greet"), hero = $(".hero"); if (!hero) return;
    hero.dataset.h = localH.toFixed(2);
    hero.dataset.l = localH < 12 ? "Morning" : localH < 17 ? "Afternoon" : localH < 21 ? "Evening" : "Night";
    hero.classList.toggle("dark", localH >= 19 || localH < 5);
    if (g) { g.textContent = localH < 12 ? "Good morning ☀" : localH < 17 ? "Good afternoon ☀" : "Good evening ☾"; g.hidden = false; }
  })();

  /* ---------- sound: removed from the page; noise() and tone() stay silent ---------- */
  var AC = null, soundOn = false;
  function noise(d, f1, f2, v, type) {
    if (!soundOn || !AC) return;
    var n = Math.floor(AC.sampleRate * d), b = AC.createBuffer(1, n, AC.sampleRate), x = b.getChannelData(0);
    for (var i = 0; i < n; i++) x[i] = Math.random() * 2 - 1;
    var s = AC.createBufferSource(); s.buffer = b;
    var f = AC.createBiquadFilter(); f.type = type || "bandpass";
    f.frequency.setValueAtTime(f1, AC.currentTime); f.frequency.linearRampToValueAtTime(f2, AC.currentTime + d);
    var g = AC.createGain(); g.gain.setValueAtTime(0, AC.currentTime);
    g.gain.linearRampToValueAtTime(v || .2, AC.currentTime + d * .3); g.gain.linearRampToValueAtTime(0, AC.currentTime + d);
    s.connect(f).connect(g).connect(AC.destination); s.start();
  }
  function tone(fr, d, v) {
    if (!soundOn || !AC) return; d = d || .15;
    var o = AC.createOscillator(), g = AC.createGain();
    o.frequency.setValueAtTime(fr, AC.currentTime); o.frequency.exponentialRampToValueAtTime(fr * 1.5, AC.currentTime + d);
    g.gain.setValueAtTime(v || .1, AC.currentTime); g.gain.exponentialRampToValueAtTime(.001, AC.currentTime + d);
    o.connect(g).connect(AC.destination); o.start(); o.stop(AC.currentTime + d);
  }

  /* ---------- mobile menu ---------- */
  var sheet = $("#sheet"), menuBtn = $("#menuBtn");
  function setMenu(open) { sheet.classList.toggle("open", open); menuBtn.setAttribute("aria-expanded", String(open)); }
  menuBtn.addEventListener("click", function () { setMenu(!sheet.classList.contains("open")); });
  sheet.addEventListener("click", function (e) { if (e.target === sheet || e.target.closest("a")) setMenu(false); });
  addEventListener("keydown", function (e) { if (e.key === "Escape") { setMenu(false); closeEgg(); } });

  var topBar = $(".top");
  function onScroll() { topBar.classList.toggle("scrolled", scrollY > 40); }
  addEventListener("scroll", onScroll, { passive: true }); onScroll();

  /* ---------- sky + clock, keyed to the hour of the day ---------- */
  var keys = [[6, ["#ffb38a", "#ffd6ad", "#b9cdf0"]], [7.5, ["#8ec2f5", "#bfe0ff", "#f3e7d6"]], [12.5, ["#4f93e6", "#8cc3f7", "#d8ecff"]], [17.5, ["#e98a52", "#f3b475", "#8a79c9"]], [19.5, ["#4a2f78", "#9a5a8c", "#e9886a"]], [21.5, ["#141033", "#2a1e52", "#3a2a66"]], [24, ["#07060f", "#0e0b22", "#17123a"]]];
  var hex = function (h) { return [1, 3, 5].map(function (i) { return parseInt(h.substr(i, 2), 16); }); };
  var mix = function (a, b, t) { return a.map(function (v, i) { return Math.round(v + (b[i] - v) * t); }); };
  function cols(h) {
    var i = 0; while (i < keys.length - 2 && h > keys[i + 1][0]) i++;
    var a = keys[i], b = keys[i + 1], t = Math.min(1, Math.max(0, (h - a[0]) / (b[0] - a[0])));
    return a[1].map(function (c, k) { return mix(hex(c), hex(b[1][k]), t); });
  }
  var sky = $("#sky"), sx = sky.getContext("2d"), st = $("#stars"), ss = st.getContext("2d"), W, H, stars = [];
  function size() {
    var dpr = Math.min(2, devicePixelRatio || 1);
    W = innerWidth; H = innerHeight;
    [sky, st].forEach(function (c) { c.width = W * dpr; c.height = H * dpr; c.getContext("2d").setTransform(dpr, 0, 0, dpr, 0, 0); });
    stars = []; for (var i = 0; i < 220; i++) stars.push({ x: Math.random() * W, y: Math.random() * H, r: Math.random() * 1.3 + .3, t: Math.random() * 6 });
  }
  size(); addEventListener("resize", size);
  var clouds = [], cl = $("#clouds");
  if (!RM) for (var i = 0; i < 10; i++) {
    var c = document.createElement("div"), w = 200 + Math.random() * 380;
    c.className = "cloud"; c.style.width = w + "px"; c.style.height = w * .45 + "px"; c.style.left = (Math.random() * 110 - 10) + "vw";
    cl.appendChild(c); clouds.push({ el: c, y: Math.random() * 3 + .5, s: .3 + Math.random() * .7, dx: Math.random() * 40 });
  }
  var secs = $$("section[data-h]");
  function hourNow() {
    var mid = scrollY + innerHeight * .5, i = 0;
    while (i < secs.length - 1 && mid > secs[i + 1].offsetTop) i++;
    var a = secs[i], b = secs[i + 1] || a;
    var t = b === a ? 0 : Math.min(1, Math.max(0, (mid - a.offsetTop) / (b.offsetTop - a.offsetTop)));
    if (a.classList.contains("hero")) t = t * t * t; // hold the visitor's own sky over the hero, then ease into the morning
    // h blends between sections for the sky; the clock shows the section's own time (its photo's time stamp)
    var tm = a.querySelector(".time");
    return { h: +a.dataset.h + (+b.dataset.h - +a.dataset.h) * t, at: +a.dataset.h, txt: tm ? tm.textContent.trim() : "", l: a.dataset.l };
  }
  function fmt(h) {
    h = Math.min(h, 23.99); var hh = Math.floor(h), mm = Math.floor((h - hh) * 60), ap = hh >= 12 ? "pm" : "am";
    hh = hh % 12 || 12; return hh + ":" + String(mm).padStart(2, "0") + " " + ap;
  }
  var clockT = $("#clockT"), clockL = $("#clockL"), sunDot = $("#sunDot"), clockEl = $("#clock"), picker = $("#lull"), dayEnd = $("#team");
  function paintSky(t) {
    var now = hourNow(), h = now.h;
    clockT.textContent = now.txt || fmt(now.at); clockL.textContent = now.l;
    // the clock joins once the day starts (the first moment) and leaves once the day is done
    var mid = scrollY + innerHeight * .5; clockEl.classList.toggle("on", !!picker && mid > picker.offsetTop && (!dayEnd || mid < dayEnd.offsetTop));
    var ang = Math.PI * (1 - Math.min(1, Math.max(0, (h - 6) / 14)));
    sunDot.setAttribute("cx", (17 + 15 * Math.cos(ang)).toFixed(1)); sunDot.setAttribute("cy", (18 - 15 * Math.sin(ang)).toFixed(1));
    sunDot.setAttribute("fill", h > 20 ? "#e9e4ff" : "#E8A022");
    var cc = cols(h), g = sx.createLinearGradient(0, 0, 0, H);
    g.addColorStop(0, "rgb(" + cc[0] + ")"); g.addColorStop(.55, "rgb(" + cc[1] + ")"); g.addColorStop(1, "rgb(" + cc[2] + ")");
    sx.fillStyle = g; sx.fillRect(0, 0, W, H);
    ss.clearRect(0, 0, W, H);
    var sa = Math.max(0, Math.min(1, (h - 19.5) / 2));
    if (sa > 0) for (var k = 0; k < stars.length; k++) {
      var s = stars[k]; ss.fillStyle = "rgba(255,248,230," + (sa * (RM ? .8 : .35 + .65 * Math.abs(Math.sin(t / 900 + s.t)))) + ")";
      ss.beginPath(); ss.arc(s.x, s.y, s.r, 0, 7); ss.fill();
    }
    return h;
  }

  /* ---------- the bird you fly ---------- */
  // Over the hero the bird *is* the logo (it sits docked on the header icon). Scroll on and it
  // lifts off and follows your mouse (or flies its own path on touch); at the studio it perches
  // on the night tree's long branch.
  var bird = $("#bird"), logoImg = $("#logo .mark"), mx = innerWidth * .5, my = innerHeight * .72, landed = false, tapT = -1e9, docked = true;
  var lr0 = logoImg ? logoImg.getBoundingClientRect() : { left: 20, top: 20, width: 36, height: 36 };
  var bx = lr0.left + lr0.width / 2, by = lr0.top + lr0.height / 2 + 12, lastX = bx;
  addEventListener("pointermove", function (e) { if (e.pointerType === "mouse") { mx = e.clientX; my = e.clientY; } });
  // The bird follows the mouse, so it must never block a click: it's pointer-events:none and
  // links/buttons under it get the click. A tap on the bird over empty sky still counts for the egg.
  addEventListener("pointerdown", function (e) {
    if (e.target.closest("a,button,input,textarea,select,label,.toy,.chips,.egg-card,.sheet")) return;
    tapT = e.timeStamp;
    var r = bird.getBoundingClientRect();
    if (docked) { mx = e.clientX; my = e.clientY; return; }
    if (e.clientX >= r.left - 20 && e.clientX <= r.right + 20 && e.clientY >= r.top - 20 && e.clientY <= r.bottom + 30) { flap(); eggTap(); return; }
    mx = e.clientX; my = e.clientY; flap();
  });
  function flap() {
    if (RM) return;
    bird.classList.add("fast"); setTimeout(function () { bird.classList.remove("fast"); }, 420);
    my -= 40; noise(.18, 900, 300, .16);
    for (var i = 0; i < 3; i++) {
      var f = document.createElement("div"); f.className = "feather"; document.body.appendChild(f);
      var dx = (Math.random() - .5) * 120, r = Math.random() * 360; f.style.left = bx + "px"; f.style.top = by + "px";
      var a = f.animate([{ transform: "rotate(" + r + "deg)", opacity: 1 }, { transform: "translate(" + dx + "px," + (80 + Math.random() * 60) + "px) rotate(" + (r + 220) + "deg)", opacity: 0 }], { duration: 1500, easing: "ease-out" });
      a.onfinish = (function (el) { return function () { el.remove(); }; })(f);
    }
  }

  /* ---------- cool bird facts: a new one every time the egg opens, no repeats until you've seen them all ---------- */
  var FACTS = [
    ["hummingbird.jpg", "A ruby-throated hummingbird hovering over the sea at sunrise", "Tiny bird. Big trip.", "The ruby-throated hummingbird weighs about 3 grams, about as much as a penny, and every autumn it flies roughly 500 miles across the Gulf of Mexico without stopping. Tiny bird, big dreams."],
    ["facts/tern.jpg", "An Arctic tern flying over an icy polar sea", "Chasing the sun.", "The Arctic tern flies from the Arctic to the Antarctic and back every year, around 70,000 km (44,000 miles). Over a lifetime that adds up to about three trips to the Moon and back. Small wings, big world."],
    ["facts/godwit.jpg", "A bar-tailed godwit flying low over the ocean at dawn", "Eleven days, no stops.", "In 2022 a five-month-old bar-tailed godwit flew about 13,560 km (8,435 miles) from Alaska to Tasmania without landing once, the longest non-stop bird flight on record. No food, no water, no rest. Tiny bird, big dreams."],
    ["facts/bee-hummingbird.jpg", "A bee hummingbird on a thin twig beside a hibiscus flower", "The world's smallest bird.", "Cuba's bee hummingbird is about 5 to 6 cm long and weighs under 2 grams, lighter than a dime. Its nest is about the size of a bottle cap. Tiny, and still a whole bird."],
    ["facts/blackpoll.jpg", "A blackpoll warbler on a spruce branch at sunrise", "A songbird crosses an ocean.", "Each autumn the blackpoll warbler, about 12 grams, flies non-stop out over the Atlantic from the northeastern US towards South America: up to 2,770 km (1,720 miles) in about three days. Tiny bird, big dreams."],
    ["facts/swift.jpg", "A common swift gliding across a big evening sky", "Ten months in the air.", "Common swifts can stay airborne for around ten months at a time, eating and drinking on the wing, and are thought to nap up there too. Some barely touch down between leaving the nest and coming back to breed."],
    ["facts/nutcracker.jpg", "A Clark's nutcracker holding a pine seed on a snowy pine", "A memory for thousands of spots.", "A Clark's nutcracker can bury tens of thousands of pine seeds in one autumn, spread across thousands of tiny caches, and find many of them again months later, even under snow. Small head, big plans."],
    ["facts/chickadee.jpg", "A black-capped chickadee on a snowy branch", "A brain that grows for winter.", "Black-capped chickadees hide food in thousands of places. Each autumn their brains add new neurons in the area that handles spatial memory, just in time to remember where it all went."],
    ["facts/nest.jpg", "A tiny hummingbird nest on a branch with two small white eggs", "A nest that grows with you.", "Many hummingbirds build a walnut-sized nest bound with spider silk. The silk stretches as the chicks grow, so the nest grows with them. The eggs are about the size of a jelly bean. Tiny home, big dreams."],
    ["facts/robin.jpg", "A European robin on a branch under a starry twilight sky", "A compass in its eyes.", "European robins can sense Earth's magnetic field and use it to find their way on night-time migrations. Scientists think the sense works through light-sensitive molecules in their eyes."],
    ["facts/rufous.jpg", "A rufous hummingbird hovering by red flowers in a meadow", "The longest trip, for its size.", "The rufous hummingbird is about 8 cm long, yet it migrates up to roughly 6,300 km (3,900 miles) each way between Alaska and Mexico. Measured in body lengths, that's one of the longest migrations of any bird. Tiny bird, big dreams."],
    ["facts/goldcrest.jpg", "A goldcrest with its gold crown stripe on a pine twig", "The woodcock pilot.", "The goldcrest, one of Europe's smallest birds at 5 to 6 grams, crosses the North Sea every autumn. People once thought it couldn't possibly fly that far and must hitch a ride on a woodcock's back. It flies itself."],
    ["facts/hover.jpg", "A ruby-throated hummingbird hovering beside a flower, wings blurred", "Reverse gear.", "Hummingbirds are the only birds that can keep flying backwards. Their wings rotate at the shoulder and trace a figure-eight, so they make lift on the upstroke as well as the downstroke."]
  ];
  function nextFact() {
    var bag = null;
    try { bag = JSON.parse(localStorage.getItem("tb_facts") || "null"); } catch (e) { bag = nextFact.mem; } // storage blocked: remember in memory
    if (!Array.isArray(bag) || !bag.length || bag.some(function (i) { return !(i >= 0 && i < FACTS.length); })) {
      bag = FACTS.map(function (_, i) { return i; });
      for (var i = bag.length - 1; i > 0; i--) { var j = Math.floor(Math.random() * (i + 1)), t = bag[i]; bag[i] = bag[j]; bag[j] = t; }
      if (nextFact.last != null && bag[0] === nextFact.last) bag.push(bag.shift()); // no back-to-back repeat across rounds
    }
    var n = bag.shift(); nextFact.last = n;
    try { localStorage.setItem("tb_facts", JSON.stringify(bag)); } catch (e) { /* in-memory only */ }
    nextFact.mem = bag;
    return FACTS[n];
  }
  function showFact() {
    var f = nextFact(), img = $("#eggCard img");
    img.src = "/assets/home/" + f[0]; img.alt = f[1]; $("#eggTitle").textContent = f[2]; $("#eggCard .b p").textContent = f[3];
  }

  /* ---------- easter egg: tap the bird 5 times ---------- */
  var eggCard = $("#eggCard"), taps = [];
  function openEgg() {
    showFact();
    eggCard.classList.add("open"); eggCard.setAttribute("aria-hidden", "false");
    bird.classList.add("loop"); setTimeout(function () { bird.classList.remove("loop"); }, 1000);
    [523, 659, 784, 1047].forEach(function (f, i) { setTimeout(function () { tone(f, .18, .08); }, i * 110); });
    trackOnce("egg", "hummingbird"); $("#eggClose").focus();
  }
  function closeEgg() { eggCard.classList.remove("open"); eggCard.setAttribute("aria-hidden", "true"); }
  function eggTap() {
    var t = Date.now(); taps = taps.filter(function (x) { return t - x < 4000; }); taps.push(t);
    if (taps.length >= 5) { taps = []; openEgg(); }
  }
  bird.addEventListener("click", function (e) { if (e.detail) return; e.stopPropagation(); flap(); eggTap(); }); // keyboard only
  $("#logo").addEventListener("click", function (e) {
    if (!TOUCH && !RM) return; // on desktop the logo just goes home; the flying bird is the egg
    if (scrollY < 10) e.preventDefault();
    eggTap();
  });
  $("#eggClose").addEventListener("click", closeEgg);

  /* ---------- main animation loop ---------- */
  var nest = $("#nest"), tp = performance.now(), hum = null;
  var sceneImgs = $$(".scene .ph img");
  function loop(t) {
    var dt = Math.min(50, t - tp); tp = t;
    var h = paintSky(t);
    for (var k = 0; k < clouds.length; k++) {
      var c = clouds[k], y = (c.y * innerHeight - scrollY * c.s) % (innerHeight * 3.4);
      c.dx += dt * .0015 * c.s; c.el.style.transform = "translate(" + (c.dx % 40) + "vw," + y + "px)";
      c.el.style.opacity = .5 * (1 - Math.max(0, Math.min(1, (h - 17) / 3)));
    }
    if (!RM) {
      var nr = nest.getBoundingClientRect(), near = nr.top < innerHeight * .7 && nr.bottom > 60;
      var home = scrollY < innerHeight * .35, tx = mx, ty = my;
      if (TOUCH && t - tapT > 2500) { // no mouse: a lazy loop down the right side as you scroll
        tx = innerWidth * .78 + Math.sin(scrollY / 260) * innerWidth * .1; ty = innerHeight * .32 + Math.cos(scrollY / 340) * innerHeight * .1;
      }
      if (home && logoImg) { var lr = logoImg.getBoundingClientRect(); tx = lr.left + lr.width / 2; ty = lr.top + lr.height / 2 + 12; near = false; }
      else if (near) { tx = nr.left + nr.width * .5; ty = nr.top + nr.height * .55; }
      if (near !== landed) { landed = near; bird.classList.toggle("landed", near); if (near) tone(660, .2); }
      bx += (tx - bx) * .1; by += (ty - by) * .1 + (landed || home ? 0 : Math.sin(t / 260) * .5);
      var dd = Math.hypot(tx - bx, ty - by), k2 = home ? Math.min(1, dd / 90) : 1; docked = home && dd < 30;
      bird.style.opacity = k2.toFixed(2);
      if (logoImg) logoImg.style.opacity = (1 - k2).toFixed(2); // only ever one bird: the logo empties while it's away
      var vx = bx - lastX; lastX = bx;
      var face = vx < -.3 ? 1 : vx > .3 ? -1 : (+bird.dataset.f || 1); bird.dataset.f = face;
      bird.style.transform = "translate(" + (bx - 28) + "px," + (by - 40) + "px) scale(" + (.78 + .22 * k2).toFixed(3) + ") scaleX(" + face + ") rotate(" + Math.max(-25, Math.min(25, -vx * face * 1.6)) + "deg)";
      for (var j = 0; j < sceneImgs.length; j++) {
        var r = sceneImgs[j].parentNode.getBoundingClientRect();
        if (r.bottom > 0 && r.top < innerHeight) sceneImgs[j].style.setProperty("--py", ((r.top + r.height / 2 - innerHeight / 2) * -.05) + "px");
      }
    }
    if (!RM && !document.hidden) requestAnimationFrame(loop); else looping = false;
  }
  if (RM && nest) { // reduced motion: the bird doesn't fly; it is simply sitting on the branch
    var team = $(".team"), still = document.createElement("span"); still.className = "perched"; still.setAttribute("aria-hidden", "true");
    still.innerHTML = bird.innerHTML; team.appendChild(still);
    var place = function () { var tr = team.getBoundingClientRect(), r = nest.getBoundingClientRect(); still.style.left = (r.left - tr.left + r.width / 2 - 28) + "px"; still.style.top = (r.top - tr.top + r.height * .55 - 40) + "px"; };
    place(); addEventListener("resize", place); addEventListener("load", place);
    var logoMark = $("#logo .mark"), sync = function () { var r = nest.getBoundingClientRect(); if (logoMark) logoMark.style.opacity = r.top < innerHeight && r.bottom > 0 ? "0" : "1"; };
    addEventListener("scroll", sync, { passive: true }); sync(); // reduced motion: one bird, either in the logo or on the branch
  }
  var looping = true;
  requestAnimationFrame(loop);
  function kick() { if (!looping) { looping = true; tp = performance.now(); requestAnimationFrame(loop); } }
  document.addEventListener("visibilitychange", function () { if (!document.hidden && !RM) kick(); });
  if (RM) { addEventListener("scroll", kick, { passive: true }); addEventListener("resize", kick); }

  /* ---------- reveal on scroll ---------- */
  var io = new IntersectionObserver(function (es) { es.forEach(function (e) { if (e.isIntersecting) e.target.classList.add("seen"); }); }, { threshold: .18 });
  $$("section").forEach(function (s) { io.observe(s); });


  /* ---------- picker + shop + outbound tracking ---------- */
  $$("[data-pick]").forEach(function (a) { a.addEventListener("click", function () { track("pick", a.dataset.pick); }); });
  $$("[data-shop]").forEach(function (a) { a.addEventListener("click", function () { track("shop", a.dataset.shop); }); });
  $$(".tabs button").forEach(function (b) {
    b.addEventListener("click", function () {
      $$(".tabs button").forEach(function (x) { x.setAttribute("aria-pressed", String(x === b)); });
      $$("#grid .card").forEach(function (c) {
        var show = b.dataset.f === "all" || c.dataset.t === b.dataset.f;
        c.hidden = !show;
        if (show && !RM && c.animate) c.animate([{ opacity: 0, transform: "translateY(16px)" }, { opacity: 1, transform: "none" }], { duration: 500, easing: "cubic-bezier(.2,.8,.2,1)" });
      });
      track("shop", "tab:" + b.dataset.f);
    });
  });

  /* ---------- toys ---------- */
  // Lull: hold to breathe
  (function () {
    var toy = $("#lullToy"), sp = $("#sphere"), tx = $("#breathTxt"), s = .8, hold = false, n = 0, peak = false, running = false;
    var vis = whenVisible(toy, function () { if (!running) { running = true; requestAnimationFrame(f); } });
    var arc = $("#lullArc"), timeEl = $("#lullTime"), pill = $("#lullPill"), left = 180, ticking = null;
    function tick() { left = Math.max(0, left - 1); timeEl.textContent = Math.floor(left / 60) + ":" + String(left % 60).padStart(2, "0"); }
    function down(e) { if (e) e.preventDefault(); hold = true; tx.textContent = "Breathe in"; pill.textContent = "Pause"; if (!ticking) ticking = setInterval(tick, 1000); noise(4, 300, 700, .1, "lowpass"); trackOnce("toy", "lull"); }
    function up() { if (!hold) return; hold = false; if (peak) { n++; peak = false; } tx.textContent = "Breathe out"; setTimeout(function () { if (!hold) tx.textContent = "Breathe in"; }, 3200); noise(4, 700, 250, .08, "lowpass"); }
    toy.addEventListener("pointerdown", down); addEventListener("pointerup", up); toy.addEventListener("pointerleave", up);
    toy.addEventListener("keydown", function (e) { if ((e.key === " " || e.key === "Enter") && !hold) down(e); });
    toy.addEventListener("keyup", function (e) { if (e.key === " " || e.key === "Enter") up(); });
    function f() {
      if (!vis()) { running = false; return; }
      s += ((hold ? 1.3 : .8) - s) * (hold ? .012 : .016); if (s > 1.2) peak = true;
      sp.style.transform = "scale(" + s + ")";
      arc.setAttribute("stroke-dashoffset", String(298 - 298 * Math.min(1, Math.max(0, (s - .8) / .5))));
      sp.style.boxShadow = "0 0 " + (30 + (s - .8) * 180) + "px " + ((s - .8) * 40) + "px rgba(160,130,255," + (.35 + (s - .8) * .6) + ")";
      requestAnimationFrame(f);
    }
  })();
  // Orbit: real faces orbit You (you can still drag one away; they spring back)
  (function () {
    var toy = $("#orbitToy"), teth = $("#tether");
    var ppl = [{ f: "mom", l: "Mom", k: "fam", r: .2, a: 0, sp: .0005 }, { f: "dev", l: "Dev", k: "fr", r: .28, a: 2.4, sp: .00042 }, { f: "sarah", l: "Sis", k: "fam", r: .4, a: 1.1, sp: .0003 }, { f: "jordan", l: "Jo", k: "fr", r: .38, a: 3.6, sp: .00028 }, { f: "gramps", l: "Gramps", k: "fam", r: .42, a: 5.1, sp: .00024 }];
    ppl.forEach(function (p) {
      var d = document.createElement("div"); d.className = "friend"; d.style.backgroundImage = "url(/assets/home/faces/" + p.f + ".jpg)"; d.innerHTML = '<span class="' + p.k + '">' + p.l + "</span>"; toy.appendChild(d);
      p.el = d; p.x = null; p.vx = 0; p.vy = 0;
      d.addEventListener("pointerdown", function (e) { e.stopPropagation(); d.setPointerCapture(e.pointerId); p.drag = true; tone(520, .12); trackOnce("toy", "orbit"); });
      d.addEventListener("pointermove", function (e) { if (!p.drag) return; var r = toy.getBoundingClientRect(); p.x = e.clientX - r.left; p.y = e.clientY - r.top; });
      d.addEventListener("pointerup", function () { p.drag = false; tone(390, .25); });
    });
    var t0 = performance.now(), running = false;
    var vis = whenVisible(toy, function () { if (!running) { running = true; t0 = performance.now(); requestAnimationFrame(f); } });
    function f(t) {
      if (!vis()) { running = false; return; }
      var dt = Math.min(50, t - t0); t0 = t;
      var S = toy.clientWidth, c = S / 2, cy = toy.clientHeight / 2, L = "";
      ppl.forEach(function (p) {
        if (!RM) p.a += p.sp * dt;
        var hx = c + Math.cos(p.a) * p.r * S, hy = cy + Math.sin(p.a) * p.r * S;
        if (p.x === null) { p.x = hx; p.y = hy; }
        if (!p.drag) { p.vx = (p.vx + (hx - p.x) * .0035 * dt) * .9; p.vy = (p.vy + (hy - p.y) * .0035 * dt) * .9; p.x += p.vx; p.y += p.vy; }
        var dd = Math.hypot(p.x - hx, p.y - hy);
        if (dd > 6) L += '<line x1="' + c + '" y1="' + cy + '" x2="' + p.x + '" y2="' + p.y + '" stroke="rgba(255,255,255,' + Math.min(.8, dd / 120) + ')" stroke-width="1.5" stroke-dasharray="4 5"/>';
        p.el.style.transform = "translate(" + p.x + "px," + p.y + "px)";
      });
      if (L !== teth._last) { teth.innerHTML = L; teth._last = L; }
      requestAnimationFrame(f);
    }
  })();
  // Lull Sleep: tap Begin, the screen dims to a slow orb and the 8 hr timer counts down; tap again to wake
  (function () {
    var toy = $("#sleepToy"); if (!toy) return;
    var left = $("#sleepLeft"), secs = 8 * 3600, timer = null;
    function fmtL(x) { var h = Math.floor(x / 3600), m = Math.floor(x % 3600 / 60), s = x % 60; return h + ":" + String(m).padStart(2, "0") + ":" + String(s).padStart(2, "0"); }
    function toggle() {
      var on = !toy.classList.contains("on"); toy.classList.toggle("on", on);
      toy.setAttribute("aria-label", on ? "Sleep mode on. Tap to wake" : "Lull's Sleep screen. Tap to begin Sleep mode");
      clearInterval(timer); secs = 8 * 3600; left.textContent = fmtL(secs);
      if (on) { timer = setInterval(function () { secs--; left.textContent = fmtL(secs); }, 1000); noise(4, 200, 900, .06, "lowpass"); trackOnce("toy", "lull-sleep"); }
    }
    toy.addEventListener("click", toggle);
    toy.addEventListener("keydown", function (e) { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); toggle(); } });
  })();
  // Field Guide: stickers
  (function () {
    var toy = $("#fgToy"), st = ["🎧", "☕", "🌙", "📼", "✨", "🎟️"], i = 0;
    toy.addEventListener("pointerdown", function (e) {
      var r = toy.getBoundingClientRect(), s = document.createElement("span");
      s.className = "stk"; s.textContent = st[i++ % st.length]; s.style.left = (e.clientX - r.left) + "px"; s.style.top = (e.clientY - r.top) + "px";
      s.style.setProperty("--r", (Math.random() * 30 - 15) + "deg"); toy.appendChild(s); tone(620 + Math.random() * 300, .12); trackOnce("toy", "fieldguide");
    });
  })();

  /* ---------- forms ---------- */
  function msg(el, text, ok) { el.textContent = text; el.style.color = ok ? "" : "#ffb4a2"; el.classList.add("show"); }
  var nestNote = $("#nestNote");
  try { if (localStorage.getItem("tb_msg") === "1") nestNote.hidden = false; } catch (e) { /* storage blocked */ }
  var cf = $("#contactForm"), cm = $("#contactMsg");
  cf.addEventListener("submit", function (e) {
    e.preventDefault();
    var btn = cf.querySelector("button"); btn.disabled = true; btn.textContent = "Sending…";
    try { var v = localStorage.getItem("tb_vid"); if (v) cf.elements.vid.value = v; } catch (x) { /* ignore */ }
    fetch(cf.action, { method: "POST", body: new FormData(cf), headers: { Accept: "application/json" } })
      .then(function (r) {
        if (!r.ok) throw new Error(r.status);
        cf.reset(); msg(cm, "Thanks! It's on its way to the nest. We'll write back soon.", true); nestNote.hidden = false;
        try { if (localStorage.getItem("tb_vid")) localStorage.setItem("tb_msg", "1"); } catch (x) { /* ignore */ }
      })
      .catch(function (err) { msg(cm, String(err && err.message) === "429" ? "You've sent a few already. Please try again later, or email hello@tinybirdbigdreams.com." : "Hmm, that didn't send. Please try again, or email hello@tinybirdbigdreams.com.", false); })
      .then(function () { btn.disabled = false; btn.textContent = "Send it →"; });
  });
  var sf = $("#signupForm"), sm = $("#signupMsg");
  sf.addEventListener("submit", function (e) {
    e.preventDefault();
    fetch(sf.action, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ email: sf.elements.email.value, website: sf.elements.website.value }) })
      .then(function (r) { if (!r.ok) throw new Error(r.status); sf.reset(); msg(sm, "You're on the list ✦ We'll tell you when something hatches.", true); track("shop", "signup"); })
      .catch(function (err) { msg(sm, String(err && err.message) === "429" ? "Too many tries. Please try again in a bit." : "That didn't work. Check the email address and try again.", false); });
  });
})();
