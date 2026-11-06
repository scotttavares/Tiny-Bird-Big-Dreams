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

  /* ---------- sound (synthesised, off by default) ---------- */
  var AC = null, soundOn = false, snd = $("#snd");
  snd.addEventListener("click", function () {
    soundOn = !soundOn;
    snd.textContent = soundOn ? "🔊" : "🔇";
    snd.setAttribute("aria-pressed", String(soundOn));
    if (soundOn && !AC) { try { AC = new (window.AudioContext || window.webkitAudioContext)(); } catch (e) { soundOn = false; } }
  });
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
    return { h: +a.dataset.h + (+b.dataset.h - +a.dataset.h) * t, l: a.dataset.l };
  }
  function fmt(h) {
    h = Math.min(h, 23.99); var hh = Math.floor(h), mm = Math.floor((h - hh) * 60), ap = hh >= 12 ? "pm" : "am";
    hh = hh % 12 || 12; return hh + ":" + String(mm).padStart(2, "0") + " " + ap;
  }
  var clockT = $("#clockT"), clockL = $("#clockL"), sunDot = $("#sunDot"), clockEl = $("#clock"), picker = $("section.picker"), dayEnd = $("#team");
  function paintSky(t) {
    var now = hourNow(), h = now.h;
    clockT.textContent = fmt(h); clockL.textContent = now.l;
    // the reel cycles through the whole day on its own, so the clock only joins once the day is scrolled, and leaves once the day is done
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
  var bird = $("#bird"), mx = innerWidth * .5, my = innerHeight * .72, bx = mx, by = my, lastX = bx, landed = false;
  addEventListener("pointermove", function (e) { if (e.pointerType === "mouse") { mx = e.clientX; my = e.clientY; } });
  addEventListener("pointerdown", function (e) {
    if (e.target.closest("a,button,input,textarea,.toy,.chips,.egg-card,.sheet")) return;
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

  /* ---------- easter egg: tap the bird 5 times ---------- */
  var eggCard = $("#eggCard"), taps = [];
  function openEgg() {
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
  bird.addEventListener("click", function (e) { e.stopPropagation(); flap(); eggTap(); });
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
      var tx = mx, ty = my; if (near) { tx = nr.left + nr.width * .5; ty = nr.top + nr.height * .55; }
      if (near !== landed) { landed = near; bird.classList.toggle("landed", near); if (near) tone(660, .2); }
      bx += (tx - bx) * .1; by += (ty - by) * .1 + (landed ? 0 : Math.sin(t / 260) * .5);
      var vx = bx - lastX; lastX = bx;
      var face = vx < -.3 ? 1 : vx > .3 ? -1 : (+bird.dataset.f || 1); bird.dataset.f = face;
      bird.style.transform = "translate(" + (bx - 28) + "px," + (by - 40) + "px) scaleX(" + face + ") rotate(" + Math.max(-25, Math.min(25, -vx * face * 1.6)) + "deg)";
      for (var j = 0; j < sceneImgs.length; j++) {
        var r = sceneImgs[j].parentNode.getBoundingClientRect();
        if (r.bottom > 0 && r.top < innerHeight) sceneImgs[j].style.setProperty("--py", ((r.top + r.height / 2 - innerHeight / 2) * -.05) + "px");
      }
    }
    if (!RM && !document.hidden) requestAnimationFrame(loop); else looping = false;
  }
  var looping = true;
  requestAnimationFrame(loop);
  function kick() { if (!looping) { looping = true; tp = performance.now(); requestAnimationFrame(loop); } }
  document.addEventListener("visibilitychange", function () { if (!document.hidden && !RM) kick(); });
  if (RM) { addEventListener("scroll", kick, { passive: true }); addEventListener("resize", kick); }

  /* ---------- reveal on scroll ---------- */
  var io = new IntersectionObserver(function (es) { es.forEach(function (e) { if (e.isIntersecting) e.target.classList.add("seen"); }); }, { threshold: .18 });
  $$("section").forEach(function (s) { io.observe(s); });

  /* ---------- the reel: four real-life clips, crossfading ---------- */
  (function () {
    var clips = [
      { n: "lull", kind: "phone", alt: "Lull's breathing screen", line: "A breath before the day.", cap: "7:12 am · Lull", sub: "One breath before the emails", ic: '<img src="/assets/home/icon-lull.png" alt="" />' },
      { n: "orbit", kind: "phone", alt: "Orbit's orbit view of friends and family", line: "A hello that brings them closer.", cap: "12:40 pm · Orbit", sub: "A hello on the lunch break", ic: '<img src="/assets/home/icon-orbit.png" alt="" />' },
      { n: "fieldguide", kind: "duo", alt: "A Field Guide journal spread on iPhone Duo", line: "A page for every adventure.", cap: "6:30 pm · Field Guide", sub: "A butterfly, saved forever", ic: '<img src="/assets/home/icon-fieldguide.png" alt="" />' },
      { n: "paperwars", kind: "phone", alt: "A Paper Wars battlefield on notebook paper", line: "A laugh to end the night.", cap: "9:15 pm · Paper Wars", sub: "Face to face, one more round", ic: '<img src="/assets/home/icon-paperwars.png" alt="" />' },
      { n: "lull-sleep", file: "lull-sleep", app: "lull", kind: "phone", alt: "Lull's Sleep screen", line: "A softer way to drift off.", cap: "10:45 pm · Lull", sub: "Sleep mode, lights out", ic: '<img src="/assets/home/icon-lull.png" alt="" />' },
    ];
    var root = $("#reel"), vids = [$("#vA"), $("#vB")], still = $(".reel .still"), capEl = $("#reelCap"), ticks = $$("#ticks i b"), pp = $("#reelPP");
    var fails = 0;
    var RATE = 0.8; // play the clips a little slower than real time
    var idx = 0, front = 0, playing = !RM, visible = false, started = false, raf = 0;
    var saveData = navigator.connection && navigator.connection.saveData;
    if (saveData) playing = false;
    function src(i) { return "/assets/home/reel/" + clips[i].n + ".mp4"; }
    var lineEl = $("#reelLine"), shot = $("#appshot"), shotImg = $("#appshotImg");
    var NAMES = { lull: "Lull", "lull-sleep": "Lull Sleep", orbit: "Orbit", fieldguide: "Field Guide", paperwars: "Paper Wars" };
    clips.forEach(function (c) { var im = new Image(); im.src = "/assets/home/screens/" + c.n + ".jpg"; });
    function showShot(i) {
      var c = clips[i];
      if (shotImg.getAttribute("src") === "/assets/home/screens/" + c.n + ".jpg") { shot.classList.add("in"); return; }
      shot.classList.remove("in");
      setTimeout(function () {
        shotImg.src = "/assets/home/screens/" + c.n + ".jpg"; shotImg.alt = c.alt;
        shot.dataset.kind = c.kind;
        shot.classList.add("in");
      }, 350);
    }
    function caption(i) {
      showShot(i);
      capEl.innerHTML = clips[i].ic + "<div><b>" + clips[i].cap + "</b><span>" + clips[i].sub + "</span></div>";
      if (lineEl.textContent === clips[i].line) return;
      lineEl.innerHTML = clips[i].line.split(" ").map(function (w, k) { return '<span class="w" style="animation-delay:' + (k * 90) + 'ms">' + w + "</span>"; }).join(" ");
    }
    function setTicks() {
      var v = vids[front];
      ticks.forEach(function (b, i) { b.style.width = i < idx ? "100%" : i > idx ? "0" : ((v.duration ? v.currentTime / v.duration : 0) * 100) + "%"; });
      raf = (playing && visible) ? requestAnimationFrame(setTicks) : 0;
    }
    function show(i) {
      var next = vids[1 - front], cur = vids[front];
      next.src = src(i); next.poster = "/assets/home/reel/" + clips[i].n + "-poster.jpg";
      next.currentTime = 0; next.playbackRate = RATE; next.defaultPlaybackRate = RATE;
      var go = function () {
        next.classList.add("on"); cur.classList.remove("on"); still.classList.remove("on");
        setTimeout(function () { cur.pause(); }, 900);
        front = 1 - front; idx = i; caption(i);
      };
      var p = next.play();
      if (p && p.then) p.then(function () { fails = 0; go(); }).catch(function (err) {
        if (err && err.name === "NotAllowedError") {
          // Autoplay refused (e.g. Low Power Mode): show this clip's still with its own caption and wait for the play button.
          still.src = next.poster; still.classList.add("on"); idx = i; caption(i);
          playing = false; started = false; pp.textContent = "▶"; pp.setAttribute("aria-label", "Play video");
        } else if (++fails < clips.length) {
          // This clip didn't load: skip it, leaving the current footage and caption together.
          idx = i; show((i + 1) % clips.length);
        }
      });
      else go();
    }
    vids.forEach(function (v) {
      v.addEventListener("ended", function () { if (v === vids[front] && playing && visible) show((idx + 1) % clips.length); });
    });
    function start() {
      if (started) { if (playing) vids[front].play().catch(function () {}); return; }
      started = true; show(0); cancelAnimationFrame(raf); setTicks();
    }
    function stop() { vids.forEach(function (v) { v.pause(); }); }
    pp.addEventListener("click", function () {
      playing = !playing;
      pp.textContent = playing ? "❚❚" : "▶"; pp.setAttribute("aria-label", playing ? "Pause video" : "Play video");
      if (playing && visible) { start(); cancelAnimationFrame(raf); setTicks(); } else stop();
    });
    if (!playing) { pp.textContent = "▶"; pp.setAttribute("aria-label", "Play video"); }
    new IntersectionObserver(function (es) {
      visible = es[0].isIntersecting;
      if (visible && playing) { start(); cancelAnimationFrame(raf); setTicks(); } else stop();
    }, { threshold: .25 }).observe(root);
  })();

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
  // Orbit: drag a friend away, they spring back
  (function () {
    var toy = $("#orbitToy"), teth = $("#tether");
    var ppl = [{ c: "#ffb4a2", l: "Mom", r: .27, a: 0, sp: .0005 }, { c: "#ffd166", l: "Sis", r: .4, a: 2.1, sp: .00032 }, { c: "#9be7c4", l: "Jo", r: .4, a: 4.2, sp: .00032 }];
    ppl.forEach(function (p) {
      var d = document.createElement("div"); d.className = "friend"; d.style.background = p.c; d.textContent = p.l; toy.appendChild(d);
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
  // Paper Wars: draw a line of fire
  (function () {
    var toy = $("#pwToy"), svg = $("#pwSvg"), tip = $("#pwTip"), NS = "http://www.w3.org/2000/svg";
    var pts = [], dr = false, busy = false, en, tr;
    function el(t, a) { var e = document.createElementNS(NS, t); for (var k in a) e.setAttribute(k, a[k]); svg.appendChild(e); return e; }
    function stick(x, y, c) {
      var g = document.createElementNS(NS, "g");
      g.innerHTML = '<circle cx="' + x + '" cy="' + y + '" r="9" class="ink" style="stroke:' + c + '"/><path class="ink" style="stroke:' + c + '" d="M' + x + ' ' + (y + 9) + ' L' + x + ' ' + (y + 38) + ' M' + x + ' ' + (y + 38) + ' L' + (x - 10) + ' ' + (y + 58) + ' M' + x + ' ' + (y + 38) + ' L' + (x + 10) + ' ' + (y + 58) + ' M' + x + ' ' + (y + 19) + ' L' + (x - 13) + ' ' + (y + 29) + ' M' + x + ' ' + (y + 19) + ' L' + (x + 13) + ' ' + (y + 27) + '"/>';
      svg.appendChild(g);
    }
    function sheetNew() { svg.innerHTML = ""; busy = false; stick(70, 440, "#2b2b2b"); var ex = 170 + Math.random() * 70, ey = 110 + Math.random() * 120; en = { x: ex, y: ey + 28 }; stick(ex, ey, "#3a5a9a"); tip.textContent = "draw a line to the blue guy ✏️"; }
    sheetNew();
    function pos(e) { var r = toy.getBoundingClientRect(); return [(e.clientX - r.left) / r.width * 300, (e.clientY - r.top) / r.height * 600]; }
    toy.addEventListener("pointerdown", function (e) { if (busy) { sheetNew(); return; } toy.setPointerCapture(e.pointerId); dr = true; pts = [pos(e)]; tr = el("path", { "class": "trace" }); trackOnce("toy", "paperwars"); });
    toy.addEventListener("pointermove", function (e) { if (!dr) return; pts.push(pos(e)); tr.setAttribute("d", "M" + pts.map(function (p) { return p.join(" "); }).join(" L")); if (pts.length % 3 === 0) noise(.05, 3000, 2500, .04, "highpass"); });
    toy.addEventListener("pointerup", function () {
      if (!dr) return; dr = false;
      var a0 = pts[0], a1 = pts[pts.length - 1];
      if (pts.length < 2 || Math.hypot(a1[0] - a0[0], a1[1] - a0[1]) < 16) { tr.remove(); return; }
      var d = [pts[0]];
      for (var i = 1; i < pts.length; i++) { var a = pts[i - 1], b = pts[i], n = Math.max(1, Math.ceil(Math.hypot(b[0] - a[0], b[1] - a[1]) / 3)); for (var j = 1; j <= n; j++) d.push([a[0] + (b[0] - a[0]) * j / n, a[1] + (b[1] - a[1]) * j / n]); }
      pts = d; tr.setAttribute("d", "M" + pts.map(function (p) { return p.join(" "); }).join(" L")); busy = true;
      var shot = el("circle", { r: 4, fill: "#2b2b2b" }), k = 0; noise(.25, 600, 200, .18);
      (function s() { k += 2; if (k >= pts.length) { shot.remove(); land(); return; } shot.setAttribute("cx", pts[k][0]); shot.setAttribute("cy", pts[k][1]); requestAnimationFrame(s); })();
    });
    function land() {
      var p = pts[pts.length - 1], hit = Math.hypot(p[0] - en.x, p[1] - en.y) < 55, b = document.createElement("div");
      b.className = "boom"; b.textContent = hit ? "BOOM!" : "miss…"; if (!hit) b.style.color = "#666";
      b.style.left = p[0] / 3 + "%"; b.style.top = p[1] / 6 + "%"; toy.appendChild(b); requestAnimationFrame(function () { b.classList.add("go"); });
      if (hit) {
        noise(.6, 400, 60, .4, "lowpass");
        var s = el("path", { "class": "ink", style: "stroke:#d4381e;stroke-width:4", d: "M" + (en.x - 26) + " " + (en.y - 40) + " L" + (en.x + 24) + " " + (en.y + 32) + " M" + (en.x + 26) + " " + (en.y - 40) + " L" + (en.x - 24) + " " + (en.y + 32) });
        var L = s.getTotalLength(); s.style.strokeDasharray = L; s.animate([{ strokeDashoffset: L }, { strokeDashoffset: 0 }], { duration: 500, fill: "forwards" });
        tip.textContent = "got him! tap for a new sheet";
      } else tip.textContent = "so close. tap to try again";
      setTimeout(function () { b.remove(); }, 1600);
    }
  })();
  // Field Guide: stickers
  (function () {
    var toy = $("#fgToy"), st = ["🌼", "🦋", "🐸", "⛺", "⭐", "🍂"], i = 0;
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
