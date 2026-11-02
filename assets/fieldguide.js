(function () {
  var reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (reduce || !('animate' in Element.prototype)) return;

  // Things land on the page as they scroll in, like items in a replay.
  var landing = new IntersectionObserver(function (entries) {
    entries.forEach(function (entry) {
      if (!entry.isIntersecting) return;
      landing.unobserve(entry.target);
      var turn = entry.target.dataset.turn || '0deg';
      entry.target.animate([
        { transform: 'scale(1.9) rotate(14deg)', opacity: 0 },
        { transform: 'scale(.9) rotate(' + turn + ')', opacity: 1, offset: .6 },
        { transform: 'scale(1.05) rotate(' + turn + ')', offset: .8 },
        { transform: 'scale(1) rotate(' + turn + ')' }
      ], { duration: 560, easing: 'ease-out' });
    });
  }, { threshold: .25 });
  document.querySelectorAll('.land').forEach(function (el) { landing.observe(el); });

  // The notebook starts shut, swings open, then the good stuff pops out. It closes and plays again.
  var hero = document.querySelector('.duo-stage');
  if (hero && document.documentElement.classList.contains('fg-intro')) {
    var opened = hero.querySelector('.duo-box > .duo-sketch:not(.duo-closed)');
    var shut = hero.querySelector('.duo-closed');
    var bits = Array.prototype.slice.call(hero.querySelectorAll('.float, .pop-tools'));
    var wait = function (ms) { return new Promise(function (go) { setTimeout(go, ms); }); };
    var run = function (el, frames, ms, delay) {
      return el.animate(frames, { duration: ms, delay: delay || 0, easing: 'ease-in-out', fill: 'forwards' }).finished;
    };
    var cycle = function () {
      return wait(1300)
        .then(function () {
          return Promise.all([
            run(shut, [{ transform: 'rotate(-2deg) scaleX(1)' }, { transform: 'rotate(-2deg) scaleX(0)' }], 600),
            run(opened, [{ clipPath: 'inset(0 0 0 50%)' }, { clipPath: 'inset(0 0 0 0%)' }], 750, 120)
          ]);
        })
        .then(function () {
          return Promise.all(bits.map(function (bit, i) {
            return run(bit, [{ opacity: 0, scale: 0 }, { opacity: 1, scale: 1.25, offset: .6 }, { opacity: 1, scale: 1 }], 480, i * 130);
          }));
        })
        .then(function () { return wait(9000); })
        .then(function () {
          return Promise.all(bits.map(function (bit) { return run(bit, [{ opacity: 1, scale: 1 }, { opacity: 0, scale: .4 }], 300); }));
        })
        .then(function () {
          return Promise.all([
            run(opened, [{ clipPath: 'inset(0 0 0 0%)' }, { clipPath: 'inset(0 0 0 50%)' }], 600),
            run(shut, [{ transform: 'rotate(-2deg) scaleX(0)' }, { transform: 'rotate(-2deg) scaleX(1)' }], 500, 120)
          ]);
        })
        .then(cycle);
    };
    cycle();
  }

  // A pencil traces the photo every time it scrolls into view.
  var trace = document.querySelector('.trace-paper svg');
  if (trace) {
    var lines = Array.prototype.slice.call(trace.querySelectorAll('g[stroke] path'));
    var pencil = trace.querySelector('.trace-pencil');
    var lengths = lines.map(function (line) { return line.getTotalLength(); });
    var token = 0;
    var clear = function () {
      lines.forEach(function (line, i) { line.style.strokeDasharray = lengths[i]; line.style.strokeDashoffset = lengths[i]; });
      pencil.style.opacity = 0;
    };
    var draw = function (mine) {
      var i = 0;
      var next = function () {
        if (mine !== token) return;
        if (i >= lines.length) { pencil.style.opacity = 0; return; }
        var line = lines[i], length = lengths[i], ms = Math.min(900, Math.max(170, length * 3.2)), start = null;
        var step = function (now) {
          if (mine !== token) return;
          if (start === null) start = now;
          var k = Math.min(1, (now - start) / ms), done = length * k, point = line.getPointAtLength(done);
          line.style.strokeDashoffset = length - done;
          pencil.setAttribute('transform', 'translate(' + point.x + ' ' + point.y + ')');
          if (k < 1) { requestAnimationFrame(step); } else { i++; setTimeout(next, 50); }
        };
        pencil.style.opacity = 1;
        requestAnimationFrame(step);
      };
      setTimeout(next, 400);
    };
    clear();
    new IntersectionObserver(function (entries) {
      token++;
      clear();
      if (entries[0].isIntersecting) draw(token);
    }, { threshold: .4 }).observe(trace);
  }

  // Text boxes pop onto the page one by one whenever the section comes into view.
  var notes = Array.prototype.slice.call(document.querySelectorAll('.notes .note'));
  if (notes.length && document.documentElement.classList.contains('fg-intro')) {
    new IntersectionObserver(function (entries) {
      var visible = entries[0].isIntersecting;
      notes.forEach(function (note, i) {
        note.getAnimations().forEach(function (a) { if (a.id === 'pop') a.cancel(); });
        if (!visible) return;
        var pop = note.animate([{ scale: 0, opacity: 0 }, { scale: 1.3, opacity: 1, offset: .6 }, { scale: .92, opacity: 1, offset: .8 }, { scale: 1, opacity: 1 }],
          { duration: 520, delay: 150 + i * 170, easing: 'ease-out', fill: 'forwards' });
        pop.id = 'pop';
      });
    }, { threshold: .35 }).observe(document.querySelector('.notes'));
  }

  var stage = document.getElementById('replay');
  if (!stage) return;
  var steps = Array.prototype.slice.call(stage.querySelectorAll('[data-step]'));
  var label = document.getElementById('replay-effect');
  var visible = false;
  var waiters = [];

  new IntersectionObserver(function (entries) {
    visible = entries[0].isIntersecting;
    if (visible) { waiters.splice(0).forEach(function (go) { go(); }); }
  }, { threshold: .3 }).observe(stage);

  function whenVisible() {
    return visible ? Promise.resolve() : new Promise(function (go) { waiters.push(go); });
  }
  function pause(ms) {
    return new Promise(function (go) { setTimeout(go, ms); });
  }

  function poses(effect) {
    var w = stage.clientWidth;
    switch (effect) {
      case 'whirl': return [
        { transform: 'translate(' + w * .35 + 'px,' + -w * .2 + 'px) rotate(-720deg) scale(.15)', opacity: 0 },
        { transform: 'translate(' + -w * .2 + 'px,' + w * .15 + 'px) rotate(-300deg) scale(.6)', opacity: 1, offset: .5 },
        { transform: 'none' }];
      case 'swoop left': return [
        { transform: 'translateX(' + -w * 1.4 + 'px) rotate(-28deg) scale(1.25)' },
        { transform: 'translate(' + w * .05 + 'px,' + -w * .06 + 'px) rotate(5deg)', offset: .72 },
        { transform: 'none' }];
      case 'swoop right': return [
        { transform: 'translateX(' + w * 1.4 + 'px) rotate(28deg) scale(1.25)' },
        { transform: 'translate(' + -w * .05 + 'px,' + -w * .06 + 'px) rotate(-5deg)', offset: .72 },
        { transform: 'none' }];
      case 'bounce': return [
        { transform: 'translateY(' + -w * 1.5 + 'px)', easing: 'ease-in' },
        { transform: 'none', offset: .4, easing: 'ease-out' },
        { transform: 'translateY(' + -w * .2 + 'px)', offset: .55, easing: 'ease-in' },
        { transform: 'none', offset: .7, easing: 'ease-out' },
        { transform: 'translateY(' + -w * .06 + 'px)', offset: .85, easing: 'ease-in' },
        { transform: 'none' }];
      case 'pop': return [
        { transform: 'scale(0)', opacity: 0 },
        { transform: 'scale(1.5)', opacity: 1, offset: .45 },
        { transform: 'scale(.8)', offset: .65 },
        { transform: 'scale(1.12)', offset: .82 },
        { transform: 'none' }];
      default: return [
        { transform: 'scale(3.2) rotate(34deg)', opacity: 0, easing: 'ease-in' },
        { transform: 'scale(.86)', opacity: 1, offset: .55 },
        { transform: 'scale(1.08)', offset: .75 },
        { transform: 'none' }];
    }
  }

  function burst(el, rays) {
    var box = el.getBoundingClientRect();
    var home = stage.getBoundingClientRect();
    var x = box.left - home.left + box.width / 2;
    var y = box.top - home.top + box.height / 2;
    var radius = Math.max(box.width, box.height) / 2;
    var colors = ['#C4552B', '#E8B23F', '#7F9A7E', '#8CBBE0', '#E89E9E', '#6B4570'];
    for (var i = 0, n = rays ? 12 : 18; i < n; i++) {
      var bit = document.createElement('span');
      var angle = rays ? i / 12 * Math.PI * 2 : i * 2.4;
      var reach = radius * (rays ? 1.5 : 1.3 + (i % 4) * .3);
      bit.className = rays ? 'ray' : 'bit';
      bit.style.left = x + 'px';
      bit.style.top = y + 'px';
      if (!rays) bit.style.background = colors[i % colors.length];
      var spin = rays ? (angle * 180 / Math.PI + 90) + 'deg' : (i * 70) + 'deg';
      stage.appendChild(bit);
      bit.animate([
        { transform: 'translate(-50%,-50%) translate(' + Math.cos(angle) * radius + 'px,' + Math.sin(angle) * radius + 'px) rotate(' + spin + ')', opacity: 1 },
        { transform: 'translate(-50%,-50%) translate(' + Math.cos(angle) * reach + 'px,' + (Math.sin(angle) * reach + (rays ? 0 : 50)) + 'px) rotate(' + spin + ')', opacity: 0 }
      ], { duration: 620, easing: 'ease-out' }).finished.then(function (done) { done.effect.target.remove(); });
    }
  }

  function draw(path) {
    var length = path.getTotalLength();
    path.style.strokeDasharray = length;
    path.style.opacity = 1;
    return path.animate([{ strokeDashoffset: length }, { strokeDashoffset: 0 }], { duration: Math.max(260, length * 1.5), easing: 'ease-in-out', fill: 'both' }).finished;
  }

  function land(el) {
    var effect = el.dataset.effect;
    label.textContent = effect;
    el.style.opacity = 1;
    var duration = 820;
    var motion = el.animate(poses(effect), { duration: duration, fill: 'none' });
    var hit = { 'slam': .55, 'bounce': .4, 'pop': .45, 'whirl': .8, 'swoop left': .72, 'swoop right': .72 }[effect];
    setTimeout(function () { burst(el, effect === 'slam' || effect === 'bounce'); }, duration * hit);
    return motion.finished;
  }

  var shareBits = Array.prototype.slice.call(stage.querySelectorAll('[data-share]'));
  var dim = stage.querySelector('.share-dim');
  var button = stage.querySelector('.share-btn');
  var messages = Array.prototype.slice.call(stage.querySelectorAll('.msg'));
  var hearts = Array.prototype.slice.call(stage.querySelectorAll('.heart'));

  function show(el, frames, ms) {
    return el.animate(frames, { duration: ms, easing: 'ease-out', fill: 'forwards' }).finished;
  }

  // The finished page goes out as a video, and the family chimes in.
  function share() {
    label.textContent = 'share with family';
    return show(button, [{ opacity: 0, transform: 'translateX(-50%) scale(0)' }, { opacity: 1, transform: 'translateX(-50%) scale(1.15)', offset: .7 }, { opacity: 1, transform: 'translateX(-50%) scale(1)' }], 420)
      .then(function () { return pause(450); })
      .then(function () { return show(button, [{ opacity: 1, transform: 'translateX(-50%) scale(1)' }, { opacity: 1, transform: 'translateX(-50%) scale(.88)', offset: .4 }, { opacity: 0, transform: 'translateX(-50%) scale(1.2)' }], 380); })
      .then(function () { return show(dim, [{ opacity: 0 }, { opacity: 1 }], 300); })
      .then(function () {
        var chain = Promise.resolve();
        messages.forEach(function (msg, i) {
          chain = chain.then(function () {
            return show(msg, [{ opacity: 0, transform: 'translateY(24px) scale(.9)' }, { opacity: 1, transform: 'none' }], 340);
          }).then(function () { return pause(i === 0 ? 650 : 480); });
        });
        return chain;
      })
      .then(function () {
        hearts.forEach(function (heart, i) {
          heart.animate([{ opacity: 0, transform: 'translateY(0) scale(.6)' }, { opacity: 1, transform: 'translateY(-60px) scale(1.2)', offset: .3 }, { opacity: 0, transform: 'translateY(-200px) scale(1)' }],
            { duration: 1600, delay: i * 180, easing: 'ease-out' });
        });
        return pause(2600);
      })
      .then(function () { return Promise.all(shareBits.map(function (el) { return show(el, [{ opacity: getComputedStyle(el).opacity }, { opacity: 0 }], 300); })); });
  }

  function reset() {
    label.textContent = 'replay';
    stage.getAnimations({ subtree: true }).forEach(function (a) { a.cancel(); });
    steps.forEach(function (el) {
      if (el.dataset.step === 'ink') { el.style.opacity = 0; } else { el.style.opacity = 0; }
    });
  }

  function run() {
    reset();
    var chain = whenVisible();
    steps.forEach(function (el) {
      chain = chain.then(whenVisible).then(function () {
        if (el.dataset.step === 'ink') return draw(el);
        if (el.dataset.step === 'write') {
          el.style.opacity = 1;
          return el.animate([{ clipPath: 'inset(0 100% 0 0)' }, { clipPath: 'inset(0 0 0 0)' }], { duration: 900, fill: 'none' }).finished;
        }
        return land(el);
      }).then(function () { return pause(140); });
    });
    chain.then(function () { label.textContent = 'tada'; return pause(1400); }).then(share).then(run);
  }
  run();
})();
