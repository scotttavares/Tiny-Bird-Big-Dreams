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
    chain.then(function () { label.textContent = 'tada'; return pause(2800); }).then(run);
  }
  run();
})();
