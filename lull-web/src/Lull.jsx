import { useState, useRef, useEffect, useMemo, useCallback } from "react";
import { Volume2, VolumeX } from "lucide-react";

// Lull — a minute to breathe.  Tiny Bird, Big Dreams.
// A living smoke-plasma orb (six themes, three swirl styles) that breathes with you.

const prefersReduced =
  typeof window !== "undefined" &&
  window.matchMedia &&
  window.matchMedia("(prefers-reduced-motion: reduce)").matches;

const rgba = (c, a) => `rgba(${c[0]},${c[1]},${c[2]},${a})`;
const POS = [[32, 34, 42], [70, 62, 48], [58, 26, 42], [40, 72, 50]];
const blobs = (cols) =>
  cols.map((c, i) => `radial-gradient(circle at ${POS[i % 4][0]}% ${POS[i % 4][1]}%, ${rgba(c, 0.85)}, transparent ${POS[i % 4][2]}%)`).join(", ");
// multi-armed conic — the raw material that turbulence shears into smoke filaments
function conic(cols, arms, alpha) {
  const seg = 360 / arms; const stops = [];
  for (let i = 0; i < arms; i++) {
    const c = cols[i % cols.length];
    stops.push(`${rgba(c, alpha)} ${(i * seg).toFixed(1)}deg`);
    stops.push(`rgba(0,0,0,0) ${(i * seg + seg * 0.5).toFixed(1)}deg`);
  }
  return `conic-gradient(from 0deg at 50% 50%, ${stops.join(", ")})`;
}

// color helpers for deriving a calmer "night" palette
const clampc = (v) => Math.max(0, Math.min(255, Math.round(v)));
const mixc = (a, b, t) => [clampc(a[0] * (1 - t) + b[0] * t), clampc(a[1] * (1 - t) + b[1] * t), clampc(a[2] * (1 - t) + b[2] * t)];
const scalec = (c, k) => [clampc(c[0] * k), clampc(c[1] * k), clampc(c[2] * k)];
const hexOf = (c) => "#" + c.map((x) => clampc(x).toString(16).padStart(2, "0")).join("");
const NIGHT_COOL = [92, 102, 140];  // muted moonlit slate-indigo
const NIGHT_WARM = [175, 115, 80];  // soft ember

// swirl character presets
const STYLES = {
  nebula: { armsA: 4, armsB: 6, blurA: 9, blurB: 5, spinA: 58, spinB: 42, soft: 12 },   // soft, diffuse haze
  filament: { armsA: 7, armsB: 11, blurA: 3.5, blurB: 1.8, spinA: 40, spinB: 26, soft: 8 }, // sharp stringy smoke
  veil: { armsA: 3, armsB: 5, blurA: 13, blurB: 8, spinA: 80, spinB: 58, soft: 15 },     // slow silky sheets
};

function makeTheme(s) {
  const nc = s.cool.map((c) => scalec(mixc(c, NIGHT_COOL, 0.5), 0.74));
  const nw = s.warm.map((c) => scalec(mixc(c, NIGHT_WARM, 0.45), 0.8));
  return {
    nightCoolRGB: nc, nightWarmRGB: nw,
    blobCoolNight: blobs(nc), blobWarmNight: blobs(nw),
    coreCoolNight: `radial-gradient(circle at 50% 47%, ${rgba(nc[0], 0.5)} 0%, ${rgba(nc[1], 0.2)} 40%, rgba(0,0,0,0) 64%)`,
    coreWarmNight: `radial-gradient(circle at 50% 47%, ${rgba(nw[0], 0.52)} 0%, ${rgba(nw[1], 0.22)} 40%, rgba(0,0,0,0) 64%)`,
    coolGlowNight: `radial-gradient(circle, ${rgba(nc[0], 0.42)}, rgba(0,0,0,0) 72%)`,
    warmGlowNight: `radial-gradient(circle, ${rgba(nw[0], 0.45)}, rgba(0,0,0,0) 72%)`,
    tintCoolNight: `radial-gradient(80% 60% at 50% 45%, ${rgba(nc[0], 0.1)}, rgba(0,0,0,0) 70%)`,
    tintWarmNight: `radial-gradient(80% 60% at 50% 45%, ${rgba(nw[0], 0.1)}, rgba(0,0,0,0) 70%)`,
    amb1Night: `radial-gradient(circle, ${rgba(nc[0], 0.16)}, rgba(0,0,0,0) 70%)`,
    amb2Night: `radial-gradient(circle, ${rgba(nw[0], 0.14)}, rgba(0,0,0,0) 70%)`,
    ringFromNight: hexOf(nc[0]), ringToNight: hexOf(nw[0]),
    name: s.name, style: s.style, coolRGB: s.cool, warmRGB: s.warm, glass: s.glass,
    swatch: `linear-gradient(135deg, ${rgba(s.cool[0], 1)} 0%, ${rgba(s.warm[0], 1)} 100%)`,
    blobCool: blobs(s.cool), blobWarm: blobs(s.warm),
    coolGlow: `radial-gradient(circle, ${rgba(s.cool[0], 0.6)}, rgba(0,0,0,0) 70%)`,
    warmGlow: `radial-gradient(circle, ${rgba(s.warm[0], 0.58)}, rgba(0,0,0,0) 70%)`,
    coreCool: `radial-gradient(circle at 50% 47%, ${rgba(s.cool[0], 0.6)} 0%, ${rgba(s.cool[1], 0.24)} 38%, rgba(0,0,0,0) 62%)`,
    coreWarm: `radial-gradient(circle at 50% 47%, ${rgba(s.warm[0], 0.6)} 0%, ${rgba(s.warm[1], 0.24)} 38%, rgba(0,0,0,0) 62%)`,
    warmGrad: `radial-gradient(circle at 34% 30%, ${rgba(s.warm[0], 1)} 0%, ${rgba(s.warm[1], 0.85)} 45%, rgba(0,0,0,0) 74%)`,
    tintCool: `radial-gradient(80% 60% at 50% 45%, ${rgba(s.cool[0], 0.15)}, rgba(0,0,0,0) 70%)`,
    tintWarm: `radial-gradient(80% 60% at 50% 45%, ${rgba(s.warm[0], 0.14)}, rgba(0,0,0,0) 70%)`,
    amb1: `radial-gradient(circle, ${rgba(s.cool[0], 0.22)}, rgba(0,0,0,0) 70%)`,
    amb2: `radial-gradient(circle, ${rgba(s.warm[0], 0.16)}, rgba(0,0,0,0) 70%)`,
    ringFrom: s.ring[0], ringTo: s.ring[1],
    rootDay: `radial-gradient(120% 120% at 50% 18%, ${s.day[0]} 0%, ${s.day[1]} 60%, ${s.day[2]} 100%)`,
    rootNight: `radial-gradient(120% 120% at 50% 22%, ${s.night[0]} 0%, ${s.night[1]} 62%, ${s.night[2]} 100%)`,
  };
}

const THEMES = {
  aurora: makeTheme({ name: "Aurora", style: "nebula", cool: [[157, 140, 255], [96, 150, 255], [214, 150, 255]], warm: [[255, 186, 150], [255, 130, 110], [255, 214, 176]], ring: ["#9D8CFF", "#FF9E7D"], day: ["#1c1133", "#0a0613", "#070410"], night: ["#120a22", "#080510", "#05030c"], glass: { irid: 0.40, rim: 200, sheen: "33% 25%", spread: 44, gx: 31, gy: 23, g2: 0, holo: 0 } }),
  tide: makeTheme({ name: "Tide", style: "filament", cool: [[120, 210, 255], [80, 160, 245], [110, 255, 225]], warm: [[255, 205, 150], [255, 150, 120], [255, 225, 180]], ring: ["#6FE0FF", "#FFB27A"], day: ["#09202e", "#06121d", "#040b13"], night: ["#06141d", "#040c14", "#03080e"], glass: { irid: 0.72, rim: 150, sheen: "28% 20%", spread: 36, gx: 26, gy: 19, g2: 0.9, holo: 0.18 } }),
  sunfire: makeTheme({ name: "Sunfire", style: "filament", cool: [[255, 140, 200], [210, 120, 255], [255, 120, 160]], warm: [[255, 170, 90], [255, 110, 70], [255, 200, 120]], ring: ["#FF8CC8", "#FF7E46"], day: ["#2a0f1c", "#160812", "#0c040a"], night: ["#1e0a15", "#0f060d", "#080308"], glass: { irid: 0.30, rim: 290, sheen: "37% 24%", spread: 40, gx: 35, gy: 21, g2: 0.5, holo: 0.06 } }),
};

const ORB_BASE_DAY = "radial-gradient(circle at 50% 47%, rgba(20,16,38,0.34) 0%, rgba(7,4,16,0.82) 80%)";
const ORB_BASE_NIGHT = "radial-gradient(circle at 50% 47%, rgba(12,10,16,0.44) 0%, rgba(4,3,8,0.87) 80%)";
const MASK_A = "radial-gradient(circle at 50% 50%, rgba(0,0,0,1) 6%, rgba(0,0,0,0.6) 20%, rgba(0,0,0,0) 33%)";
const MASK_B = "radial-gradient(circle at 50% 50%, rgba(0,0,0,1) 4%, rgba(0,0,0,0.55) 18%, rgba(0,0,0,0) 31%)";
const MASK_SOFT = "radial-gradient(circle at 50% 50%, rgba(0,0,0,1) 8%, rgba(0,0,0,0.4) 24%, rgba(0,0,0,0) 35%)";

const AUDIO = {
  breathe: { padFreqs: [146.83, 220.0, 293.66], padFilterLo: 480, padFilterHi: 940, padPeak: 0.2, padLow: 0.06, noise: 0.012, noiseFilter: 520, bowlIn: 528, bowlOut: 396, bowlVol: 0.085 },
  sleep: { padFreqs: [98.0, 146.83, 196.0], padFilterLo: 280, padFilterHi: 520, padPeak: 0.16, padLow: 0.05, noise: 0.016, noiseFilter: 320, bowlIn: 396, bowlOut: 264, bowlVol: 0.05 },
};
const DURATIONS = { breathe: [1, 3, 5], sleep: [15, 30, 60] };
const DEFAULT_PATTERN = { breathe: "calm", sleep: "drift" };
const DEFAULT_DUR = { breathe: 3, sleep: 15 };
const SOUND = [{ id: "bowls", name: "Bowls" }, { id: "handpan", name: "Handpan" }, { id: "binaural", name: "Binaural" }];

function makeIR(ctx, seconds, decay) {
  const len = Math.floor(ctx.sampleRate * seconds); const buf = ctx.createBuffer(2, len, ctx.sampleRate);
  for (let ch = 0; ch < 2; ch++) { const d = buf.getChannelData(ch); for (let i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, decay); }
  return buf;
}
function makeBrownNoise(ctx, seconds) {
  const len = Math.floor(ctx.sampleRate * seconds); const buf = ctx.createBuffer(1, len, ctx.sampleRate); const d = buf.getChannelData(0); let last = 0;
  for (let i = 0; i < len; i++) { const w = Math.random() * 2 - 1; last = (last + 0.02 * w) / 1.02; d[i] = last * 3.5; }
  return buf;
}


function makeWhiteNoise(ctx, seconds) {
  const len = Math.floor(ctx.sampleRate * seconds); const b = ctx.createBuffer(1, len, ctx.sampleRate); const d = b.getChannelData(0);
  for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1; return b;
}
function pingNote(ctx, out, wet, o) {
  const t = ctx.currentTime; const vol = o.vol == null ? 0.1 : o.vol; const attack = o.attack == null ? 0.005 : o.attack;
  (o.partials || [{ r: 1, g: 1, d: 2.4 }]).forEach((pt) => {
    const osc = ctx.createOscillator(); osc.type = o.type || "sine"; const f = o.freq * pt.r;
    if (o.glide) { osc.frequency.setValueAtTime(f * (1 + o.glide), t); osc.frequency.exponentialRampToValueAtTime(f, t + 0.14); } else osc.frequency.value = f;
    const g = ctx.createGain(); g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(Math.max(vol * pt.g, 0.0002), t + attack); g.gain.exponentialRampToValueAtTime(0.0001, t + pt.d);
    let node = osc; if (o.lp) { const flt = ctx.createBiquadFilter(); flt.type = "lowpass"; flt.frequency.value = o.lp; osc.connect(flt); node = flt; }
    node.connect(g); g.connect(out); if (wet) g.connect(wet); osc.start(t); osc.stop(t + pt.d + 0.1);
  });
}
const HANDPAN = [146.83, 220.0, 233.08, 261.63, 293.66, 329.63, 349.23, 440.0]; // D "Kurd"-ish, restful
const HP_PARTIALS = [{ r: 1, g: 1, d: 2.6 }, { r: 2.01, g: 0.4, d: 2.0 }, { r: 3.0, g: 0.16, d: 1.3 }, { r: 5.02, g: 0.07, d: 0.8 }];
const BOWL_PARTIALS = (done) => [{ r: 1, g: 1, d: done ? 6.5 : 3.4 }, { r: 2.76, g: 0.42, d: done ? 5 : 2.6 }, { r: 5.4, g: 0.16, d: 2.0 }];

function createSoundscape(id, ctx, master, reverb, buffers, mode) {
  const bus = ctx.createGain(); bus.gain.value = 1; bus.connect(master);
  const wet = ctx.createGain(); wet.gain.value = 0.4; bus.connect(wet); wet.connect(reverb);
  const bedGain = ctx.createGain(); bedGain.gain.value = 1; bedGain.connect(bus);
  const timers = []; const srcs = []; const fades = []; let stopped = false; let base = 0.3;
  const startSrc = (x) => { try { x.start(); } catch (e) {} srcs.push(x); };
  const every = (fn, delay) => { const tick = () => { if (stopped) return; try { fn(); } catch (e) {} const n = typeof delay === "function" ? delay() : delay; timers.push(setTimeout(tick, n)); }; timers.push(setTimeout(tick, typeof delay === "function" ? delay() : delay)); };
  const swell = (phase) => { const t = ctx.currentTime; let tgt = base; if (phase.key === "inhale") tgt = base * 1.18; else if (phase.key === "exhale") tgt = base * 0.82; const g = bedGain.gain; g.cancelScheduledValues(t); g.setValueAtTime(Math.max(g.value, 0.0001), t); g.linearRampToValueAtTime(Math.max(tgt, 0.0001), t + phase.dur * 0.9); };
  const api = { onPhase() {}, onStart() {}, onDone() {}, soften() {}, stop(fade = 1.2) { stopped = true; timers.forEach(clearTimeout); const t = ctx.currentTime; [bus, ...fades].forEach((g) => { try { g.gain.cancelScheduledValues(t); g.gain.setValueAtTime(Math.max(g.gain.value, 0.0001), t); g.gain.exponentialRampToValueAtTime(0.0001, t + fade); } catch (e) {} }); srcs.forEach((x) => { try { x.stop(t + fade + 0.1); } catch (e) {} }); } };

  if (id === "handpan") {
    wet.gain.value = 0.45;
    const drone = ctx.createGain(); drone.gain.value = 0.0001; drone.connect(bus); fades.push(drone);
    const root = mode === "sleep" ? 73.42 : 98;
    [1, 1.5].forEach((m, i) => { const o = ctx.createOscillator(); o.type = "sine"; o.frequency.value = root * m; o.detune.value = i ? 5 : -5; const lp = ctx.createBiquadFilter(); lp.type = "lowpass"; lp.frequency.value = 600; o.connect(lp); lp.connect(drone); startSrc(o); });
    drone.gain.exponentialRampToValueAtTime(0.05, ctx.currentTime + 5);
    const scale = mode === "sleep" ? HANDPAN.slice(0, 5) : HANDPAN;
    const note = (hi) => { const pool = hi ? scale.slice(Math.floor(scale.length / 2)) : scale.slice(0, Math.ceil(scale.length / 2)); const f = pool[Math.floor(Math.random() * pool.length)]; pingNote(ctx, master, reverb, { freq: f, partials: HP_PARTIALS, attack: 0.004, vol: mode === "sleep" ? 0.09 : 0.12, lp: 3200, glide: 0.01 }); };
    api.onPhase = (phase) => { if (phase.key === "inhale") note(true); else if (phase.key === "exhale") note(false); };
    api.onStart = () => note(false);
    api.onDone = () => { if (mode === "breathe") pingNote(ctx, master, reverb, { freq: scale[0], partials: HP_PARTIALS, attack: 0.004, vol: 0.12, lp: 3200 }); };
  } else if (id === "binaural") {
    wet.gain.value = 0.15;
    const cfg = mode === "sleep" ? { f: 150, beat: 3.2 } : { f: 200, beat: 10 };
    const mk = (freq, pan) => { const o = ctx.createOscillator(); o.type = "sine"; o.frequency.value = freq; const pn = ctx.createStereoPanner(); pn.pan.value = pan; const g = ctx.createGain(); g.gain.value = 0.0001; o.connect(g); g.connect(pn); pn.connect(bus); startSrc(o); fades.push(g); g.gain.exponentialRampToValueAtTime(0.08, ctx.currentTime + 3); return g; };
    const gL = mk(cfg.f, -1); const gR = mk(cfg.f + cfg.beat, 1);
    const pad = ctx.createGain(); pad.gain.value = 0.0001; const po = ctx.createOscillator(); po.type = "sine"; po.frequency.value = cfg.f / 2; const plp = ctx.createBiquadFilter(); plp.type = "lowpass"; plp.frequency.value = 300; po.connect(plp); plp.connect(pad); pad.connect(bus); startSrc(po); fades.push(pad); pad.gain.exponentialRampToValueAtTime(0.04, ctx.currentTime + 4);
    const ns = ctx.createBufferSource(); ns.buffer = buffers.brown; ns.loop = true; const ng = ctx.createGain(); ng.gain.value = 0.008; ns.connect(ng); ng.connect(bus); startSrc(ns); fades.push(ng);
    api.onPhase = (phase) => { const t = ctx.currentTime; const tgt = phase.key === "inhale" ? 0.1 : phase.key === "exhale" ? 0.07 : 0.085; [gL, gR].forEach((g) => { g.gain.cancelScheduledValues(t); g.gain.setValueAtTime(Math.max(g.gain.value, 0.0001), t); g.gain.linearRampToValueAtTime(tgt, t + phase.dur * 0.9); }); };
  } else { // bowls (default)
    wet.gain.value = 0.5;
    const cfg = mode === "sleep" ? { f: [98, 146.83, 196], lo: 280, hi: 520, peak: 0.16, low: 0.05, noise: 0.016, nf: 320, bin: 396, bout: 264, vol: 0.05 } : { f: [146.83, 220, 293.66], lo: 480, hi: 940, peak: 0.2, low: 0.06, noise: 0.012, nf: 520, bin: 528, bout: 396, vol: 0.085 };
    const padFilter = ctx.createBiquadFilter(); padFilter.type = "lowpass"; padFilter.frequency.value = cfg.lo; padFilter.Q.value = 0.7;
    const padGain = ctx.createGain(); padGain.gain.value = 0.0001; padFilter.connect(padGain); padGain.connect(bus); padGain.connect(wet); fades.push(padGain);
    cfg.f.forEach((fr) => [-6, 6].forEach((dt) => { const o = ctx.createOscillator(); o.type = "sine"; o.frequency.value = fr; o.detune.value = dt + (Math.random() * 2 - 1); o.connect(padFilter); startSrc(o); }));
    const nsx = ctx.createBufferSource(); nsx.buffer = buffers.brown; nsx.loop = true; const nfl = ctx.createBiquadFilter(); nfl.type = "lowpass"; nfl.frequency.value = cfg.nf; const ng = ctx.createGain(); ng.gain.value = 0.0001; nsx.connect(nfl); nfl.connect(ng); ng.connect(bus); startSrc(nsx); fades.push(ng); ng.gain.exponentialRampToValueAtTime(cfg.noise, ctx.currentTime + 4);
    const strike = (f0, done) => pingNote(ctx, master, reverb, { freq: f0, partials: BOWL_PARTIALS(done), attack: 0.05, vol: cfg.vol * (done ? 1.15 : 1) });
    api.onPhase = (phase) => { const t = ctx.currentTime; let gt, ft; if (phase.key === "inhale") { gt = cfg.peak; ft = cfg.hi; strike(cfg.bin, false); } else if (phase.key === "exhale") { gt = cfg.low; ft = cfg.lo; strike(cfg.bout, false); } else if (phase.tone === "cool") { gt = cfg.peak * 0.95; ft = cfg.hi * 0.9; } else { gt = cfg.low; ft = cfg.lo; } const g = padGain.gain; g.cancelScheduledValues(t); g.setValueAtTime(Math.max(g.value, 0.0001), t); g.linearRampToValueAtTime(gt, t + phase.dur * 0.95); padFilter.frequency.cancelScheduledValues(t); padFilter.frequency.setValueAtTime(padFilter.frequency.value, t); padFilter.frequency.linearRampToValueAtTime(ft, t + phase.dur * 0.95); };
    api.onStart = () => strike(cfg.bin * 0.5, false);
    api.onDone = () => { if (mode === "breathe") { strike(cfg.bin * 0.75, true); pingNote(ctx, master, reverb, { freq: cfg.bin * 1.12, partials: [{ r: 1, g: 0.6, d: 5 }], attack: 0.06, vol: cfg.vol }); } };
    api.soften = () => { const t = ctx.currentTime; const g = padGain.gain; g.cancelScheduledValues(t); g.setValueAtTime(Math.max(g.value, 0.0001), t); g.linearRampToValueAtTime(cfg.low * 0.7, t + 1.4); };
  }
  return api;
}

export default function Lull() {
  const HI = prefersReduced ? 1.06 : 1.18;
  const LO = prefersReduced ? 0.92 : 0.72;

  const PATTERNS = useMemo(() => ({
    breathe: {
      calm: { name: "Calm", ratio: "4 · 7 · 8", phases: [{ key: "inhale", label: "Breathe in", dur: 4, scale: HI, tone: "cool" }, { key: "hold", label: "Hold", dur: 7, scale: HI, tone: "cool" }, { key: "exhale", label: "Breathe out", dur: 8, scale: LO, tone: "warm" }] },
      steady: { name: "Steady", ratio: "4 · 4 · 4 · 4", phases: [{ key: "inhale", label: "Breathe in", dur: 4, scale: HI, tone: "cool" }, { key: "hold", label: "Hold", dur: 4, scale: HI, tone: "cool" }, { key: "exhale", label: "Breathe out", dur: 4, scale: LO, tone: "warm" }, { key: "hold", label: "Hold", dur: 4, scale: LO, tone: "warm" }] },
      ease: { name: "Ease", ratio: "4 · 6", phases: [{ key: "inhale", label: "Breathe in", dur: 4, scale: HI, tone: "cool" }, { key: "exhale", label: "Breathe out", dur: 6, scale: LO, tone: "warm" }] },
    },
    sleep: {
      drift: { name: "Drift", ratio: "4 · 8", phases: [{ key: "inhale", label: "Breathe in", dur: 4, scale: HI, tone: "cool" }, { key: "exhale", label: "Let go", dur: 8, scale: LO, tone: "warm" }] },
      calm: { name: "Calm", ratio: "4 · 7 · 8", phases: [{ key: "inhale", label: "Breathe in", dur: 4, scale: HI, tone: "cool" }, { key: "hold", label: "Hold", dur: 7, scale: HI, tone: "cool" }, { key: "exhale", label: "Let go", dur: 8, scale: LO, tone: "warm" }] },
    },
  }), [HI, LO]);

  const [mode, setMode] = useState("breathe");
  const [themeId, setThemeId] = useState("aurora");
  const [screen, setScreen] = useState("home");
  const [patternId, setPatternId] = useState("calm");
  const [durationMin, setDurationMin] = useState(3);
  const [soundOn, setSoundOn] = useState(true);
  const [scapeId, setScapeId] = useState("bowls");

  const [phaseLabel, setPhaseLabel] = useState("Breathe in");
  const [tone, setTone] = useState("cool");
  const [orb, setOrb] = useState({ scale: LO, dur: 4, ease: "ease" });
  const [remaining, setRemaining] = useState(durationMin * 60);
  const [progress, setProgress] = useState(0);
  const [paused, setPaused] = useState(false);
  const [sleepVeil, setSleepVeil] = useState(0);

  const phasesRef = useRef([]); const idxRef = useRef(0); const elapsedRef = useRef(0); const targetRef = useRef(0);
  const pausedRef = useRef(false); const phaseTimeout = useRef(null); const tickRef = useRef(null);
  const soundRef = useRef(soundOn); const modeRef = useRef(mode);
  const audioRef = useRef(null); const nodesRef = useRef(null); const scapeRef = useRef(null); const brownRef = useRef(null); const whiteRef = useRef(null); const scapeIdRef = useRef("bowls");

  useEffect(() => { soundRef.current = soundOn; }, [soundOn]);
  useEffect(() => { modeRef.current = mode; }, [mode]);
  useEffect(() => { scapeIdRef.current = scapeId; }, [scapeId]);

  const clearTimers = useCallback(() => {
    if (phaseTimeout.current) clearTimeout(phaseTimeout.current);
    if (tickRef.current) clearInterval(tickRef.current);
    phaseTimeout.current = null; tickRef.current = null;
  }, []);

  // ---------- audio engine ----------
  const ensureAudio = () => {
    try {
      if (!audioRef.current) { const Ctx = window.AudioContext || window.webkitAudioContext; if (!Ctx) return; audioRef.current = new Ctx(); }
      const ctx = audioRef.current;
      if (!nodesRef.current) {
        const master = ctx.createGain(); master.gain.value = soundRef.current ? 0.45 : 0.0001; master.connect(ctx.destination);
        const reverb = ctx.createConvolver(); reverb.buffer = makeIR(ctx, 3.4, 2.4);
        const reverbGain = ctx.createGain(); reverbGain.gain.value = 0.6; reverb.connect(reverbGain); reverbGain.connect(master);
        nodesRef.current = { master, reverb, reverbGain };
      }
      if (!brownRef.current) brownRef.current = makeBrownNoise(ctx, 3); if (!whiteRef.current) whiteRef.current = makeWhiteNoise(ctx, 3);
      if (ctx.state === "suspended") ctx.resume();
    } catch (e) {}
  };
  const buildAmbience = () => {
    if (!audioRef.current || !nodesRef.current || scapeRef.current) return;
    scapeRef.current = createSoundscape(scapeIdRef.current, audioRef.current, nodesRef.current.master, nodesRef.current.reverb, { white: whiteRef.current, brown: brownRef.current }, modeRef.current);
  };
  const teardownAmbience = (fade = 1.2) => { try { if (scapeRef.current) scapeRef.current.stop(fade); } catch (e) {} scapeRef.current = null; };
  const breathAudio = (phase) => { try { if (scapeRef.current) scapeRef.current.onPhase(phase, modeRef.current); } catch (e) {} };
  const softenAmbience = () => { try { if (scapeRef.current && scapeRef.current.soften) scapeRef.current.soften(); } catch (e) {} };
  const bowl = (type) => { try { if (!soundRef.current || !scapeRef.current) return; if (type === "start" && scapeRef.current.onStart) scapeRef.current.onStart(); else if (type === "done" && scapeRef.current.onDone) scapeRef.current.onDone(); } catch (e) {} };

  useEffect(() => () => { clearTimers(); try { teardownAmbience(0.1); } catch (e) {} try { if (audioRef.current) audioRef.current.close(); } catch (e) {} }, [clearTimers]);
  useEffect(() => {
    if (screen === "done" && mode === "sleep") { const id = requestAnimationFrame(() => setSleepVeil(1)); return () => cancelAnimationFrame(id); }
    setSleepVeil(0);
  }, [screen, mode]);

  // ---------- breathing engine ----------
  const runPhase = useCallback(() => {
    const phase = phasesRef.current[idxRef.current]; if (!phase) return;
    setPhaseLabel(phase.label); setTone(phase.tone);
    setOrb({ scale: phase.scale, dur: phase.dur, ease: phase.key === "hold" ? "linear" : "cubic-bezier(0.45,0,0.55,1)" });
    breathAudio(phase);
    phaseTimeout.current = setTimeout(() => {
      const finished = phasesRef.current[idxRef.current];
      if (elapsedRef.current >= targetRef.current && finished.key === "exhale") { finishSession(); return; }
      idxRef.current = (idxRef.current + 1) % phasesRef.current.length; runPhase();
    }, phase.dur * 1000);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const startTick = useCallback(() => {
    if (tickRef.current) clearInterval(tickRef.current);
    tickRef.current = setInterval(() => {
      if (pausedRef.current) return;
      elapsedRef.current += 0.2;
      setRemaining(Math.max(targetRef.current - elapsedRef.current, 0));
      setProgress(Math.min(elapsedRef.current / targetRef.current, 1));
    }, 200);
  }, []);

  const startSession = () => {
    const p = PATTERNS[mode][patternId];
    phasesRef.current = p.phases; idxRef.current = 0; elapsedRef.current = 0; targetRef.current = durationMin * 60;
    pausedRef.current = false; setPaused(false); setRemaining(targetRef.current); setProgress(0); setScreen("active");
    ensureAudio(); if (soundRef.current) { buildAmbience(); bowl("start"); }
    startTick(); runPhase();
  };
  const pauseSession = () => { pausedRef.current = true; setPaused(true); if (phaseTimeout.current) clearTimeout(phaseTimeout.current); setPhaseLabel("Paused"); setOrb({ scale: prefersReduced ? 0.95 : 0.92, dur: 0.8, ease: "ease" }); softenAmbience(); };
  const resumeSession = () => { pausedRef.current = false; setPaused(false); ensureAudio(); if (soundRef.current && !scapeRef.current) buildAmbience(); runPhase(); };
  const goHome = () => { clearTimers(); pausedRef.current = false; setPaused(false); teardownAmbience(0.9); setScreen("home"); setOrb({ scale: LO, dur: 1, ease: "ease" }); setRemaining(durationMin * 60); setProgress(0); };
  function finishSession() { clearTimers(); pausedRef.current = false; setPaused(false); if (modeRef.current === "breathe") bowl("done"); teardownAmbience(modeRef.current === "sleep" ? 3.4 : 1.6); setScreen("done"); }
  const switchMode = (m) => { if (m === mode) return; clearTimers(); teardownAmbience(0.4); setMode(m); setScreen("home"); setPatternId(DEFAULT_PATTERN[m]); setDurationMin(DEFAULT_DUR[m]); setRemaining(DEFAULT_DUR[m] * 60); setProgress(0); setTone("cool"); setOrb({ scale: LO, dur: 1, ease: "ease" }); };
  const toggleSound = () => {
    ensureAudio(); const next = !soundOn; setSoundOn(next); soundRef.current = next;
    if (nodesRef.current && audioRef.current) { const t = audioRef.current.currentTime; const g = nodesRef.current.master.gain; g.cancelScheduledValues(t); g.setValueAtTime(Math.max(g.value, 0.0001), t); g.linearRampToValueAtTime(next ? 0.45 : 0.0001, t + 0.6); }
    if (screen === "active") { if (next) buildAmbience(); else teardownAmbience(0.6); }
  };
  const fmt = (s) => { s = Math.max(0, Math.ceil(s)); const m = Math.floor(s / 60); return `${m}:${String(s % 60).padStart(2, "0")}`; };

  // ---------- visuals ----------
  const th = THEMES[themeId];
  const baseStyle = STYLES[th.style];
  const isCool = tone === "cool";
  const idle = screen === "home";
  const active = screen === "active";
  const night = mode === "sleep";
  const sleepDone = screen === "done" && night;
  const breatheDone = screen === "done" && !night;
  const showStage = screen !== "done" || night;
  const dim = night ? 0.9 : 1;
  const orbBase = night ? ORB_BASE_NIGHT : ORB_BASE_DAY;
  const coolOp = (isCool ? 1 : 0.14) * (night ? 0.7 : 1);
  const warmOp = (isCool ? 0.14 : 1) * (night ? 0.7 : 1);

  // night: soften (fewer arms, more blur) and slow the swirl right down
  const stl = night
    ? { armsA: Math.min(baseStyle.armsA, 4), armsB: Math.min(baseStyle.armsB, 6), blurA: baseStyle.blurA + 4, blurB: baseStyle.blurB + 3, spinA: baseStyle.spinA * 1.7, spinB: baseStyle.spinB * 1.7, soft: baseStyle.soft + 4 }
    : baseStyle;
  const filtA = night ? "smokeAN" : "smokeA";
  const filtB = night ? "smokeBN" : "smokeB";
  const sheenOp = night ? 0.16 : 0.34;
  const useCool = night ? th.nightCoolRGB : th.coolRGB;
  const useWarm = night ? th.nightWarmRGB : th.warmRGB;
  const glowCool = night ? th.coolGlowNight : th.coolGlow;
  const glowWarm = night ? th.warmGlowNight : th.warmGlow;
  const coreCool = night ? th.coreCoolNight : th.coreCool;
  const coreWarm = night ? th.coreWarmNight : th.coreWarm;
  const blobCool = night ? th.blobCoolNight : th.blobCool;
  const blobWarm = night ? th.blobWarmNight : th.blobWarm;
  const tintCool = night ? th.tintCoolNight : th.tintCool;
  const tintWarm = night ? th.tintWarmNight : th.tintWarm;
  const amb1 = night ? th.amb1Night : th.amb1;
  const amb2 = night ? th.amb2Night : th.amb2;
  const ringFrom = night ? th.ringFromNight : th.ringFrom;
  const ringTo = night ? th.ringToNight : th.ringTo;

  const cA = conic(useCool, stl.armsA, night ? 0.72 : 0.85), wA = conic(useWarm, stl.armsA, night ? 0.74 : 0.85);
  const cB = conic(useCool, stl.armsB, night ? 0.58 : 0.7), wB = conic(useWarm, stl.armsB, night ? 0.6 : 0.7);

  const S = 300, ORB = 200, R = 142;
  const C = 2 * Math.PI * R;
  const pats = PATTERNS[mode];

  const root = { minHeight: "100vh", width: "100%", display: "flex", alignItems: "center", justifyContent: "center", position: "relative", overflow: "hidden", background: night ? th.rootNight : th.rootDay, color: "#F3EFFF", fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", Roboto, sans-serif', WebkitFontSmoothing: "antialiased", transition: "background 1.4s ease" };
  const frame = { position: "relative", zIndex: 2, width: "100%", maxWidth: 460, minHeight: "100vh", padding: "26px 26px 40px", display: "flex", flexDirection: "column", alignItems: "center" };
  const css = `
    * { box-sizing: border-box; }
    body { margin: 0; }
    @keyframes orbIdle { 0%,100% { transform: scale(0.9);} 50% { transform: scale(0.985);} }
    @keyframes drift1 { 0%,100% { transform: translate(0,0);} 50% { transform: translate(40px,-30px);} }
    @keyframes drift2 { 0%,100% { transform: translate(0,0);} 50% { transform: translate(-50px,40px);} }
    @keyframes swirlSpin { from { transform: rotate(0deg);} to { transform: rotate(360deg);} }
    @keyframes swirlSpinRev { from { transform: rotate(360deg);} to { transform: rotate(0deg);} }
    @keyframes coreScale { 0%,100% { transform: scale(0.95);} 50% { transform: scale(1.1);} }
    .orb-idle { animation: orbIdle 7s ease-in-out infinite; }
    .amb1 { animation: drift1 24s ease-in-out infinite; }
    .amb2 { animation: drift2 30s ease-in-out infinite; }
    .lull-btn { font-family: inherit; cursor: pointer; border: none; background: none; color: inherit; }
    .lull-btn:focus-visible, .lull-seg:focus-visible, .lull-dot:focus-visible { outline: 2px solid rgba(255,255,255,0.7); outline-offset: 3px; border-radius: 14px; }
    .lull-seg, .lull-dot { font-family: inherit; cursor: pointer; }
    .lull-cta { -webkit-tap-highlight-color: transparent; background-color: rgba(255,255,255,0.05); background-image: linear-gradient(177deg, rgba(255,255,255,0.30) 0%, rgba(255,255,255,0.07) 38%, rgba(255,255,255,0.02) 64%, rgba(255,255,255,0.13) 100%), radial-gradient(120% 80% at 50% 104%, rgba(255,255,255,0.16), transparent 62%); border: 1px solid rgba(255,255,255,0.28); -webkit-backdrop-filter: blur(16px) saturate(190%); backdrop-filter: blur(16px) saturate(190%); }
    .lull-cta::before { content: ""; position: absolute; left: 0; right: 0; top: 0; height: 46%; border-radius: inherit; background: linear-gradient(180deg, rgba(255,255,255,0.45), rgba(255,255,255,0) 100%); opacity: 0.55; pointer-events: none; }
    .lull-cta:active { transform: translateY(1px) scale(0.985); animation: lullGlow 1.1s ease; }
    @media (hover: hover) { .lull-cta:hover { transform: translateY(-1px); filter: brightness(1.07) saturate(1.12) drop-shadow(0 0 22px var(--glow, #9D8CFF)); } }
    @keyframes lullGlow { 0% { filter: brightness(1) saturate(1); } 45% { filter: brightness(1.1) saturate(1.16) drop-shadow(0 0 24px var(--glow, #9D8CFF)); } 100% { filter: brightness(1) saturate(1); } }
    @media (prefers-reduced-motion: reduce) { .lull-cta:active { animation: none; } }
    ::selection { background: rgba(255,158,125,0.35); }
    @media (prefers-reduced-motion: reduce) { .orb-idle,.amb1,.amb2 { animation: none !important; } }
  `;
  const segWrap = { display: "flex", gap: 8, width: "100%", background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", borderRadius: 18, padding: 6 };
  const seg = (sel) => ({ flex: 1, padding: "12px 8px", borderRadius: 13, border: "1px solid transparent", background: sel ? "rgba(255,255,255,0.10)" : "transparent", color: sel ? "#F8F5FF" : "rgba(243,239,255,0.5)", transition: "background .35s ease, color .35s ease", display: "flex", flexDirection: "column", alignItems: "center", gap: 3 });
  const glassBtn = { "--glow": ringFrom, "--glow2": ringTo, position: "relative", overflow: "hidden", padding: "17px 0", width: "100%", borderRadius: 999, color: "#FBFAFF", fontSize: 16.5, fontWeight: 600, letterSpacing: 0.8, boxShadow: `0 14px 46px ${ringFrom}40, 0 6px 18px ${ringTo}30, 0 1px 0 rgba(255,255,255,0.18), inset 0 1.4px 0.5px rgba(255,255,255,0.66), inset 0 -1.2px 1px rgba(255,255,255,0.30), inset 0 0 18px rgba(255,255,255,0.10), inset 0 -14px 26px rgba(0,0,0,0.18)`, transition: "transform .2s cubic-bezier(.2,.8,.2,1), box-shadow .3s ease, filter .45s ease" };
  const textBtn = { padding: "12px 18px", color: "rgba(243,239,255,0.5)", fontSize: 14, letterSpacing: 0.3 };

  // a rotating, turbulence-displaced, masked smoke layer (cool + warm crossfaded)
  const smokeLayer = (coolBg, warmBg, blur, spin, rev, filterId, mask) => (
    <div style={{ position: "absolute", inset: "-38%", borderRadius: "50%", zIndex: 2, animation: prefersReduced ? "none" : `${rev ? "swirlSpinRev" : "swirlSpin"} ${spin}s linear infinite`, filter: `${filterId ? `url(#${filterId}) ` : ""}blur(${blur}px)`, WebkitMaskImage: mask, maskImage: mask, WebkitMaskRepeat: "no-repeat", maskRepeat: "no-repeat", willChange: "transform" }}>
      <div style={{ position: "absolute", inset: 0, backgroundImage: coolBg, opacity: coolOp, transition: "opacity 1.2s ease", mixBlendMode: "screen" }} />
      <div style={{ position: "absolute", inset: 0, backgroundImage: warmBg, opacity: warmOp, transition: "opacity 1.2s ease", mixBlendMode: "screen" }} />
    </div>
  );

  const tagline = active ? `${pats[patternId].name} · ${pats[patternId].ratio}` : night ? "A slow exhale into sleep." : "A minute to breathe.";

  return (
    <div style={root}>
      <style>{css}</style>

      {/* smoke filters */}
      <svg width="0" height="0" style={{ position: "absolute" }} aria-hidden="true">
        <defs>
          <filter id="smokeA" x="-45%" y="-45%" width="190%" height="190%" colorInterpolationFilters="sRGB">
            <feTurbulence type="fractalNoise" baseFrequency="0.007 0.011" numOctaves="3" seed="7" result="n">
              {!prefersReduced && (<animate attributeName="baseFrequency" dur="56s" values="0.006 0.010;0.011 0.008;0.006 0.010" repeatCount="indefinite" />)}
            </feTurbulence>
            <feDisplacementMap in="SourceGraphic" in2="n" scale="54" xChannelSelector="R" yChannelSelector="G" />
          </filter>
          <filter id="smokeB" x="-45%" y="-45%" width="190%" height="190%" colorInterpolationFilters="sRGB">
            <feTurbulence type="fractalNoise" baseFrequency="0.019 0.023" numOctaves="2" seed="11" result="n">
              {!prefersReduced && (<animate attributeName="baseFrequency" dur="38s" values="0.018 0.022;0.024 0.019;0.018 0.022" repeatCount="indefinite" />)}
            </feTurbulence>
            <feDisplacementMap in="SourceGraphic" in2="n" scale="28" xChannelSelector="R" yChannelSelector="G" />
          </filter>
          <filter id="smokeAN" x="-45%" y="-45%" width="190%" height="190%" colorInterpolationFilters="sRGB">
            <feTurbulence type="fractalNoise" baseFrequency="0.006 0.009" numOctaves="2" seed="9" result="n">
              {!prefersReduced && (<animate attributeName="baseFrequency" dur="96s" values="0.005 0.008;0.008 0.006;0.005 0.008" repeatCount="indefinite" />)}
            </feTurbulence>
            <feDisplacementMap in="SourceGraphic" in2="n" scale="36" xChannelSelector="R" yChannelSelector="G" />
          </filter>
          <filter id="smokeBN" x="-45%" y="-45%" width="190%" height="190%" colorInterpolationFilters="sRGB">
            <feTurbulence type="fractalNoise" baseFrequency="0.013 0.017" numOctaves="2" seed="13" result="n">
              {!prefersReduced && (<animate attributeName="baseFrequency" dur="72s" values="0.012 0.016;0.018 0.013;0.012 0.016" repeatCount="indefinite" />)}
            </feTurbulence>
            <feDisplacementMap in="SourceGraphic" in2="n" scale="18" xChannelSelector="R" yChannelSelector="G" />
          </filter>
        </defs>
      </svg>

      <div className="amb1" style={{ position: "absolute", top: "-10%", left: "-15%", width: 520, height: 520, borderRadius: "50%", background: amb1, filter: "blur(20px)", zIndex: 0, transition: "background 1.4s ease" }} />
      <div className="amb2" style={{ position: "absolute", bottom: "-12%", right: "-18%", width: 560, height: 560, borderRadius: "50%", background: amb2, filter: "blur(20px)", zIndex: 0, transition: "background 1.4s ease" }} />
      <div style={{ position: "absolute", inset: 0, background: isCool ? tintCool : tintWarm, transition: "background 1.5s ease", zIndex: 1, pointerEvents: "none" }} />

      <div style={frame}>
        <div style={{ position: "relative", width: "100%", display: "flex", alignItems: "center", justifyContent: "center", minHeight: 36, marginBottom: 8 }}>
          <span style={{ fontSize: 14, letterSpacing: 6, textTransform: "uppercase", fontWeight: 500, opacity: 0.82, paddingLeft: 6 }}>Lull</span>
          <button className="lull-btn" aria-label={soundOn ? "Mute sound" : "Unmute sound"} aria-pressed={soundOn} onClick={toggleSound} style={{ position: "absolute", right: 0, padding: 8, opacity: 0.7, display: "flex" }}>{soundOn ? <Volume2 size={20} /> : <VolumeX size={20} />}</button>
        </div>

        {screen !== "done" && (<p style={{ fontSize: 13, opacity: 0.45, margin: "2px 0 0", letterSpacing: 0.3, minHeight: 18 }}>{tagline}</p>)}

        {screen === "home" && (
          <div style={{ ...segWrap, maxWidth: 220, marginTop: 14 }}>
            {["breathe", "sleep"].map((m) => { const sel = mode === m; return (<button key={m} className="lull-seg lull-btn" aria-pressed={sel} onClick={() => switchMode(m)} style={seg(sel)}><span style={{ fontSize: 14, fontWeight: 500, textTransform: "capitalize" }}>{m}</span></button>); })}
          </div>
        )}

        {showStage && (
          <div style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14, width: "100%", opacity: dim, transition: "opacity 1.2s ease" }}>
            <div style={{ position: "relative", width: S, height: S, display: "flex", alignItems: "center", justifyContent: "center" }}>
              <svg width={S} height={S} style={{ position: "absolute", inset: 0, transform: "rotate(-90deg)" }}>
                <circle cx={S / 2} cy={S / 2} r={R} fill="none" stroke="rgba(243,239,255,0.10)" strokeWidth={2} />
                <circle cx={S / 2} cy={S / 2} r={R} fill="none" stroke="url(#ring)" strokeWidth={3} strokeLinecap="round" strokeDasharray={C} strokeDashoffset={C * (1 - (active ? progress : screen === "done" ? 1 : 0))} style={{ transition: "stroke-dashoffset .3s linear", opacity: active || screen === "done" ? 1 : 0 }} />
                <defs><linearGradient id="ring" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stopColor={ringFrom} /><stop offset="100%" stopColor={ringTo} /></linearGradient></defs>
              </svg>

              <div className={idle ? "orb-idle" : ""} style={{ width: ORB, height: ORB, borderRadius: "50%", position: "relative", display: "flex", alignItems: "center", justifyContent: "center", willChange: "transform", ...(idle ? {} : { transform: `scale(${orb.scale})`, transition: `transform ${orb.dur}s ${orb.ease}` }) }}>
                <div style={{ position: "absolute", inset: -46, borderRadius: "50%", background: isCool ? glowCool : glowWarm, filter: "blur(36px)", transition: "background 1.2s ease", zIndex: 0 }} />
                <div style={{ position: "absolute", inset: 0, borderRadius: "50%", overflow: "hidden", zIndex: 1, boxShadow: "inset 0 0 42px rgba(0,0,0,0.6), inset 0 1px 14px rgba(255,255,255,0.12)" }}>
                  <div style={{ position: "absolute", inset: 0, background: orbBase, transition: "background 1.2s ease" }} />
                  {/* lit core */}
                  <div style={{ position: "absolute", inset: "-6%", zIndex: 1, animation: prefersReduced ? "none" : "coreScale 9s ease-in-out infinite" }}>
                    <div style={{ position: "absolute", inset: 0, backgroundImage: coreCool, opacity: coolOp, transition: "opacity 1.2s ease" }} />
                    <div style={{ position: "absolute", inset: 0, backgroundImage: coreWarm, opacity: warmOp, transition: "opacity 1.2s ease" }} />
                  </div>
                  {/* smoke: soft density, coarse curls, fine filaments */}
                  {smokeLayer(blobCool, blobWarm, stl.soft, stl.spinA * 1.3, false, null, MASK_SOFT)}
                  {smokeLayer(cA, wA, stl.blurA, stl.spinA, false, filtA, MASK_A)}
                  {smokeLayer(cB, wB, stl.blurB, stl.spinB, true, filtB, MASK_B)}
                  {/* liquid-glass shell — per-theme character: sheen, holographic veil, dispersion rim, Fresnel edge, dual glints */}
                  <div style={{ position: "absolute", inset: 0, borderRadius: "50%", background: `radial-gradient(circle at ${th.glass.sheen}, rgba(255,255,255,${sheenOp}), rgba(255,255,255,0) ${th.glass.spread}%)`, zIndex: 4 }} />
                  <div style={{ position: "absolute", inset: 0, borderRadius: "50%", background: "radial-gradient(circle at 50% 90%, rgba(255,255,255,0.12), rgba(255,255,255,0) 34%)", zIndex: 4 }} />
                  {th.glass.holo > 0 && (<div style={{ position: "absolute", inset: 0, borderRadius: "50%", background: `conic-gradient(from ${th.glass.rim + 40}deg at 50% 50%, #ff9ecb, #ffe8a8, #b6ffc0, #9fe4ff, #d4b8ff, #ff9ecb)`, mixBlendMode: "screen", opacity: night ? th.glass.holo * 0.6 : th.glass.holo, zIndex: 4 }} />)}
                  <div style={{ position: "absolute", inset: 0, borderRadius: "50%", zIndex: 5, background: `conic-gradient(from ${th.glass.rim}deg at 50% 50%, #ff6ea6, #ffd98a, #9bff9e, #74d4ff, #b88cff, #ff6ea6)`, WebkitMaskImage: "radial-gradient(closest-side, transparent 68%, #000 85%, #000 95%, transparent 100%)", maskImage: "radial-gradient(closest-side, transparent 68%, #000 85%, #000 95%, transparent 100%)", mixBlendMode: "screen", filter: "blur(2px)", opacity: night ? th.glass.irid * 0.6 : th.glass.irid }} />
                  <div style={{ position: "absolute", inset: 0, borderRadius: "50%", zIndex: 6, boxShadow: "inset 0 6px 16px -5px rgba(255,255,255,0.55), inset 0 -11px 22px -8px rgba(255,255,255,0.32), inset 0 0 0 1.5px rgba(255,255,255,0.30), inset 0 0 12px rgba(255,255,255,0.10)" }} />
                  <div style={{ position: "absolute", inset: 0, borderRadius: "50%", background: `radial-gradient(circle at ${th.glass.gx}% ${th.glass.gy}%, rgba(255,255,255,${sheenOp * 1.7}), rgba(255,255,255,0) 13%)`, zIndex: 7 }} />
                  {th.glass.g2 > 0 && (<div style={{ position: "absolute", inset: 0, borderRadius: "50%", background: "radial-gradient(circle at 67% 73%, rgba(255,255,255,0.5), rgba(255,255,255,0) 7%)", zIndex: 7, opacity: night ? th.glass.g2 * 0.6 : th.glass.g2 }} />)}
                </div>
              </div>

              <div style={{ position: "absolute", textAlign: "center", zIndex: 6, pointerEvents: "none" }}>
                {active ? (<div style={{ fontSize: 29, fontWeight: 200, letterSpacing: 1, textShadow: "0 2px 22px rgba(0,0,0,0.65)" }}>{phaseLabel}</div>)
                  : sleepDone ? null : (<>
                    <div style={{ fontSize: 22, fontWeight: 300, letterSpacing: 0.5, textShadow: "0 2px 20px rgba(0,0,0,0.6)" }}>{pats[patternId].name}</div>
                    <div style={{ fontSize: 12, letterSpacing: 3, opacity: 0.75, marginTop: 4, textShadow: "0 1px 14px rgba(0,0,0,0.6)" }}>{pats[patternId].ratio}</div></>)}
              </div>
            </div>
            <div style={{ fontSize: 15, opacity: 0.65, fontVariantNumeric: "tabular-nums", letterSpacing: 1, minHeight: 22 }}>{active ? fmt(remaining) : ""}</div>
          </div>
        )}

        {screen === "home" && (
          <div style={{ width: "100%", display: "flex", flexDirection: "column", gap: 12 }}>
            <div style={{ display: "flex", gap: 12, justifyContent: "center", padding: "2px 0 4px" }}>
              {Object.entries(THEMES).map(([id, t]) => { const sel = themeId === id; return (
                <button key={id} className="lull-dot lull-btn" aria-label={`Orb theme: ${t.name}`} aria-pressed={sel} title={t.name} onClick={() => setThemeId(id)} style={{ width: 30, height: 30, borderRadius: "50%", padding: 0, backgroundImage: t.swatch, border: "1px solid rgba(255,255,255,0.25)", boxShadow: sel ? "0 0 0 2px rgba(255,255,255,0.9), 0 3px 12px rgba(0,0,0,0.45)" : "0 2px 8px rgba(0,0,0,0.35)", transform: sel ? "scale(1.14)" : "scale(1)", transition: "transform .2s ease, box-shadow .2s ease" }} />); })}
            </div>
            <div style={segWrap}>
              {Object.entries(pats).map(([id, p]) => { const sel = patternId === id; return (<button key={id} className="lull-seg lull-btn" aria-pressed={sel} onClick={() => setPatternId(id)} style={seg(sel)}><span style={{ fontSize: 14, fontWeight: 500 }}>{p.name}</span><span style={{ fontSize: 11, opacity: 0.7, letterSpacing: 1 }}>{p.ratio}</span></button>); })}
            </div>
            <div style={segWrap}>
              {DURATIONS[mode].map((m) => { const sel = durationMin === m; const big = m >= 60 ? m / 60 : m; const unit = m >= 60 ? "hr" : "min"; return (<button key={m} className="lull-seg lull-btn" aria-pressed={sel} onClick={() => { setDurationMin(m); setRemaining(m * 60); }} style={seg(sel)}><span style={{ fontSize: 16, fontWeight: 500 }}>{big}</span><span style={{ fontSize: 11, opacity: 0.6, letterSpacing: 1 }}>{unit}</span></button>); })}
            </div>
            <div style={{ display: "flex", flexWrap: "wrap", gap: 7, justifyContent: "center", paddingTop: 2 }}>
              {SOUND.map((o) => { const sel = scapeId === o.id; return (
                <button key={o.id} className="lull-seg lull-btn" aria-pressed={sel} onClick={() => setScapeId(o.id)} style={{ padding: "7px 13px", borderRadius: 999, fontSize: 12.5, letterSpacing: 0.3, background: sel ? "rgba(255,255,255,0.12)" : "rgba(255,255,255,0.04)", border: "1px solid " + (sel ? "rgba(255,255,255,0.28)" : "rgba(255,255,255,0.08)"), color: sel ? "#F8F5FF" : "rgba(243,239,255,0.55)", transition: "background .25s ease, color .25s ease, border-color .25s ease" }}>{o.name}</button>); })}
            </div>
            {scapeId === "binaural" && (<p style={{ fontSize: 12, opacity: 0.55, textAlign: "center", margin: "2px 0 0", letterSpacing: 0.3 }}>Best with headphones</p>)}
            <button className="lull-btn lull-cta" onClick={startSession} style={{ ...glassBtn, marginTop: 4 }}>Begin</button>
          </div>
        )}

        {screen === "active" && (
          <div style={{ width: "100%", display: "flex", flexDirection: "column", alignItems: "center", gap: 6 }}>
            <button className="lull-btn lull-cta" onClick={paused ? resumeSession : pauseSession} style={{ ...glassBtn, maxWidth: 240 }}>{paused ? "Resume" : "Pause"}</button>
            <button className="lull-btn" onClick={goHome} style={textBtn}>End session</button>
          </div>
        )}

        {breatheDone && (
          <div style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", textAlign: "center", gap: 10, width: "100%" }}>
            <div style={{ width: 96, height: 96, borderRadius: "50%", marginBottom: 14, backgroundImage: th.warmGrad, boxShadow: `0 0 60px ${th.ringTo}66` }} />
            <div style={{ fontSize: 28, fontWeight: 300, letterSpacing: 0.5 }}>That's it.</div>
            <p style={{ fontSize: 14, opacity: 0.6, margin: 0, maxWidth: 260 }}>You gave yourself {durationMin} {durationMin === 1 ? "minute" : "minutes"}. Carry it with you.</p>
            <div style={{ display: "flex", flexDirection: "column", gap: 8, width: "100%", maxWidth: 240, marginTop: 26 }}>
              <button className="lull-btn lull-cta" onClick={startSession} style={glassBtn}>Again</button>
              <button className="lull-btn" onClick={goHome} style={textBtn}>Done</button>
            </div>
          </div>
        )}
      </div>

      {sleepDone && (
        <div onClick={goHome} role="button" aria-label="Exit" style={{ position: "fixed", inset: 0, zIndex: 50, display: "flex", alignItems: "center", justifyContent: "center", background: "#050302", opacity: sleepVeil, transition: "opacity 3.4s ease", cursor: "pointer" }}>
          <span style={{ fontSize: 16, fontWeight: 300, letterSpacing: 3, color: "rgba(243,239,255,0.5)", opacity: sleepVeil, transition: "opacity 4s ease 1s" }}>Sleep well.</span>
        </div>
      )}
    </div>
  );
}
