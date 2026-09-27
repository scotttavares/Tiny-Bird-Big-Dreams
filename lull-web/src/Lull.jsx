import { useState, useRef, useEffect, useMemo, useCallback } from "react";
import { Volume2, VolumeX, Sun, Moon, CalendarDays, Waves } from "lucide-react";
import { Capacitor } from "@capacitor/core";
import { Purchases, LOG_LEVEL } from "@revenuecat/purchases-capacitor";

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
    name: s.name, style: s.style, coolRGB: s.cool, warmRGB: s.warm, glass: s.glass, bloom: s.bloom,
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
  aurora: makeTheme({ name: "Aurora", style: "nebula", cool: [[157, 140, 255], [96, 150, 255], [214, 150, 255]], warm: [[255, 186, 150], [255, 130, 110], [255, 214, 176]], ring: ["#9D8CFF", "#FF9E7D"], day: ["#1c1133", "#0a0613", "#070410"], night: ["#120a22", "#080510", "#05030c"], bloom: [[198,182,255],[111,178,255],[255,143,206],[119,240,208],[255,190,148]], glass: { irid: 0.40, rim: 200, sheen: "33% 25%", spread: 44, gx: 31, gy: 23, g2: 0, holo: 0 } }),
  tide: makeTheme({ name: "Tide", style: "filament", cool: [[120, 210, 255], [80, 160, 245], [110, 255, 225]], warm: [[255, 205, 150], [255, 150, 120], [255, 225, 180]], ring: ["#6FE0FF", "#FFB27A"], day: ["#09202e", "#06121d", "#040b13"], night: ["#06141d", "#040c14", "#03080e"], bloom: [[120,210,255],[110,255,225],[130,180,255],[120,240,235],[170,225,255]], glass: { irid: 0.72, rim: 150, sheen: "28% 20%", spread: 36, gx: 26, gy: 19, g2: 0.9, holo: 0.18 } }),
  sunfire: makeTheme({ name: "Sunfire", style: "filament", cool: [[255, 140, 200], [210, 120, 255], [255, 120, 160]], warm: [[255, 170, 90], [255, 110, 70], [255, 200, 120]], ring: ["#FF8CC8", "#FF7E46"], day: ["#2a0f1c", "#160812", "#0c040a"], night: ["#1e0a15", "#0f060d", "#080308"], bloom: [[255,150,200],[210,120,255],[255,140,170],[255,180,120],[255,205,150]], glass: { irid: 0.30, rim: 290, sheen: "37% 24%", spread: 40, gx: 35, gy: 21, g2: 0.5, holo: 0.06 } }),
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
const DURATIONS = { breathe: [1, 3, 5], meditate: [3, 5, 10], sleep: [30, 60, 360, 480] };
const DEFAULT_PATTERN = { breathe: "calm", meditate: "body", sleep: "drift" };
const DEFAULT_DUR = { breathe: 3, meditate: 5, sleep: 30 };
// One-line "what it's for", shown under the picker for the selected pattern.
const PATTERN_INFO = {
  breathe: {
    calm: "A long, slow exhale to unwind.",
    steady: "Balanced box breathing for focus.",
    ease: "A gentle everyday reset.",
    coherence: "Slow, even breaths for balance.",
    custom: "Your own rhythm.",
  },
  meditate: {
    body: "A slow scan from head to toe.",
    gratitude: "Rest on what you're thankful for.",
    presence: "Come back to the here and now.",
  },
  sleep: {
    drift: "A long exhale to help you let go.",
    calm: "The classic wind down for sleep.",
    noise: "A steady sound for sleep.",
    custom: "Your own rhythm.",
  },
};
// "Get ready" pre-roll lines, chosen by how the person answered the pre-session calm scale
// (Tense 1 .. Calm 5, or null when skipped). One is picked at random each time. Dash-free, one line.
const READY_LINES = {
  tense: [
    "You're safe here. Let's slow it all down.",
    "Unclench your jaw. Drop your shoulders.",
    "Nothing to solve right now. Only breathe.",
    "Let's set down what you're holding.",
    "One slow breath, then another.",
  ],
  mid: [
    "A few quiet minutes, just for you.",
    "Arrive here. The rest can wait.",
    "Let's find a slower rhythm together.",
    "Settle in. There's no rush.",
    "Soften your gaze and begin.",
  ],
  calm: [
    "Let's deepen the calm you brought.",
    "Stay a while in this stillness.",
    "Carry this quiet a little further.",
    "You're already here. Let's go deeper.",
    "Savor this steadiness.",
  ],
  general: [
    "Get comfortable. Let's breathe.",
    "A minute to breathe, just for you.",
    "Arrive here. The rest can wait.",
    "Soften, settle, and begin.",
    "Let's slow down together.",
  ],
};
function pickReadyLine(mood) {
  const b = (typeof mood !== "number") ? READY_LINES.general : mood <= 2 ? READY_LINES.tense : mood >= 4 ? READY_LINES.calm : READY_LINES.mid;
  return b[Math.floor(Math.random() * b.length)];
}
// Soundscapes: three ship free; others unlock via a sound pack (or the Everything bundle).
// Each is generated procedurally in createSoundscape — no audio files. `pack` names the pack it belongs to.
const SOUND = [
  { id: "bowls", name: "Bowls", tag: "Singing bowls", glyph: "🎵", tint: "#9a86ff", img: "/assets/sound-bowls.webp", free: true, bed: true },
  { id: "handpan", name: "Handpan", tag: "Hand drum", glyph: "🪘", tint: "#ffb27a", img: "/assets/sound-handpan.webp", free: true, bed: true },
  { id: "binaural", name: "Binaural", tag: "Deep tones", glyph: "🎧", tint: "#6fb2ff", free: true, bed: true },
  { id: "noise", name: "White noise", tag: "Steady hush", glyph: "🌫️", tint: "#aebdd6", free: true, bed: true },
  { id: "rain", name: "Rain", tag: "Steady rainfall", glyph: "🌧️", tint: "#7fa8d8", pack: "nature", bed: true },
  { id: "lightrain", name: "Light rain", tag: "Soft patter for sleep", glyph: "💧", tint: "#9fc4e0", pack: "nature", bed: true },
  { id: "ocean", name: "Ocean", tag: "Rolling waves", glyph: "🌊", tint: "#4fc4d0", pack: "nature", bed: true },
  { id: "forest", name: "Forest", tag: "Calm woodland", glyph: "🌲", tint: "#79c88a", pack: "nature", bed: true },
  { id: "fire", name: "Fire", tag: "Crackling hearth", glyph: "🔥", tint: "#ff8a5c", pack: "nature", bed: true },
];
const SOUND_BY_ID = Object.fromEntries(SOUND.map((s) => [s.id, s]));
function soundChip(id, size) {
  const s = SOUND_BY_ID[id] || SOUND[0]; const t = s.tint || "#9a86ff";
  const base = { width: size, height: size, borderRadius: "50%", flex: "0 0 auto", overflow: "hidden", boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.09), 0 2px 10px rgba(0,0,0,0.25)" };
  if (s.img) return <div style={base}><img src={s.img} alt="" draggable="false" style={{ width: "100%", height: "100%", objectFit: "cover", display: "block" }} /></div>;
  return <div style={{ ...base, display: "flex", alignItems: "center", justifyContent: "center", fontSize: Math.round(size * 0.42), lineHeight: 1, background: `radial-gradient(circle at 50% 38%, ${t}55, ${t}1f 60%, rgba(8,5,16,0.62) 100%)` }}>{s.glyph}</div>;
}
// ---------- rings orb ----------
// A rosette of large, thin, translucent circle outlines (screen-blended so overlaps glow) around a
// dark hollow centre — the "woven light-rings" look. Each ring takes a colour from the orb's palette;
// the whole group rotates slowly. Interior is transparent, so the orb's own dark ground shows through.
function ringsSVG(palette, opts = {}) {
  const pal = (palette && palette.length) ? palette : ["#e0929e", "#e6935e", "#8fb0e0", "#5ececf", "#efe6f2", "#c98ad0"];
  const n = 9, R = 40, off = 13;
  const circles = [];
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2 + 0.4;
    const cx = 50 + Math.cos(a) * off, cy = 50 + Math.sin(a) * off;
    const rr = R * (0.9 + 0.2 * ((i * 41 % 100) / 100));
    const bright = i % 3 === 0;
    circles.push(<circle key={i} cx={cx.toFixed(2)} cy={cy.toFixed(2)} r={rr.toFixed(2)} fill="none" stroke={pal[i % pal.length]} strokeWidth={bright ? 0.9 : 0.6} opacity={bright ? 0.62 : 0.42} />);
  }
  return (
    <svg viewBox="0 0 100 100" preserveAspectRatio="xMidYMid meet" style={{ position: "absolute", inset: 0, width: "100%", height: "100%", display: "block", overflow: "visible" }}>
      <g style={{ mixBlendMode: "screen", transformBox: "fill-box", transformOrigin: "center", animation: opts.anim ? "ringSpin 64s linear infinite" : "none" }}>{circles}</g>
    </svg>
  );
}
const SOUND_PACKS = {
  nature: { name: "Nature Pack", tag: "Rain, light rain, ocean, forest & fire", price: 0.99, sounds: ["rain", "lightrain", "ocean", "forest", "fire"] },
};
const SOUND_PACK_ORDER = ["nature"];
const FREE_SOUNDS = SOUND.filter((s) => s.free).map((s) => s.id);
const SOUNDS_OWNED_KEY = "lull.soundsOwned.v1";
function loadOwnedSounds() { try { const r = JSON.parse(localStorage.getItem(SOUNDS_OWNED_KEY) || "null"); const saved = Array.isArray(r) ? r.filter((id) => SOUND_BY_ID[id]) : []; const merged = [...FREE_SOUNDS]; saved.forEach((id) => { if (!merged.includes(id)) merged.push(id); }); return merged; } catch (e) { return [...FREE_SOUNDS]; } }
const HIST_KEY = "lull.sessions.v1";
const DAY_MS = 86400000;
function loadHist() { try { const r = JSON.parse(localStorage.getItem(HIST_KEY) || "[]"); return Array.isArray(r) ? r : []; } catch (e) { return []; } }
function saveHist(list) { try { localStorage.setItem(HIST_KEY, JSON.stringify(list.slice(-300))); } catch (e) {} }
function minutesSince(list, sinceMs) { return list.reduce((a, s) => a + (s && s.min && (!sinceMs || s.t >= sinceMs) ? s.min : 0), 0); }
// Optional, private mood check-in: a 1–5 calm scale before and after a session. Never required, never shared.
const MOOD_LABELS = { 1: "Tense", 2: "Uneasy", 3: "Okay", 4: "Settled", 5: "Calm" };
function moodLift(list) { let sum = 0, n = 0; for (const s of list) { if (s && typeof s.moodBefore === "number" && typeof s.moodAfter === "number") { sum += s.moodAfter - s.moodBefore; n++; } } return n ? { avg: sum / n, n } : null; }
const CUSTOM_KEY = "lull.custom.v1";
function loadCustom() { try { const r = JSON.parse(localStorage.getItem(CUSTOM_KEY) || "null"); return r && typeof r === "object" ? r : null; } catch (e) { return null; } }
function saveCustom(c) { try { localStorage.setItem(CUSTOM_KEY, JSON.stringify(c)); } catch (e) {} }
const SLEEPDUR_KEY = "lull.sleepDur.v1";   // a custom sleep length (minutes) — e.g. run all night
function loadSleepDur() { try { const r = JSON.parse(localStorage.getItem(SLEEPDUR_KEY) || "null"); return (typeof r === "number" && r > 0) ? r : null; } catch (e) { return null; } }
function saveSleepDur(m) { try { localStorage.setItem(SLEEPDUR_KEY, JSON.stringify(m)); } catch (e) {} }
function fmtDur(m) { if (m >= 60) { const h = m / 60; return { big: (Number.isInteger(h) ? String(h) : h.toFixed(1)), unit: "hr" }; } return { big: String(m), unit: "min" }; }
// ---------- orbs ----------
// The orb you breathe with is a cosmetic choice. "aurora" (the Siri-style glass orb) ships free;
// others can be unlocked. Purchases are scaffolded locally here — real charging (Apple In-App
// Purchase on iOS, Stripe on web) is wired separately; `unlockOrb` is the single seam for it.
// kind "image": a generated orb picture (masked, counter-rotating swirl). kind "glow": a coded
// symmetric ring of the `colors` palette on a white (white:true) or deep (white:false) ground.
// Every orb is a real generated swirl (Aurora quality). Three different swirl compositions
// (glass/b/c/d), each hue-shifted into its own colour family and cropped bubble-less like Aurora.
// Each orb carries its own `bg` (a dark, tinted ground that matches it). "coded" is the original
// aurora-bloom orb (recoloured by the theme dots); it has no bg so it uses the theme's own ground.
const ORBS = {
  aurora:  { name: "Aurora",  tag: "Flowing swirl", kind: "image", src: "/assets/orb-glass.webp",  price: 0,   zoom: 1.5, noBubble: true, hue: 0,             ring: ["#5ec8ff", "#9a7bff", "#ff6ec0"], bg: "radial-gradient(125% 120% at 50% 16%, #1a1030 0%, #0a0613 58%, #060310 100%)" },
  bloom:   { name: "Bloom",   tag: "Original · themeable", kind: "coded", price: 0 },
  ember:   { name: "Ember",   tag: "Warm fire",     kind: "image", src: "/assets/orb-swirl-d.webp", price: 0.5, zoom: 1.5, noBubble: true, hue: 150, sat: 1.15, ring: ["#ffd27a", "#ff9a5c", "#ff5c7d"], bg: "radial-gradient(125% 120% at 50% 16%, #2a1208 0%, #150806 58%, #0a0403 100%)" },
  verdant: { name: "Verdant", tag: "Emerald bloom", kind: "image", src: "/assets/orb-swirl-c.webp", price: 0.5, zoom: 1.5, noBubble: true, hue: 260, sat: 1.12, ring: ["#7fe6a0", "#a8e86e", "#5ad0c0"], bg: "radial-gradient(125% 120% at 50% 16%, #0c2418 0%, #07140d 58%, #030b07 100%)" },
  blossom: { name: "Blossom", tag: "Rose petals",   kind: "image", src: "/assets/orb-swirl-b.webp", price: 0.5, zoom: 1.5, noBubble: true, hue: 90,  sat: 1.12, ring: ["#ff8fbf", "#ff6ea0", "#ffa8d8"], bg: "radial-gradient(125% 120% at 50% 16%, #2a1024 0%, #150813 58%, #0a040b 100%)" },
  glacier: { name: "Glacier", tag: "Icy current",   kind: "image", src: "/assets/orb-swirl-c.webp", price: 0.5, zoom: 1.5, noBubble: true, hue: 310, sat: 1.1,  ring: ["#5ee0ff", "#66d6e6", "#7fb8ff"], bg: "radial-gradient(125% 120% at 50% 16%, #0a2432 0%, #06131c 58%, #03080e 100%)" },
  nebula:  { name: "Nebula",  tag: "Cosmic violet", kind: "image", src: "/assets/orb-swirl-d.webp", price: 0.5, zoom: 1.5, noBubble: true, hue: 55,  sat: 1.12, ring: ["#b46eff", "#8a6eff", "#ff6ecd"], bg: "radial-gradient(125% 120% at 50% 16%, #1c1038 0%, #0e0722 58%, #060310 100%)" },
  // Particle spheres — a rotating cloud of glowing dots on a deep black ground.
  solstice: { name: "Solstice", tag: "Ember dust",   kind: "particles", dark: true, price: 0.5, thumb: "/assets/orb-thumb-solstice.png", palette: { top: [255, 150, 55],  mid: [255, 180, 120], bot: [255, 255, 255] }, ring: ["#ffb04a", "#ff8a3c", "#fff0d6"], bg: "radial-gradient(120% 120% at 50% 30%, #140b06 0%, #080402 60%, #020101 100%)" },
  frost:    { name: "Frost",    tag: "Ice dust",     kind: "particles", dark: true, price: 0.5, thumb: "/assets/orb-thumb-frost.png", palette: { top: [120, 205, 255], mid: [180, 228, 255], bot: [255, 255, 255] }, ring: ["#7fd0ff", "#b0e6ff", "#ffffff"], bg: "radial-gradient(120% 120% at 50% 30%, #06121e 0%, #03080f 60%, #010305 100%)" },
  nova:     { name: "Nova",     tag: "Stardust",     kind: "particles", dark: true, price: 0.5, thumb: "/assets/orb-thumb-nova.png", palette: { top: [190, 120, 255], mid: [230, 140, 230], bot: [255, 155, 210] }, ring: ["#b46eff", "#e08aff", "#ff8ec8"], bg: "radial-gradient(120% 120% at 50% 30%, #120826 0%, #080414 60%, #030108 100%)" },
  // Radiant image orbs — a pinwheel bloom and a wispy flare, on their own deep grounds.
  iris:     { name: "Iris",     tag: "Radiant bloom", kind: "image", src: "/assets/orb-iris.webp", price: 0.5, zoom: 1.35, noBubble: true, hue: 0, ring: ["#4fd0ff", "#b46eff", "#ff7ad0"], bg: "radial-gradient(125% 120% at 50% 16%, #16123a 0%, #0a0720 58%, #050310 100%)" },
  wisp:     { name: "Wisp",     tag: "Wisps of light", kind: "image", src: "/assets/orb-wisp.webp", price: 0.5, zoom: 1.35, noBubble: true, hue: 0, ring: ["#6ea8ff", "#a06eff", "#ff6ec8"], bg: "radial-gradient(120% 120% at 50% 30%, #0e0a2a 0%, #070518 60%, #030110 100%)" },
  // Light orb — a pastel swirl on a soft bright ground (flips the UI to dark ink; drifting pastel blobs behind it).
  dawn:     { name: "Dawn",     tag: "Soft daylight", kind: "image", src: "/assets/orb-dawn.webp", price: 0.5, zoom: 1.25, noBubble: true, hue: 0, light: true, ring: ["#5ab0f5", "#a97fe6", "#f58cb8"], bg: "radial-gradient(125% 120% at 50% 8%, #ffffff 0%, #fbf7ff 55%, #f1edfa 100%)" },
  // Aura Pack — premium generated "woven light-rings" orbs (image), each on its own deep ground.
  halo:     { name: "Halo",     tag: "Woven light",   kind: "image", src: "/assets/orb-halo.webp",   price: 0.5, zoom: 1.1, hue: 0, ring: ["#e0929e", "#8fb0e0", "#5ececf"], bg: "radial-gradient(125% 120% at 50% 20%, #0e1220 0%, #080b16 58%, #04060e 100%)" },
  prism:    { name: "Prism",    tag: "Spectrum halo", kind: "image", src: "/assets/orb-prism.webp",  price: 0.5, zoom: 1.1, hue: 0, ring: ["#ff9a9a", "#9be89b", "#7fb8ff"], bg: "radial-gradient(125% 120% at 50% 20%, #0b0910 0%, #070510 58%, #030208 100%)" },
  lagoon:   { name: "Lagoon",   tag: "Tidal rings",   kind: "image", src: "/assets/orb-lagoon.webp", price: 0.5, zoom: 1.1, hue: 0, ring: ["#5ec8ff", "#4fd0c0", "#bfeeff"], bg: "radial-gradient(125% 120% at 50% 20%, #06181f 0%, #04111a 58%, #02090f 100%)" },
  dusk:     { name: "Dusk",     tag: "Ember halo",    kind: "image", src: "/assets/orb-dusk.webp",   price: 0.5, zoom: 1.1, hue: 0, ring: ["#ff9a7a", "#ff6ea0", "#c79bff"], bg: "radial-gradient(125% 120% at 50% 20%, #140b16 0%, #0c0710 58%, #060309 100%)" },
};
const ORB_ORDER = ["aurora", "bloom", "ember", "verdant", "blossom", "glacier", "nebula", "iris", "dawn", "solstice", "frost", "nova", "wisp", "halo", "prism", "lagoon", "dusk"];
// ---------- packs & bundle ----------
// Orbs are sold in themed packs (one price unlocks every orb in the pack), plus a single
// "Everything" bundle that unlocks all orbs — and every future orb & sound we add — for one
// price. Aurora + Bloom ship free and belong to no pack. Pricing is scaffolded; real charging
// (Apple In-App Purchase on iOS, Stripe on web) wires into unlockPack/unlockBundle — the same
// seam as unlockOrb.
const PACKS = {
  swirls: { name: "Swirls Pack", tag: "Flowing colour orbs, each with its own sky", price: 0.99, orbs: ["ember", "verdant", "blossom", "glacier", "nebula", "iris", "dawn"] },
  cosmos: { name: "Cosmos Pack", tag: "Cosmic orbs on deep space", price: 0.99, orbs: ["solstice", "frost", "nova", "wisp"] },
  aura: { name: "Aura Pack", tag: "Woven translucent light-rings", price: 0.99, orbs: ["halo", "prism", "lagoon", "dusk"] },
};
const PACK_ORDER = ["swirls", "cosmos", "aura"];
const BUNDLE = { name: "Everything", tag: "Every orb and sound, plus every future one we add", price: 3.99 };

// ---- In-App Purchases (RevenueCat on iOS; web falls back to local unlock until Stripe lands) ----
// This is the RevenueCat *public* iOS SDK key (safe to ship in the app). Paste yours (starts with
// "appl_") before building the release, or purchases stay in local-unlock mode.
const RC_IOS_KEY = "appl_REPLACE_WITH_YOUR_REVENUECAT_IOS_KEY";
const RC_ENTITLEMENT_EVERYTHING = "everything"; // RevenueCat entitlement the "Everything" bundle grants
// Product identifiers — must match App Store Connect AND RevenueCat exactly.
const IAP_PRODUCTS = {
  swirls: "com.tinybirdbigdreams.lull.pack.swirls",
  cosmos: "com.tinybirdbigdreams.lull.pack.cosmos",
  aura: "com.tinybirdbigdreams.lull.pack.aura",
  nature: "com.tinybirdbigdreams.lull.pack.nature",
  everything: "com.tinybirdbigdreams.lull.everything",
};
const PRODUCT_TO_UNLOCK = {
  [IAP_PRODUCTS.swirls]: { kind: "orb", pack: "swirls" },
  [IAP_PRODUCTS.cosmos]: { kind: "orb", pack: "cosmos" },
  [IAP_PRODUCTS.aura]: { kind: "orb", pack: "aura" },
  [IAP_PRODUCTS.nature]: { kind: "sound", pack: "nature" },
};
const iapLive = () => Capacitor.isNativePlatform() && RC_IOS_KEY.indexOf("REPLACE") === -1;
const FREE_ORBS = ORB_ORDER.filter((id) => (ORBS[id].price || 0) === 0); // ship unlocked (Aurora, Bloom)
const ORB_KEY = "lull.orb.v1";
const OWNED_KEY = "lull.orbsOwned.v1";
function loadOrb() { try { const v = localStorage.getItem(ORB_KEY); return v && ORBS[v] ? v : "aurora"; } catch (e) { return "aurora"; } }
function loadOwned() { try { const r = JSON.parse(localStorage.getItem(OWNED_KEY) || "null"); const saved = Array.isArray(r) ? r.filter((id) => ORBS[id]) : []; const merged = [...FREE_ORBS]; saved.forEach((id) => { if (!merged.includes(id)) merged.push(id); }); return merged; } catch (e) { return [...FREE_ORBS]; } }
function fmtPrice(p) { return p ? "$" + p.toFixed(2) : "Free"; }
function orbChip(id, size) {
  const o = ORBS[id] || ORBS.aurora;
  const base = { width: size, height: size, borderRadius: "50%", flex: "0 0 auto", overflow: "hidden", boxShadow: "0 2px 10px rgba(0,0,0,0.22)" };
  if (o.thumb) return <div style={base}><img src={o.thumb} alt="" draggable="false" style={{ width: "100%", height: "100%", objectFit: "cover", display: "block" }} /></div>;
  if (o.kind === "image") return <div style={base}><img src={o.src} alt="" draggable="false" style={{ width: "100%", height: "100%", objectFit: "cover", display: "block", transform: o.zoom ? `scale(${o.zoom})` : undefined, transformOrigin: "center", filter: o.hue ? `hue-rotate(${o.hue}deg) saturate(${o.sat || 1.1})` : undefined }} /></div>;
  if (o.kind === "particles") { const t = o.palette.top.join(","), bt = o.palette.bot.join(","); return <div style={{ ...base, background: `radial-gradient(58% 52% at 50% 33%, rgba(${t},0.95), transparent 62%), radial-gradient(54% 50% at 50% 78%, rgba(${bt},0.92), transparent 62%), #060409` }} />; }
  if (o.kind === "plasma") return <div style={{ ...base, background: "radial-gradient(circle at 44% 38%, #12336a 0%, #0a1428 62%), radial-gradient(circle at 50% 50%, transparent 74%, rgba(150,232,255,0.9) 93%, transparent 100%), #050308" }} />;
  if (o.kind === "rings") return <div style={{ ...base, position: "relative", background: "radial-gradient(circle at 50% 45%, #14111f, #06040e)" }}>{ringsSVG(o.palette, { anim: false })}</div>;
  if (o.kind === "coded") return <div style={{ ...base, background: "radial-gradient(circle at 38% 30%, #b8a4ff, transparent 54%), radial-gradient(circle at 68% 40%, #6fb2ff, transparent 54%), radial-gradient(circle at 62% 72%, #78f0d0, transparent 54%), radial-gradient(circle at 32% 66%, #ffb696, transparent 54%), radial-gradient(circle at 50% 46%, rgba(255,255,255,0.7), transparent 34%), #0a0613" }} />;
  const cols = o.colors || ["140,180,255", "196,155,255", "255,158,203", "134,235,205"];
  const layers = cols.map((c, i, arr) => { const a = (i / arr.length) * Math.PI * 2 - Math.PI / 2; const x = (50 + Math.cos(a) * 24).toFixed(0); const y = (50 + Math.sin(a) * 24).toFixed(0); return `radial-gradient(42% 42% at ${x}% ${y}%, rgba(${c},0.92), transparent 60%)`; });
  layers.push("radial-gradient(30% 30% at 50% 50%, rgba(255,255,255,0.85), transparent 60%)");
  return <div style={{ ...base, background: layers.join(", ") + ", " + (o.white ? "#ffffff" : "#0e0b1a") }} />;
}
// ---------- particle sphere (canvas) ----------
// A rotating sphere of ~2200 glowing dots (fibonacci distribution + jitter), coloured by a
// vertical gradient (bright caps, dim equator) with depth-based size/alpha and a soft twinkle.
function buildParticles(n) {
  const p = [], ga = Math.PI * (3 - Math.sqrt(5));
  for (let i = 0; i < n; i++) {
    let y = 1 - (i / (n - 1)) * 2;
    const r0 = Math.sqrt(Math.max(0, 1 - y * y));
    const th = ga * i + (Math.random() - 0.5) * 0.5;
    const rr = 0.93 + Math.random() * 0.12;
    const x = Math.cos(th) * r0, z = Math.sin(th) * r0; y += (Math.random() - 0.5) * 0.04;
    p.push({ x: x * rr, y: y * rr, z: z * rr, tw: Math.random() * 6.28, sp: 0.6 + Math.random() * 0.9, big: Math.random() < 0.06 });
  }
  return p;
}
function drawParticleSphere(ctx, size, pts, pal, t) {
  const CX = size / 2, CY = size / 2, R = size * 0.42;
  const ang = t * 0.26, ca = Math.cos(ang), sa = Math.sin(ang), tilt = -0.30, ct = Math.cos(tilt), st = Math.sin(tilt);
  ctx.clearRect(0, 0, size, size); ctx.globalCompositeOperation = "lighter";
  const lerp = (a, b, k) => [a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k];
  const col3 = (ny) => ny < 0.5 ? lerp(pal.top, pal.mid, ny / 0.5) : lerp(pal.mid, pal.bot, (ny - 0.5) / 0.5);
  for (const p of pts) {
    const X = p.x * ca - p.z * sa, Z = p.x * sa + p.z * ca, Y = p.y;
    const Y2 = Y * ct - Z * st, Z2 = Y * st + Z * ct;
    const sx = CX + X * R, sy = CY + Y2 * R, depth = (Z2 + 1) / 2, ny = (Y2 + 1) / 2;
    const cap = Math.pow(Math.abs(Y2), 1.05);
    const tw = 0.65 + 0.35 * Math.sin(t * 2.2 * p.sp + p.tw);
    let a = (0.16 + 0.95 * cap) * (0.4 + 0.6 * depth) * tw;
    if (p.big) a = Math.min(1, a * 1.7);
    const c = col3(Math.min(1, Math.max(0, ny)));
    const sz = (0.8 + 2.0 * depth) * (p.big ? 1.7 : 1);
    ctx.fillStyle = "rgba(" + (c[0] | 0) + "," + (c[1] | 0) + "," + (c[2] | 0) + "," + Math.min(1, a).toFixed(3) + ")";
    ctx.fillRect(sx - sz / 2, sy - sz / 2, sz, sz);
  }
  ctx.globalCompositeOperation = "source-over";
}
function customRatio(c) { return [c.inhale, c.hold, c.exhale, c.hold2].filter((n) => n > 0).join(" · "); }
function customPhases(c, HI, LO, night) { const out = [{ key: "inhale", label: "Breathe in", dur: c.inhale, scale: HI, tone: "cool" }]; if (c.hold > 0) out.push({ key: "hold", label: "Hold", dur: c.hold, scale: HI, tone: "cool" }); out.push({ key: "exhale", label: night ? "Let go" : "Breathe out", dur: c.exhale, scale: LO, tone: "warm" }); if (c.hold2 > 0) out.push({ key: "hold", label: "Hold", dur: c.hold2, scale: LO, tone: "warm" }); return out; }

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

// Real recorded loops for nature sounds. Each carries a `gain` measured from the file offline (these
// recordings export very quiet — rain is ~22 dB down), baked in so playback needs no runtime decode.
// They play through an <audio> element tapped into the graph (createMediaElementSource) rather than
// fetch + decodeAudioData + BufferSource: the media element uses the browser's native streaming
// decoder, which plays MP3 reliably across Chrome, Safari and Firefox — decodeAudioData does not
// (it rejects some MP3s in Safari/Firefox and fails silently). Add ocean/forest/fire here as they land.
// A soft, steady hush generated at runtime (low-passed white noise) for the sleep "White noise" mode.
// Encoded as a WAV data URI so it plays through the same media-element path as the recorded beds —
// it keeps going with the screen off and shows lock-screen controls. Normalized to ~0.2 RMS.
function makeHushDataUri() {
  try {
    const sr = 44100, n = sr * 6; const d = new Float32Array(n);
    let prev = 0; for (let i = 0; i < n; i++) { const w = Math.random() * 2 - 1; prev = prev + 0.16 * (w - prev); d[i] = prev; }
    let sum = 0; for (let i = 0; i < n; i++) sum += d[i] * d[i]; const rms = Math.sqrt(sum / n) || 1;
    const g0 = 0.2 / rms; let peak = 0; for (let i = 0; i < n; i++) { const v = Math.abs(d[i] * g0); if (v > peak) peak = v; }
    const g = peak > 0.95 ? (0.95 / peak) * g0 : g0;
    const buf = new ArrayBuffer(44 + n * 2); const dv = new DataView(buf);
    const wr = (o, s) => { for (let i = 0; i < s.length; i++) dv.setUint8(o + i, s.charCodeAt(i)); };
    wr(0, "RIFF"); dv.setUint32(4, 36 + n * 2, true); wr(8, "WAVE"); wr(12, "fmt "); dv.setUint32(16, 16, true); dv.setUint16(20, 1, true); dv.setUint16(22, 1, true); dv.setUint32(24, sr, true); dv.setUint32(28, sr * 2, true); dv.setUint16(32, 2, true); dv.setUint16(34, 16, true); wr(36, "data"); dv.setUint32(40, n * 2, true);
    let o = 44; for (let i = 0; i < n; i++) { const s = Math.max(-1, Math.min(1, d[i] * g)); dv.setInt16(o, s < 0 ? s * 0x8000 : s * 0x7fff, true); o += 2; }
    let bin = ""; const u8 = new Uint8Array(buf); for (let i = 0; i < u8.length; i += 0x8000) bin += String.fromCharCode.apply(null, u8.subarray(i, i + 0x8000));
    return "data:audio/wav;base64," + btoa(bin);
  } catch (e) { return ""; }
}
let _hushUrl = null; const hushUrl = () => (_hushUrl || (_hushUrl = makeHushDataUri()));

const NATURE_AUDIO = {
  rain: { url: "/assets/rain.mp3", gain: 24 },
  lightrain: { url: "/assets/lightrain.wav", gain: 1.2 }, // soft, sparse rain for sleep (real recording, seamless loop)
  ocean: { url: "/assets/ocean.wav", gain: 1.8 }, // calm rolling ocean waves (real recording, seamless loop, no birds)
  forest: { url: "/assets/forest.wav", gain: 1.5 }, // calm real forest (ElevenLabs take, minimal processing)
  // Calmer, sleep-friendly fire: the source was compressed to tame the sharp snaps and low-passed for
  // warmth before export, so it needs no live limiter now — just a gentle level.
  fire: { url: "/assets/fire.wav", gain: 1.5 },
  // White noise: generated lazily on first use (url filled in by createNatureNode via hushUrl()).
  noise: { url: "", gain: 1.0 },
};
const NATURE_IDS = SOUND.filter((s) => NATURE_AUDIO[s.id] && s.id !== "noise").map((s) => s.id); // nature bed ids for the mixer (white noise is a single-sound pick, not a blend layer)

// Build one looping nature bed: <audio> → gain → (optional limiter) → out. `level` (0..1) scales the
// file's baked gain; `setLevel` adjusts it live. Shared by breathing sessions and the standalone mixer.
function createNatureNode(ctx, out, id, level) {
  const conf = NATURE_AUDIO[id]; if (!conf) return null;
  if (!conf.url && id === "noise") conf.url = hushUrl(); // generate the hush once, on first play
  if (!conf.url) return null;
  const g = ctx.createGain(); g.gain.value = 0.0001; g.connect(out);
  let head = g;
  if (conf.limit) {
    const lim = ctx.createDynamicsCompressor();
    lim.threshold.value = -10; lim.knee.value = 6; lim.ratio.value = 20; lim.attack.value = 0.003; lim.release.value = 0.25;
    lim.connect(g); head = lim;
  }
  const vg = ctx.createGain(); vg.gain.value = conf.gain * level; vg.connect(head);
  let el = null;
  try {
    el = new Audio(); el.src = conf.url; el.loop = true; el.preload = "auto";
    const node = ctx.createMediaElementSource(el); node.connect(vg);
    const p = el.play(); if (p && p.catch) p.catch(() => {});
    const t = ctx.currentTime; g.gain.cancelScheduledValues(t); g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(1, t + 1.4);
  } catch (e) {}
  return {
    el,
    setLevel(l) { try { vg.gain.setTargetAtTime(conf.gain * Math.max(0, l), ctx.currentTime, 0.08); } catch (e) {} },
    soften() { try { const t = ctx.currentTime; g.gain.cancelScheduledValues(t); g.gain.setValueAtTime(Math.max(g.gain.value, 0.0001), t); g.gain.linearRampToValueAtTime(0.55, t + 0.6); } catch (e) {} },
    pause() { try { if (el) el.pause(); } catch (e) {} },
    resume() { try { if (el) { const p = el.play(); if (p && p.catch) p.catch(() => {}); } } catch (e) {} },
    stop(fade = 1.4) { try { const t = ctx.currentTime; g.gain.cancelScheduledValues(t); g.gain.setValueAtTime(Math.max(g.gain.value, 0.0001), t); g.gain.exponentialRampToValueAtTime(0.0001, t + fade); } catch (e) {} if (el) { setTimeout(() => { try { el.pause(); } catch (e) {} }, (fade + 0.15) * 1000); } },
  };
}

function createSoundscape(id, ctx, master, reverb, buffers, mode, selfPlay) {
  // A saved mix bed: play several nature beds together, each at its own saved level.
  if (id && typeof id === "object" && id.mix) {
    const ns = [];
    Object.entries(id.mix).forEach(([sid, lvl]) => { if (NATURE_AUDIO[sid] && lvl > 0) { const n = createNatureNode(ctx, master, sid, lvl); if (n) ns.push(n); } });
    return { onPhase() {}, onStart() {}, onDone() {}, soften() { ns.forEach((n) => { try { n.soften(); } catch (e) {} }); }, pause() { ns.forEach((n) => { try { n.pause(); } catch (e) {} }); }, resume() { ns.forEach((n) => { try { n.resume(); } catch (e) {} }); }, stop(fade = 1.4) { ns.forEach((n) => { try { n.stop(fade); } catch (e) {} }); } };
  }
  // Nature sounds play from a real looping recording via a media element (see createNatureNode).
  if (NATURE_AUDIO[id]) {
    const n = createNatureNode(ctx, master, id, 1);
    return { onPhase() {}, onStart() {}, onDone() {}, soften() { if (n) n.soften(); }, pause() { if (n) n.pause(); }, resume() { if (n) n.resume(); }, stop(fade = 1.4) { if (n) n.stop(fade); } };
  }
  const bus = ctx.createGain(); bus.gain.value = 1; bus.connect(master);
  const wet = ctx.createGain(); wet.gain.value = 0.4; bus.connect(wet); wet.connect(reverb);
  const bedGain = ctx.createGain(); bedGain.gain.value = 1; bedGain.connect(bus);
  const timers = []; const srcs = []; const fades = []; let stopped = false; let paused = false; let base = 0.3;
  const startSrc = (x) => { try { x.start(); } catch (e) {} srcs.push(x); };
  const every = (fn, delay) => { const tick = () => { if (stopped) return; if (!paused) { try { fn(); } catch (e) {} } const n = typeof delay === "function" ? delay() : delay; timers.push(setTimeout(tick, n)); }; timers.push(setTimeout(tick, typeof delay === "function" ? delay() : delay)); };
  const swell = (phase) => { const t = ctx.currentTime; let tgt = base; if (phase.key === "inhale") tgt = base * 1.18; else if (phase.key === "exhale") tgt = base * 0.82; const g = bedGain.gain; g.cancelScheduledValues(t); g.setValueAtTime(Math.max(g.value, 0.0001), t); g.linearRampToValueAtTime(Math.max(tgt, 0.0001), t + phase.dur * 0.9); };
  const api = { onPhase() {}, onStart() {}, onDone() {}, soften() {}, pause() { paused = true; try { const t = ctx.currentTime; bus.gain.cancelScheduledValues(t); bus.gain.setValueAtTime(Math.max(bus.gain.value, 0.0001), t); bus.gain.exponentialRampToValueAtTime(0.0001, t + 0.35); } catch (e) {} }, resume() { paused = false; try { const t = ctx.currentTime; bus.gain.cancelScheduledValues(t); bus.gain.setValueAtTime(Math.max(bus.gain.value, 0.0001), t); bus.gain.exponentialRampToValueAtTime(1, t + 0.4); } catch (e) {} }, stop(fade = 1.2) { stopped = true; timers.forEach(clearTimeout); const t = ctx.currentTime; [bus, ...fades].forEach((g) => { try { g.gain.cancelScheduledValues(t); g.gain.setValueAtTime(Math.max(g.gain.value, 0.0001), t); g.gain.exponentialRampToValueAtTime(0.0001, t + fade); } catch (e) {} }); srcs.forEach((x) => { try { x.stop(t + fade + 0.1); } catch (e) {} }); } };

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
    // Sound-only: no breath to trigger notes, so play soft ones on a slow, random timer (a calm handpan bed).
    if (selfPlay) every(() => note(Math.random() < 0.5), () => 3200 + Math.random() * 5200);
  } else if (id === "binaural") {
    wet.gain.value = 0.15;
    const cfg = mode === "sleep" ? { f: 150, beat: 3.2 } : { f: 200, beat: 10 };
    const mk = (freq, pan) => { const o = ctx.createOscillator(); o.type = "sine"; o.frequency.value = freq; const pn = ctx.createStereoPanner(); pn.pan.value = pan; const g = ctx.createGain(); g.gain.value = 0.0001; o.connect(g); g.connect(pn); pn.connect(bus); startSrc(o); fades.push(g); g.gain.exponentialRampToValueAtTime(0.08, ctx.currentTime + 3); return g; };
    const gL = mk(cfg.f, -1); const gR = mk(cfg.f + cfg.beat, 1);
    const pad = ctx.createGain(); pad.gain.value = 0.0001; const po = ctx.createOscillator(); po.type = "sine"; po.frequency.value = cfg.f / 2; const plp = ctx.createBiquadFilter(); plp.type = "lowpass"; plp.frequency.value = 300; po.connect(plp); plp.connect(pad); pad.connect(bus); startSrc(po); fades.push(pad); pad.gain.exponentialRampToValueAtTime(0.04, ctx.currentTime + 4);
    const ns = ctx.createBufferSource(); ns.buffer = buffers.brown; ns.loop = true; const ng = ctx.createGain(); ng.gain.value = 0.008; ns.connect(ng); ng.connect(bus); startSrc(ns); fades.push(ng);
    api.onPhase = (phase) => { const t = ctx.currentTime; const tgt = phase.key === "inhale" ? 0.1 : phase.key === "exhale" ? 0.07 : 0.085; [gL, gR].forEach((g) => { g.gain.cancelScheduledValues(t); g.gain.setValueAtTime(Math.max(g.gain.value, 0.0001), t); g.gain.linearRampToValueAtTime(tgt, t + phase.dur * 0.9); }); };
  } else if (id === "rain") {
    // Steady rain: bright hiss (white noise, high-passed) over a distant low rumble, with occasional close drips.
    wet.gain.value = 0.22;
    const wns = ctx.createBufferSource(); wns.buffer = buffers.white; wns.loop = true;
    const hp = ctx.createBiquadFilter(); hp.type = "highpass"; hp.frequency.value = 780;
    const lp = ctx.createBiquadFilter(); lp.type = "lowpass"; lp.frequency.value = 6800;
    const wg = ctx.createGain(); wg.gain.value = 0.0001; wns.connect(hp); hp.connect(lp); lp.connect(wg); wg.connect(bus); startSrc(wns); fades.push(wg);
    wg.gain.exponentialRampToValueAtTime(mode === "sleep" ? 0.42 : 0.55, ctx.currentTime + 3);
    const bns = ctx.createBufferSource(); bns.buffer = buffers.brown; bns.loop = true; const blp = ctx.createBiquadFilter(); blp.type = "lowpass"; blp.frequency.value = 200; const bg = ctx.createGain(); bg.gain.value = 0.0001; bns.connect(blp); blp.connect(bg); bg.connect(bus); startSrc(bns); fades.push(bg); bg.gain.exponentialRampToValueAtTime(0.32, ctx.currentTime + 5);
    const drip = () => { const t0 = ctx.currentTime; const o = ctx.createOscillator(); o.type = "sine"; const f = 900 + Math.random() * 1500; o.frequency.setValueAtTime(f * 1.5, t0); o.frequency.exponentialRampToValueAtTime(f, t0 + 0.05); const g = ctx.createGain(); g.gain.setValueAtTime(0.0001, t0); g.gain.exponentialRampToValueAtTime(0.1, t0 + 0.005); g.gain.exponentialRampToValueAtTime(0.0001, t0 + 0.18); o.connect(g); g.connect(bus); g.connect(wet); o.start(t0); o.stop(t0 + 0.24); };
    every(() => { if (Math.random() < 0.7) drip(); }, () => 1200 + Math.random() * 2600);
    api.onPhase = (phase) => { const t = ctx.currentTime; const tgt = phase.key === "inhale" ? 0.62 : phase.key === "exhale" ? 0.44 : 0.55; const g = wg.gain; g.cancelScheduledValues(t); g.setValueAtTime(Math.max(g.value, 0.0001), t); g.linearRampToValueAtTime(mode === "sleep" ? tgt * 0.8 : tgt, t + phase.dur * 0.9); };
  } else if (id === "ocean") {
    // Waves: brown noise through a slow LFO-swept lowpass (swell in/out), with white-noise foam cresting on the same wave.
    wet.gain.value = 0.3;
    const bns = ctx.createBufferSource(); bns.buffer = buffers.brown; bns.loop = true; const lp = ctx.createBiquadFilter(); lp.type = "lowpass"; lp.frequency.value = 500; lp.Q.value = 0.6;
    const wg = ctx.createGain(); wg.gain.value = 0.6; bns.connect(lp); lp.connect(wg); wg.connect(bus); wg.connect(wet); startSrc(bns); fades.push(wg);
    const wns = ctx.createBufferSource(); wns.buffer = buffers.white; wns.loop = true; const whp = ctx.createBiquadFilter(); whp.type = "highpass"; whp.frequency.value = 1500; const fg = ctx.createGain(); fg.gain.setValueAtTime(0.14, ctx.currentTime); wns.connect(whp); whp.connect(fg); fg.connect(bus); startSrc(wns); fades.push(fg);
    const lfo = ctx.createOscillator(); lfo.type = "sine"; lfo.frequency.value = mode === "sleep" ? 0.06 : 0.09; const lfg = ctx.createGain(); lfg.gain.value = 320; lfo.connect(lfg); lfg.connect(lp.frequency); startSrc(lfo);
    const lfo2 = ctx.createOscillator(); lfo2.type = "sine"; lfo2.frequency.value = lfo.frequency.value; const lfo2g = ctx.createGain(); lfo2g.gain.value = 0.12; lfo2.connect(lfo2g); lfo2g.connect(fg.gain); startSrc(lfo2);
    api.onPhase = (phase) => { const t = ctx.currentTime; const tgt = phase.key === "inhale" ? 0.72 : phase.key === "exhale" ? 0.5 : 0.6; const g = wg.gain; g.cancelScheduledValues(t); g.setValueAtTime(Math.max(g.value, 0.0001), t); g.linearRampToValueAtTime(tgt, t + phase.dur * 0.9); };
  } else if (id === "forest") {
    // Woodland: soft LFO-drifting wind, plus random bird chirps (a few quick glissando notes). Birds rest in sleep mode.
    wet.gain.value = 0.35;
    const bns = ctx.createBufferSource(); bns.buffer = buffers.brown; bns.loop = true; const lp = ctx.createBiquadFilter(); lp.type = "lowpass"; lp.frequency.value = 480; const wg = ctx.createGain(); wg.gain.value = 0.0001; bns.connect(lp); lp.connect(wg); wg.connect(bus); startSrc(bns); fades.push(wg); wg.gain.exponentialRampToValueAtTime(mode === "sleep" ? 0.66 : 0.82, ctx.currentTime + 4);
    const wlfo = ctx.createOscillator(); wlfo.type = "sine"; wlfo.frequency.value = 0.05; const wlg = ctx.createGain(); wlg.gain.value = 180; wlfo.connect(wlg); wlg.connect(lp.frequency); startSrc(wlfo);
    const chirp = () => { const n = 2 + (Math.random() * 3 | 0); const base = 2200 + Math.random() * 1800; for (let i = 0; i < n; i++) { const t0 = ctx.currentTime + i * (0.06 + Math.random() * 0.05); const o = ctx.createOscillator(); o.type = "sine"; const f = base * (1 + (Math.random() * 0.3 - 0.1)); o.frequency.setValueAtTime(f * 1.12, t0); o.frequency.exponentialRampToValueAtTime(f, t0 + 0.04); const g = ctx.createGain(); g.gain.setValueAtTime(0.0001, t0); g.gain.exponentialRampToValueAtTime(mode === "sleep" ? 0.03 : 0.06, t0 + 0.01); g.gain.exponentialRampToValueAtTime(0.0001, t0 + 0.10); o.connect(g); g.connect(wet); g.connect(bus); o.start(t0); o.stop(t0 + 0.16); } };
    if (mode !== "sleep") every(() => { if (Math.random() < 0.75) chirp(); }, () => 2600 + Math.random() * 4200);
    api.onPhase = (phase) => { const t = ctx.currentTime; const tgt = phase.key === "inhale" ? 0.92 : 0.66; const g = wg.gain; g.cancelScheduledValues(t); g.setValueAtTime(Math.max(g.value, 0.0001), t); g.linearRampToValueAtTime(mode === "sleep" ? tgt * 0.7 : tgt, t + phase.dur * 0.9); };
  } else if (id === "fire") {
    // Hearth: a warm two-layer roar (low rumble + a wavering mid "body") under soft, clustered pops.
    wet.gain.value = 0.22;
    const bns = ctx.createBufferSource(); bns.buffer = buffers.brown; bns.loop = true; const lp = ctx.createBiquadFilter(); lp.type = "lowpass"; lp.frequency.value = 380; const rg = ctx.createGain(); rg.gain.value = 0.0001; bns.connect(lp); lp.connect(rg); rg.connect(bus); startSrc(bns); fades.push(rg); rg.gain.exponentialRampToValueAtTime(mode === "sleep" ? 0.72 : 0.9, ctx.currentTime + 3);
    const bns2 = ctx.createBufferSource(); bns2.buffer = buffers.brown; bns2.loop = true; const bpBody = ctx.createBiquadFilter(); bpBody.type = "bandpass"; bpBody.frequency.value = 700; bpBody.Q.value = 0.5; const bg2 = ctx.createGain(); bg2.gain.value = 0.0001; bns2.connect(bpBody); bpBody.connect(bg2); bg2.connect(bus); startSrc(bns2); fades.push(bg2); bg2.gain.exponentialRampToValueAtTime(0.34, ctx.currentTime + 4);
    const bodyLfo = ctx.createOscillator(); bodyLfo.type = "sine"; bodyLfo.frequency.value = 0.16; const bodyLfg = ctx.createGain(); bodyLfg.gain.value = 220; bodyLfo.connect(bodyLfg); bodyLfg.connect(bpBody.frequency); startSrc(bodyLfo);
    // one soft pop: brown-noise burst, eased (non-clicky) attack, warm low-mid band, quick natural decay.
    const pop = (amp) => { const t0 = ctx.currentTime; const src = ctx.createBufferSource(); src.buffer = buffers.brown; src.loop = true; src.playbackRate.value = 1.4 + Math.random() * 1.8; const bp = ctx.createBiquadFilter(); bp.type = "bandpass"; bp.frequency.value = 360 + Math.random() * 900; bp.Q.value = 1.1 + Math.random(); const g = ctx.createGain(); const a = 0.007 + Math.random() * 0.013; g.gain.setValueAtTime(0.0001, t0); g.gain.linearRampToValueAtTime(amp, t0 + a); g.gain.exponentialRampToValueAtTime(0.0001, t0 + a + 0.05 + Math.random() * 0.09); src.connect(bp); bp.connect(g); g.connect(bus); src.start(t0); src.stop(t0 + 0.3); };
    // clustered crackle: 1-4 soft pops per burst (rare louder one), with real gaps between bursts.
    const burst = () => { const n = 1 + (Math.random() * 3 | 0); for (let i = 0; i < n; i++) timers.push(setTimeout(() => { if (!stopped) pop(0.04 + (Math.random() < 0.18 ? Math.random() * 0.14 : Math.random() * 0.04)); }, i * (30 + Math.random() * 90))); };
    every(() => { if (Math.random() < 0.72) burst(); }, () => 320 + Math.random() * 900);
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
    // Sound-only: no breath to raise the pad or trigger strikes, so bring the pad up and ring soft bowls on a slow timer.
    if (selfPlay) { const t0 = ctx.currentTime; padGain.gain.cancelScheduledValues(t0); padGain.gain.setValueAtTime(0.0001, t0); padGain.gain.exponentialRampToValueAtTime(cfg.peak * 0.45, t0 + 4); every(() => strike(Math.random() < 0.5 ? cfg.bin : cfg.bout, false), () => 4200 + Math.random() * 6000); }
  }
  return api;
}

// First-run intro: a few calm slides shown before the home screen, remembered on the device.
const ONBOARD_SLIDES = [
  { eyebrow: "You made it here", title: ["Take a breath.", "You're here now."], body: "Whatever you carried in with you, set it down for a minute. This is a small, quiet place that asks nothing of you.", foot: "You don't have to hold it all." },
  { eyebrow: "Nothing to get right", title: ["Breathe with", "the light."], body: "Watch the orb rise and fall, and let your breath follow. There's no right way to do this, and slower is always enough.", foot: "Be gentle with yourself." },
  { eyebrow: "When the day winds down", title: ["Drift off", "to calm nights."], body: "Soft rain, distant waves, a warm fire. Let calm sound stay close and carry you into sleep, however far from home you are.", foot: "We're right here with you." },
];

export default function Lull() {
  const HI = prefersReduced ? 1.06 : 1.18;
  const LO = prefersReduced ? 0.92 : 0.72;
  const [customPat, setCustomPat] = useState(() => (typeof window !== "undefined" ? loadCustom() : null));
  const [showCustom, setShowCustom] = useState(false);
  const [draft, setDraft] = useState({ inhale: 4, hold: 7, exhale: 8, hold2: 0 });
  const [sleepCustomMin, setSleepCustomMin] = useState(() => (typeof window !== "undefined" ? loadSleepDur() : null));
  const [showSleepTime, setShowSleepTime] = useState(false);
  const [sleepDraft, setSleepDraft] = useState({ h: 8, m: 0 });

  const PATTERNS = useMemo(() => {
    const P = {
      breathe: {
        calm: { name: "Calm", ratio: "4 · 7 · 8", goal: "Ease anxiety", phases: [{ key: "inhale", label: "Breathe in", dur: 4, scale: HI, tone: "cool" }, { key: "hold", label: "Hold", dur: 7, scale: HI, tone: "cool" }, { key: "exhale", label: "Breathe out", dur: 8, scale: LO, tone: "warm" }] },
        steady: { name: "Steady", ratio: "4 · 4 · 4 · 4", goal: "Find focus", phases: [{ key: "inhale", label: "Breathe in", dur: 4, scale: HI, tone: "cool" }, { key: "hold", label: "Hold", dur: 4, scale: HI, tone: "cool" }, { key: "exhale", label: "Breathe out", dur: 4, scale: LO, tone: "warm" }, { key: "hold", label: "Hold", dur: 4, scale: LO, tone: "warm" }] },
        ease: { name: "Ease", ratio: "4 · 6", goal: "Everyday calm", phases: [{ key: "inhale", label: "Breathe in", dur: 4, scale: HI, tone: "cool" }, { key: "exhale", label: "Breathe out", dur: 6, scale: LO, tone: "warm" }] },
        coherence: { name: "Coherence", ratio: "5 · 5", goal: "Find balance", phases: [{ key: "inhale", label: "Breathe in", dur: 5, scale: HI, tone: "cool" }, { key: "exhale", label: "Breathe out", dur: 5, scale: LO, tone: "warm" }] },
      },
      // Guided meditations — a calm breath keeps the orb moving while short cues (the phase labels)
      // lead a body scan / gratitude / presence practice. Every cue pair ends on an exhale so the
      // session can finish cleanly whenever the timer runs out; cues loop for longer durations.
      meditate: {
        body: { name: "Body Scan", ratio: "Head to toe", goal: "Ground yourself", meditation: true, phases: [
          { key: "inhale", label: "Settle into your seat.", dur: 5, scale: HI, tone: "cool" }, { key: "exhale", label: "Let your shoulders drop.", dur: 6, scale: LO, tone: "warm" },
          { key: "inhale", label: "Notice your face and jaw.", dur: 5, scale: HI, tone: "cool" }, { key: "exhale", label: "Let them soften.", dur: 6, scale: LO, tone: "warm" },
          { key: "inhale", label: "Feel your chest and arms.", dur: 5, scale: HI, tone: "cool" }, { key: "exhale", label: "Release any holding.", dur: 6, scale: LO, tone: "warm" },
          { key: "inhale", label: "Notice your belly.", dur: 5, scale: HI, tone: "cool" }, { key: "exhale", label: "Let it rise and fall.", dur: 6, scale: LO, tone: "warm" },
          { key: "inhale", label: "Feel your legs, heavy.", dur: 5, scale: HI, tone: "cool" }, { key: "exhale", label: "Let them grow still.", dur: 6, scale: LO, tone: "warm" },
          { key: "inhale", label: "Sense your whole body.", dur: 5, scale: HI, tone: "cool" }, { key: "exhale", label: "At rest, at ease.", dur: 7, scale: LO, tone: "warm" } ] },
        gratitude: { name: "Gratitude", ratio: "Warm reflection", goal: "Lift your mood", meditation: true, phases: [
          { key: "inhale", label: "Take an easy breath.", dur: 5, scale: HI, tone: "cool" }, { key: "exhale", label: "Let the day slow down.", dur: 6, scale: LO, tone: "warm" },
          { key: "inhale", label: "Bring someone to mind.", dur: 5, scale: HI, tone: "cool" }, { key: "exhale", label: "Feel your thanks for them.", dur: 6, scale: LO, tone: "warm" },
          { key: "inhale", label: "Recall one small kindness.", dur: 5, scale: HI, tone: "cool" }, { key: "exhale", label: "Let it warm you.", dur: 6, scale: LO, tone: "warm" },
          { key: "inhale", label: "Notice something you have.", dur: 5, scale: HI, tone: "cool" }, { key: "exhale", label: "You'd miss if it were gone.", dur: 6, scale: LO, tone: "warm" },
          { key: "inhale", label: "Picture a place you love.", dur: 5, scale: HI, tone: "cool" }, { key: "exhale", label: "Rest there a moment.", dur: 6, scale: LO, tone: "warm" },
          { key: "inhale", label: "Include yourself, too.", dur: 5, scale: HI, tone: "cool" }, { key: "exhale", label: "You showed up today.", dur: 7, scale: LO, tone: "warm" } ] },
        presence: { name: "Presence", ratio: "Back to now", goal: "Come back to now", meditation: true, phases: [
          { key: "inhale", label: "Arrive where you are.", dur: 5, scale: HI, tone: "cool" }, { key: "exhale", label: "Nothing to fix right now.", dur: 6, scale: LO, tone: "warm" },
          { key: "inhale", label: "Notice three sounds.", dur: 5, scale: HI, tone: "cool" }, { key: "exhale", label: "Near, then far away.", dur: 6, scale: LO, tone: "warm" },
          { key: "inhale", label: "Feel where you meet the seat.", dur: 5, scale: HI, tone: "cool" }, { key: "exhale", label: "Let it hold you.", dur: 6, scale: LO, tone: "warm" },
          { key: "inhale", label: "Feel the air on your skin.", dur: 5, scale: HI, tone: "cool" }, { key: "exhale", label: "Cool in, warm out.", dur: 6, scale: LO, tone: "warm" },
          { key: "inhale", label: "Watch one whole breath.", dur: 5, scale: HI, tone: "cool" }, { key: "exhale", label: "Beginning to end.", dur: 6, scale: LO, tone: "warm" },
          { key: "inhale", label: "This moment is enough.", dur: 5, scale: HI, tone: "cool" }, { key: "exhale", label: "You're here.", dur: 7, scale: LO, tone: "warm" } ] },
      },
      sleep: {
        drift: { name: "Drift", ratio: "4 · 8", phases: [{ key: "inhale", label: "Breathe in", dur: 4, scale: HI, tone: "cool" }, { key: "exhale", label: "Let go", dur: 8, scale: LO, tone: "warm" }] },
        calm: { name: "Calm", ratio: "4 · 7 · 8", phases: [{ key: "inhale", label: "Breathe in", dur: 4, scale: HI, tone: "cool" }, { key: "hold", label: "Hold", dur: 7, scale: HI, tone: "cool" }, { key: "exhale", label: "Let go", dur: 8, scale: LO, tone: "warm" }] },
        noise: { name: "Sound only", ratio: "Any sound", soundOnly: true, phases: [{ key: "hold", label: "", dur: 6, scale: LO, tone: "cool" }] },
      },
    };
    if (customPat) {
      P.breathe.custom = { name: "Yours", ratio: customRatio(customPat), phases: customPhases(customPat, HI, LO, false) };
      P.sleep.custom = { name: "Yours", ratio: customRatio(customPat), phases: customPhases(customPat, HI, LO, true) };
    }
    return P;
  }, [HI, LO, customPat]);

  const [mode, setMode] = useState("breathe");
  const [orbId, setOrbId] = useState(loadOrb);          // which orb you breathe with
  const [ownedOrbs, setOwnedOrbs] = useState(loadOwned); // unlocked orb ids
  const [ownedSounds, setOwnedSounds] = useState(loadOwnedSounds); // unlocked sound ids
  const [bundleOwned, setBundleOwned] = useState(() => { try { return localStorage.getItem("lull.bundleOwned.v1") === "1"; } catch (e) { return false; } }); // "Everything" owned → unlocks all, incl. future
  const [orbStoreOpen, setOrbStoreOpen] = useState(false);
  const [themeId, setThemeId] = useState("aurora");
  const [screen, setScreen] = useState("home");
  const [patternId, setPatternId] = useState("calm");
  const [durationMin, setDurationMin] = useState(3);
  const [soundOn, setSoundOn] = useState(true);
  // A bed selection is a sound id ("rain") OR a saved mix ("mix:<presetId>").
  const [scapeId, setScapeId] = useState(() => { try { const s = localStorage.getItem("lull.scape.v1"); return (s && (SOUND_BY_ID[s] || s.slice(0, 4) === "mix:")) ? s : "bowls"; } catch (e) { return "bowls"; } });
  // Sound-only sleep ("Sound only") keeps its own bed, so a sleep sound never changes your breathing sound. Defaults to white noise.
  const [sleepScapeId, setSleepScapeId] = useState(() => { try { const s = localStorage.getItem("lull.sleepScape.v1"); return (s && (SOUND_BY_ID[s] || s.slice(0, 4) === "mix:")) ? s : "noise"; } catch (e) { return "noise"; } });
  const [light, setLight] = useState(false);
  const [sessions, setSessions] = useState(() => (typeof window !== "undefined" ? loadHist() : []));
  const [showHistory, setShowHistory] = useState(false);
  const [exportOpen, setExportOpen] = useState(false); const [copied, setCopied] = useState(false);
  // Standalone ambient mixer (play nature beds without a session; blend several, each with its own level).
  const [mixerOpen, setMixerOpen] = useState(false);
  const [mix, setMix] = useState(() => { try { return JSON.parse(localStorage.getItem("lull.mix.v1")) || {}; } catch (e) { return {}; } }); // { id: 0..1 }
  const [mixPlaying, setMixPlaying] = useState(false);
  const mixBusRef = useRef(null); const mixNodesRef = useRef({}); const mixPlayingRef = useRef(false);
  const [mixPresets, setMixPresets] = useState(() => { try { return JSON.parse(localStorage.getItem("lull.mixPresets.v1")) || []; } catch (e) { return []; } }); // saved, named blends
  const mixPresetsRef = useRef(mixPresets); // buildAmbience resolves a "mix:<id>" bed against this
  const [savingMix, setSavingMix] = useState(false); const [mixName, setMixName] = useState("");
  const [editingPresetId, setEditingPresetId] = useState(null); // when set, the mixer edits this saved mix in place
  const [preCheck, setPreCheck] = useState(false);      // pre-session mood check-in overlay
  const [onboard, setOnboard] = useState(() => { try { return localStorage.getItem("lull.onboarded.v1") !== "1"; } catch (e) { return false; } }); // first-run intro
  const [onboardStep, setOnboardStep] = useState(0);
  const [ready, setReady] = useState(false);            // "get ready" 3·2·1 pre-roll overlay
  const [readyN, setReadyN] = useState(3);              // countdown number; 0 shows "Breathe"
  const [readySaying, setReadySaying] = useState("");   // mood-tailored line shown during the pre-roll
  const [moodAfter, setMoodAfter] = useState(null);     // done-screen mood → reveals the calm lift

  const [phaseLabel, setPhaseLabel] = useState("Breathe in");
  const [tone, setTone] = useState("cool");
  const [orb, setOrb] = useState({ scale: LO, dur: 4, ease: "ease" });
  const [remaining, setRemaining] = useState(durationMin * 60);
  const [progress, setProgress] = useState(0);
  const [paused, setPaused] = useState(false);
  const [sleepVeil, setSleepVeil] = useState(0);

  const phasesRef = useRef([]); const idxRef = useRef(0); const elapsedRef = useRef(0); const targetRef = useRef(0);
  const pausedRef = useRef(false); const phaseTimeout = useRef(null); const tickRef = useRef(null);
  const soundRef = useRef(soundOn); const modeRef = useRef(mode); const patternIdRef = useRef(patternId);
  const audioRef = useRef(null); const nodesRef = useRef(null); const scapeRef = useRef(null); const brownRef = useRef(null); const whiteRef = useRef(null); const scapeIdRef = useRef("bowls"); const sleepScapeIdRef = useRef("noise");
  const soundOnlyRef = useRef(false); const sessionScapeRef = useRef(null); // sound-only sleep: no breathing, a forced bed
  const purchasesRef = useRef(null); const iapBusyRef = useRef(false); // RevenueCat handle + in-flight guard
  const particleRef = useRef(null);
  const moodBeforeRef = useRef(null); const pendingStartRef = useRef(null); // carry the pre-session mood + intent through the check-in
  const readyTimers = useRef([]); // pending "get ready" countdown timeouts
  // Drive the particle-sphere canvas while a particle orb is selected; clean up on change/unmount.
  useEffect(() => {
    const orb = ORBS[orbId] || ORBS.aurora;
    if (orb.kind !== "particles") return;
    const canvas = particleRef.current; if (!canvas) return;
    const ctx = canvas.getContext("2d"); if (!ctx) return;
    const DPR = Math.min((typeof window !== "undefined" && window.devicePixelRatio) || 1, 2);
    const size = canvas.clientWidth || 264;
    canvas.width = Math.round(size * DPR); canvas.height = Math.round(size * DPR);
    ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
    const pts = buildParticles(2200);
    let raf = 0; const start = (typeof performance !== "undefined" ? performance.now() : Date.now());
    const loop = (now) => { drawParticleSphere(ctx, size, pts, orb.palette, (now - start) / 1000); raf = requestAnimationFrame(loop); };
    if (prefersReduced) drawParticleSphere(ctx, size, pts, orb.palette, 0);
    else raf = requestAnimationFrame(loop);
    return () => { if (raf) cancelAnimationFrame(raf); };
  }, [orbId]);

  useEffect(() => { soundRef.current = soundOn; }, [soundOn]);
  useEffect(() => { modeRef.current = mode; }, [mode]);
  useEffect(() => { patternIdRef.current = patternId; }, [patternId]);
  useEffect(() => { scapeIdRef.current = scapeId; try { localStorage.setItem("lull.scape.v1", scapeId); } catch (e) {} }, [scapeId]);
  useEffect(() => { sleepScapeIdRef.current = sleepScapeId; try { localStorage.setItem("lull.sleepScape.v1", sleepScapeId); } catch (e) {} }, [sleepScapeId]);
  useEffect(() => { try { localStorage.setItem(ORB_KEY, orbId); } catch (e) {} }, [orbId]);
  useEffect(() => { try { localStorage.setItem(OWNED_KEY, JSON.stringify(ownedOrbs)); } catch (e) {} }, [ownedOrbs]);
  useEffect(() => { try { localStorage.setItem(SOUNDS_OWNED_KEY, JSON.stringify(ownedSounds)); } catch (e) {} }, [ownedSounds]);
  useEffect(() => { try { localStorage.setItem("lull.bundleOwned.v1", bundleOwned ? "1" : "0"); } catch (e) {} }, [bundleOwned]);
  const selectOrb = (id) => { if (orbOwned(id)) { setOrbId(id); setOrbStoreOpen(false); } };
  // Single seam for buying an orb. Today it unlocks locally; real charging (Apple In-App Purchase
  // on iOS, Stripe on web) drops in here — await the receipt, then unlock on success.
  const unlockOrb = (id) => { setOwnedOrbs((prev) => (prev.includes(id) ? prev : [...prev, id])); setOrbId(id); };
  const restoreOrbs = async () => {
    if (!iapLive() || !purchasesRef.current) return; // web / not configured: nothing to restore
    try { const { customerInfo } = await purchasesRef.current.restorePurchases(); applyCustomerInfo(customerInfo); try { window.alert("Purchases restored."); } catch (e) {} }
    catch (e) { try { window.alert("Nothing to restore."); } catch (_) {} }
  };
  const orbOwned = (id) => bundleOwned || ownedOrbs.includes(id);
  const packOwned = (p) => p.orbs.every(orbOwned);
  const soundOwned = (id) => bundleOwned || ownedSounds.includes(id);
  const soundPackOwned = (p) => p.sounds.every(soundOwned);
  const allOrbsOwned = ORB_ORDER.every(orbOwned);
  const allSoundsOwned = SOUND.every((s) => soundOwned(s.id));
  const allOwned = allOrbsOwned && allSoundsOwned;   // everything (orbs + sounds) — gates the bundle & the "Unlock more" section
  // The "Sound only" sleep mode edits its own bed (sleepScapeId); every other mode edits the breathing bed (scapeId).
  const editingSleepSound = mode === "sleep" && patternId === "noise";
  const activeSoundId = editingSleepSound ? sleepScapeId : scapeId;
  // A bed is either a single sound or a saved mix ("mix:<id>"). These resolve a selection to its name/chip.
  const isMixSel = (sel) => typeof sel === "string" && sel.slice(0, 4) === "mix:";
  const presetFor = (sel) => mixPresets.find((p) => "mix:" + p.id === sel);
  const soundLabel = (sel) => { if (isMixSel(sel)) { const pr = presetFor(sel); return pr ? pr.name : "Mix"; } return (SOUND_BY_ID[sel] || SOUND[0]).name; };
  const soundChipFor = (sel, size) => { if (isMixSel(sel)) return (<div style={{ width: size, height: size, borderRadius: "50%", flex: "0 0 auto", display: "flex", alignItems: "center", justifyContent: "center", background: "radial-gradient(circle at 50% 38%, #8ce0b055, #4fc4d022 60%, rgba(8,5,16,0.62) 100%)", boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.09), 0 2px 10px rgba(0,0,0,0.25)" }}><Waves size={Math.round(size * 0.5)} style={{ opacity: 0.85 }} /></div>); return soundChip(sel, size); };
  const selectSound = (id) => { if (!isMixSel(id) && !soundOwned(id)) return; if (editingSleepSound) setSleepScapeId(id); else setScapeId(id); };
  // Unlock an orb pack, a sound pack, or everything (the bundle). Real charging awaits the receipt,
  // then calls these on success — same seam as unlockOrb.
  const unlockPack = (packId) => { const p = PACKS[packId]; if (!p) return; setOwnedOrbs((prev) => { const next = [...prev]; p.orbs.forEach((id) => { if (!next.includes(id)) next.push(id); }); return next; }); };
  const unlockSoundPack = (packId) => { const p = SOUND_PACKS[packId]; if (!p) return; setOwnedSounds((prev) => { const next = [...prev]; p.sounds.forEach((id) => { if (!next.includes(id)) next.push(id); }); return next; }); };
  const unlockBundle = () => { setOwnedOrbs([...ORB_ORDER]); setOwnedSounds(SOUND.map((s) => s.id)); };
  // Reflect a RevenueCat CustomerInfo into what the app has unlocked.
  const applyCustomerInfo = (info) => {
    try {
      if (!info) return;
      const active = (info.entitlements && info.entitlements.active) || {};
      if (active[RC_ENTITLEMENT_EVERYTHING]) { setBundleOwned(true); unlockBundle(); return; }
      const owned = info.allPurchasedProductIdentifiers || (info.nonSubscriptionTransactions || []).map((t) => t.productIdentifier) || [];
      owned.forEach((pidStr) => { const m = PRODUCT_TO_UNLOCK[pidStr]; if (!m) return; if (m.kind === "orb") unlockPack(m.pack); else unlockSoundPack(m.pack); });
    } catch (e) {}
  };
  const syncPurchases = async () => { try { if (!purchasesRef.current) return; const { customerInfo } = await purchasesRef.current.getCustomerInfo(); applyCustomerInfo(customerInfo); } catch (e) {} };
  // One buy path for every store button. On iOS it charges through StoreKit/RevenueCat; on web (or
  // before the key is set) it falls back to the local unlock so nothing breaks.
  const buyProduct = async (productId, applyLocal) => {
    if (!iapLive() || !purchasesRef.current) { applyLocal(); return; }
    if (iapBusyRef.current) return; iapBusyRef.current = true;
    try {
      const got = await purchasesRef.current.getProducts({ productIdentifiers: [productId] });
      const list = (got && (got.products || got)) || [];
      const product = list.find((p) => (p.identifier || p.productIdentifier) === productId) || list[0];
      if (!product) throw new Error("product unavailable");
      const res = await purchasesRef.current.purchaseStoreProduct({ product });
      applyCustomerInfo(res && res.customerInfo); applyLocal();
    } catch (e) {
      const cancelled = e && (e.userCancelled || e.code === "PURCHASE_CANCELLED" || ((e.message || "") + "").toLowerCase().indexOf("cancel") !== -1);
      if (!cancelled) { try { window.alert("Purchase couldn't be completed. Please try again."); } catch (_) {} }
    } finally { iapBusyRef.current = false; }
  };
  useEffect(() => {
    let dead = false;
    (async () => {
      if (!iapLive()) return;
      try {
        await Purchases.configure({ apiKey: RC_IOS_KEY });
        try { await Purchases.setLogLevel({ level: LOG_LEVEL.WARN }); } catch (e) {}
        if (dead) return; purchasesRef.current = Purchases;
        await syncPurchases();
      } catch (e) {}
    })();
    return () => { dead = true; };
  }, []);
  useEffect(() => { try { if (window.matchMedia) setLight(window.matchMedia("(prefers-color-scheme: light)").matches); } catch (e) {} }, []);
  useEffect(() => { try { document.documentElement.style.colorScheme = "dark"; const m = document.querySelector('meta[name="theme-color"]'); if (m) m.setAttribute("content", "#070410"); } catch (e) {} }, []);

  const clearTimers = useCallback(() => {
    if (phaseTimeout.current) clearTimeout(phaseTimeout.current);
    if (tickRef.current) clearInterval(tickRef.current);
    readyTimers.current.forEach(clearTimeout); readyTimers.current = [];
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
    let sel = sessionScapeRef.current || scapeIdRef.current; // a sound id or a "mix:<id>" reference
    if (typeof sel === "string" && sel.slice(0, 4) === "mix:") { const pr = mixPresetsRef.current.find((p) => "mix:" + p.id === sel); sel = pr && pr.mix ? { mix: pr.mix } : "noise"; }
    scapeRef.current = createSoundscape(sel, audioRef.current, nodesRef.current.master, nodesRef.current.reverb, { white: whiteRef.current, brown: brownRef.current }, modeRef.current, soundOnlyRef.current);
  };
  const teardownAmbience = (fade = 1.2) => { try { if (scapeRef.current) scapeRef.current.stop(fade); } catch (e) {} scapeRef.current = null; };
  const breathAudio = (phase) => { try { if (scapeRef.current) scapeRef.current.onPhase(phase, modeRef.current); } catch (e) {} };
  const softenAmbience = () => { try { if (scapeRef.current && scapeRef.current.soften) scapeRef.current.soften(); } catch (e) {} };
  const pauseAmbience = () => { try { if (scapeRef.current && scapeRef.current.pause) scapeRef.current.pause(); } catch (e) {} };
  const resumeAmbience = () => { try { if (scapeRef.current && scapeRef.current.resume) scapeRef.current.resume(); } catch (e) {} };
  const bowl = (type) => { try { if (!soundRef.current || !scapeRef.current) return; if (type === "start" && scapeRef.current.onStart) scapeRef.current.onStart(); else if (type === "done" && scapeRef.current.onDone) scapeRef.current.onDone(); } catch (e) {} };

  // ---------- ambient mixer: play nature beds standalone, blended, each with its own level ----------
  const setMasterAudible = () => { try { const ctx = audioRef.current, m = nodesRef.current && nodesRef.current.master; if (!ctx || !m) return; const t = ctx.currentTime; m.gain.cancelScheduledValues(t); m.gain.setValueAtTime(Math.max(m.gain.value, 0.0001), t); m.gain.linearRampToValueAtTime(0.45, t + 0.4); } catch (e) {} };
  const updateMediaSession = () => {
    try {
      if (!("mediaSession" in navigator)) return; const ms = navigator.mediaSession;
      const active = NATURE_IDS.filter((id) => mixPlayingRef.current && (mix[id] || 0) > 0 && soundOwned(id));
      if (active.length) {
        const names = active.map((id) => (SOUND_BY_ID[id] || {}).name).filter(Boolean).join(" · ");
        ms.metadata = new window.MediaMetadata({ title: names || "Ambient sound", artist: "Lull", album: "Calm", artwork: [{ src: "/icon-512.png", sizes: "512x512", type: "image/png" }] });
        ms.playbackState = "playing";
        try { ms.setActionHandler("play", () => startMix()); } catch (e) {}
        try { ms.setActionHandler("pause", () => stopMix()); } catch (e) {}
        try { ms.setActionHandler("stop", () => stopMix()); } catch (e) {}
      } else { try { ms.playbackState = "none"; ms.metadata = null; } catch (e) {} }
    } catch (e) {}
  };
  const applyMix = () => {
    const ctx = audioRef.current; if (!ctx || !mixBusRef.current) return; const nodes = mixNodesRef.current;
    NATURE_IDS.forEach((id) => {
      const lvl = mixPlayingRef.current && soundOwned(id) ? (mix[id] || 0) : 0;
      if (lvl > 0) { if (nodes[id]) nodes[id].setLevel(lvl); else nodes[id] = createNatureNode(ctx, mixBusRef.current, id, lvl); }
      else if (nodes[id]) { try { nodes[id].stop(0.8); } catch (e) {} delete nodes[id]; }
    });
  };
  const startMix = () => {
    teardownAmbience(0.4); // ambient mixer and a breathing-session bed are mutually exclusive
    ensureAudio(); const ctx = audioRef.current; if (!ctx || !nodesRef.current) return;
    if (!soundRef.current) { setSoundOn(true); soundRef.current = true; }
    setMasterAudible();
    if (!mixBusRef.current) { const bus = ctx.createGain(); bus.gain.value = 1; const lim = ctx.createDynamicsCompressor(); lim.threshold.value = -3; lim.knee.value = 4; lim.ratio.value = 20; lim.attack.value = 0.004; lim.release.value = 0.25; bus.connect(lim); lim.connect(nodesRef.current.master); mixBusRef.current = bus; }
    mixPlayingRef.current = true; setMixPlaying(true); applyMix(); updateMediaSession();
  };
  const stopMix = () => { mixPlayingRef.current = false; setMixPlaying(false); const nodes = mixNodesRef.current; Object.keys(nodes).forEach((id) => { try { nodes[id].stop(0.8); } catch (e) {} delete nodes[id]; }); updateMediaSession(); };
  const setMixLevel = (id, v) => setMix((prev) => ({ ...prev, [id]: v }));
  const onMixSlide = (id, v) => { setMixLevel(id, v); if (v > 0 && !mixPlayingRef.current) startMix(); }; // touch a fader → it plays
  // Saved, named blends. suggestMixName offers the loudest one or two sounds as a default name.
  const suggestMixName = () => { const on = NATURE_IDS.filter((id) => (mix[id] || 0) > 0 && soundOwned(id)).sort((a, b) => (mix[b] || 0) - (mix[a] || 0)); const names = on.slice(0, 2).map((id) => (SOUND_BY_ID[id] || {}).name).filter(Boolean); return names.join(" & ") || "My mix"; };
  const beginSaveMix = () => { setMixName(suggestMixName()); setSavingMix(true); };
  const saveMixPreset = () => {
    const m = {}; NATURE_IDS.forEach((id) => { if ((mix[id] || 0) > 0 && soundOwned(id)) m[id] = mix[id]; });
    if (!Object.keys(m).length) return;
    const name = (mixName.trim() || suggestMixName()).slice(0, 24);
    setMixPresets((prev) => (editingPresetId != null && prev.some((x) => x.id === editingPresetId))
      ? prev.map((x) => (x.id === editingPresetId ? { ...x, name, mix: m } : x))   // update the mix you're editing, in place
      : [{ id: Date.now(), name, mix: m }, ...prev].slice(0, 12));                  // otherwise save a new one
    setSavingMix(false); setMixName(""); setEditingPresetId(null);
  };
  // Open the mixer to build a brand-new blend, or to edit an existing one in place. Both are reachable from the store.
  const newMix = () => { setEditingPresetId(null); setSavingMix(false); setMixName(""); try { stopMix(); } catch (e) {} setMix({}); setOrbStoreOpen(false); setMixerOpen(true); };
  const editMix = (pr) => { setEditingPresetId(pr.id); setMixName(pr.name); setMix({ ...pr.mix }); setSavingMix(true); setOrbStoreOpen(false); setMixerOpen(true); if (!mixPlayingRef.current) startMix(); };
  const closeMixer = () => { setMixerOpen(false); setSavingMix(false); setEditingPresetId(null); };
  const deletePreset = (id) => { const ref = "mix:" + id; if (scapeId === ref) setScapeId("bowls"); if (sleepScapeId === ref) setSleepScapeId("noise"); setMixPresets((prev) => prev.filter((x) => x.id !== id)); };
  const loadPreset = (p) => { setMix({ ...p.mix }); if (!mixPlayingRef.current) startMix(); };
  useEffect(() => { mixPresetsRef.current = mixPresets; try { localStorage.setItem("lull.mixPresets.v1", JSON.stringify(mixPresets)); } catch (e) {} }, [mixPresets]);
  useEffect(() => { try { localStorage.setItem("lull.mix.v1", JSON.stringify(mix)); } catch (e) {} if (mixPlayingRef.current) { applyMix(); updateMediaSession(); } }, [mix]);
  useEffect(() => { const h = () => { try { if (!document.hidden && audioRef.current && audioRef.current.state === "suspended" && (mixPlayingRef.current || scapeRef.current)) audioRef.current.resume(); } catch (e) {} }; document.addEventListener("visibilitychange", h); return () => document.removeEventListener("visibilitychange", h); }, []);

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
      if (soundOnlyRef.current && elapsedRef.current >= targetRef.current) finishSession(); // no breathing phase to end it
    }, 200);
  }, []);

  const startSession = (patOverride, durSecOverride, preroll) => {
    // patOverride is a string only when called programmatically (e.g. the SOS button); as an onClick
    // handler the first arg is the event, which we ignore and fall back to the chosen pattern.
    const pid = (typeof patOverride === "string" && PATTERNS[mode][patOverride]) ? patOverride : patternId;
    const p = PATTERNS[mode][pid]; if (!p) return;
    if (mixPlayingRef.current) stopMix(); // a session's bed replaces the standalone ambient mix
    if (pid !== patternId) { setPatternId(pid); patternIdRef.current = pid; }
    phasesRef.current = p.phases; idxRef.current = 0; elapsedRef.current = 0;
    soundOnlyRef.current = !!p.soundOnly; sessionScapeRef.current = p.soundOnly ? sleepScapeIdRef.current : (p.sound || null);
    targetRef.current = (typeof durSecOverride === "number" && durSecOverride > 0) ? durSecOverride : durationMin * 60;
    pausedRef.current = false; setPaused(false); setRemaining(targetRef.current); setProgress(0); setScreen("active");
    // Unlock + start the audio bed inside the tap gesture (iOS won't start media outside a gesture); it
    // fades in gently under the "get ready" pre-roll. Breathing phases + the countdown clock wait for
    // beginBreathing() so the 3·2·1 isn't taken out of the session.
    ensureAudio(); if (soundRef.current) buildAmbience();
    if (preroll) { setPhaseLabel(""); setTone("cool"); setOrb({ scale: prefersReduced ? 0.95 : 0.9, dur: 1.4, ease: "ease" }); return; }
    beginBreathing();
  };
  const beginBreathing = () => {
    const p = PATTERNS[modeRef.current] && PATTERNS[modeRef.current][patternIdRef.current]; if (!p) return;
    startTick();
    if (soundRef.current && !p.soundOnly) bowl("start");
    if (p.soundOnly) {
      setPhaseLabel(""); setTone("cool"); setOrb({ scale: 0.88, dur: 4, ease: "ease" });
      try { if ("mediaSession" in navigator) { navigator.mediaSession.metadata = new window.MediaMetadata({ title: p.name, artist: "Lull", album: "Sleep", artwork: [{ src: "/icon-512.png", sizes: "512x512", type: "image/png" }] }); navigator.mediaSession.playbackState = "playing"; navigator.mediaSession.setActionHandler("pause", () => pauseSession()); navigator.mediaSession.setActionHandler("play", () => resumeSession()); } } catch (e) {}
    } else runPhase();
  };
  // "Get ready" pre-roll: 3 · 2 · 1 · Breathe, with a line chosen by the pre-session calm scale. The bed
  // starts now (see startSession); breathing begins when the count lands. Only breathe/meditate reach here.
  const beginReady = (mood, pat, dur) => {
    readyTimers.current.forEach(clearTimeout); readyTimers.current = [];
    setReadySaying(pickReadyLine(mood)); setReadyN(3); setReady(true);
    startSession(pat, dur, true);
    const step = prefersReduced ? 820 : 950;
    readyTimers.current.push(setTimeout(() => setReadyN(2), step));
    readyTimers.current.push(setTimeout(() => setReadyN(1), step * 2));
    readyTimers.current.push(setTimeout(() => setReadyN(0), step * 3)); // 0 → "Breathe"
    readyTimers.current.push(setTimeout(() => { setReady(false); beginBreathing(); }, step * 3 + 850));
  };
  const skipReady = () => { readyTimers.current.forEach(clearTimeout); readyTimers.current = []; setReady(false); beginBreathing(); };
  const finishOnboard = () => { try { localStorage.setItem("lull.onboarded.v1", "1"); } catch (e) {} setOnboard(false); setOnboardStep(0); };
  const nextOnboard = () => { if (onboardStep < ONBOARD_SLIDES.length - 1) setOnboardStep(onboardStep + 1); else finishOnboard(); };
  const replayOnboard = () => { setOnboardStep(0); setOnboard(true); };
  const pauseSession = () => { pausedRef.current = true; setPaused(true); if (phaseTimeout.current) clearTimeout(phaseTimeout.current); setPhaseLabel("Paused"); setOrb({ scale: prefersReduced ? 0.95 : 0.92, dur: 0.8, ease: "ease" }); pauseAmbience(); try { if ("mediaSession" in navigator) navigator.mediaSession.playbackState = "paused"; } catch (e) {} };
  const resumeSession = () => { pausedRef.current = false; setPaused(false); ensureAudio(); if (soundRef.current && !scapeRef.current) buildAmbience(); else resumeAmbience(); if (soundOnlyRef.current) { setPhaseLabel(""); setOrb({ scale: 0.88, dur: 3, ease: "ease" }); } else runPhase(); try { if ("mediaSession" in navigator) navigator.mediaSession.playbackState = "playing"; } catch (e) {} };
  const goHome = () => { clearTimers(); setReady(false); pausedRef.current = false; setPaused(false); soundOnlyRef.current = false; sessionScapeRef.current = null; teardownAmbience(0.9); setScreen("home"); setOrb({ scale: LO, dur: 1, ease: "ease" }); setRemaining(durationMin * 60); setProgress(0); try { updateMediaSession(); } catch (e) {} };
  function finishSession() { clearTimers(); pausedRef.current = false; setPaused(false); soundOnlyRef.current = false; sessionScapeRef.current = null; if (modeRef.current !== "sleep") bowl("done"); teardownAmbience(modeRef.current === "sleep" ? 3.4 : 1.6); setMoodAfter(null); try { const entry = { t: Date.now(), mode: modeRef.current, pattern: patternIdRef.current, min: Math.max(1, Math.round(targetRef.current / 60)), moodBefore: (typeof moodBeforeRef.current === "number" ? moodBeforeRef.current : null), moodAfter: null }; setSessions((prev) => { const next = [...prev, entry]; saveHist(next); return next; }); } catch (e) {} setScreen("done"); }
  // A gentle, skippable calm check before breathing → sets moodBefore, then starts. Sleep and SOS
  // (sos:true patterns, e.g. Reset) skip it entirely — no friction when someone needs to calm down now.
  const beginWithCheckin = (patOverride, durSecOverride) => {
    const pid = (typeof patOverride === "string" && PATTERNS[mode][patOverride]) ? patOverride : patternId;
    const p = PATTERNS[mode] && PATTERNS[mode][pid];
    if (mode === "sleep" || (p && p.sos)) { moodBeforeRef.current = null; startSession(patOverride, durSecOverride); return; }
    pendingStartRef.current = { pat: (typeof patOverride === "string" ? patOverride : undefined), dur: (typeof durSecOverride === "number" ? durSecOverride : undefined) };
    moodBeforeRef.current = null; setMoodAfter(null); setPreCheck(true);
  };
  const startAfterCheckin = (mood) => {
    moodBeforeRef.current = (typeof mood === "number") ? mood : null; setPreCheck(false);
    const j = pendingStartRef.current || {}; pendingStartRef.current = null;
    beginReady(mood, j.pat, j.dur);
  };
  // Post-session tap patches the just-created entry with moodAfter and reveals the lift.
  const recordMoodAfter = (mood) => { setMoodAfter(mood); setSessions((prev) => { if (!prev.length) return prev; const next = prev.slice(); next[next.length - 1] = { ...next[next.length - 1], moodAfter: mood }; saveHist(next); return next; }); };
  // Your data, yours: view/copy/download every session & mood, or erase it all from this device.
  const exportJson = () => JSON.stringify({ app: "Lull", exported: new Date().toISOString(), sessions }, null, 2);
  const exportData = () => { setCopied(false); setExportOpen(true); };
  const downloadExport = () => { try { const blob = new Blob([exportJson()], { type: "application/json" }); const url = URL.createObjectURL(blob); const a = document.createElement("a"); a.href = url; a.download = "lull-breaths.json"; document.body.appendChild(a); a.click(); a.remove(); setTimeout(() => URL.revokeObjectURL(url), 2000); } catch (e) {} };
  const copyExport = async () => { let ok = false; try { await navigator.clipboard.writeText(exportJson()); ok = true; } catch (e) {} if (!ok) { try { const ta = document.getElementById("lull-export-ta"); if (ta) { ta.focus(); ta.select(); ok = document.execCommand("copy"); } } catch (e) {} } setCopied(ok); if (ok) setTimeout(() => setCopied(false), 2200); };
  const eraseData = () => { if (typeof window !== "undefined" && !window.confirm("Erase all your breaths and mood ratings? This stays on your device and can't be undone.")) return; try { localStorage.removeItem(HIST_KEY); } catch (e) {} setSessions([]); setShowHistory(false); };
  const switchMode = (m) => { if (m === mode) return; clearTimers(); setReady(false); teardownAmbience(0.4); setMode(m); setScreen("home"); setPatternId(DEFAULT_PATTERN[m]); setDurationMin(DEFAULT_DUR[m]); setRemaining(DEFAULT_DUR[m] * 60); setProgress(0); setTone("cool"); setOrb({ scale: LO, dur: 1, ease: "ease" }); };
  const toggleSound = () => {
    ensureAudio(); const next = !soundOn; setSoundOn(next); soundRef.current = next;
    if (nodesRef.current && audioRef.current) { const t = audioRef.current.currentTime; const g = nodesRef.current.master.gain; g.cancelScheduledValues(t); g.setValueAtTime(Math.max(g.value, 0.0001), t); g.linearRampToValueAtTime(next ? 0.45 : 0.0001, t + 0.6); }
    if (screen === "active") { if (next) buildAmbience(); else teardownAmbience(0.6); }
  };
  const fmt = (s) => { s = Math.max(0, Math.ceil(s)); const m = Math.floor(s / 60); return `${m}:${String(s % 60).padStart(2, "0")}`; };
  const openCustom = () => { setDraft(customPat || { inhale: 4, hold: 7, exhale: 8, hold2: 0 }); setShowCustom(true); };
  const openSleepTime = () => { const cur = sleepCustomMin || 480; setSleepDraft({ h: Math.min(12, Math.floor(cur / 60)), m: cur % 60 }); setShowSleepTime(true); };
  const saveSleepTime = () => { const mins = Math.max(5, sleepDraft.h * 60 + sleepDraft.m); saveSleepDur(mins); setSleepCustomMin(mins); setDurationMin(mins); setRemaining(mins * 60); setShowSleepTime(false); };
  const bumpSleep = (k, d, lo, hi) => setSleepDraft((p) => ({ ...p, [k]: Math.min(hi, Math.max(lo, (p[k] || 0) + d)) }));
  const saveCustomPat = () => { const c = { inhale: draft.inhale, hold: draft.hold, exhale: draft.exhale, hold2: draft.hold2 }; saveCustom(c); setCustomPat(c); setPatternId("custom"); setShowCustom(false); };
  const bump = (k, d, lo, hi) => setDraft((p) => ({ ...p, [k]: Math.min(hi, Math.max(lo, (p[k] || 0) + d)) }));

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

  // ORB is sized so a full inhale (×HI) lands just inside the ring, not past it: 234 × 1.18 ≈ 276,
  // inside the ring's ~281px interior (2·R − stroke). The breath fills the ring at its peak and never
  // crosses the line, while keeping the LO→HI breath ratio intact.
  const S = 312, ORB = 234, R = 142;
  const C = 2 * Math.PI * R;
  const pats = PATTERNS[mode];

  const selectedOrb = ORBS[orbId] || ORBS.aurora;
  // The progress ring's gradient matches the selected orb's own palette (falls back to the theme).
  const ringColors = selectedOrb.ring || [ringFrom, ringTo];
  const isLight = !!selectedOrb.light && !night;    // pastel orbs sit on a bright ground with dark UI; sleep stays dark
  const onWhite = isLight;                           // dark readout ink + a soft white halo on the bright ground
  const onDark = !!selectedOrb.dark;               // particle / plasma orbs glow on a deep-black ground
  const daylight = isLight;
  const lightUI = isLight;                            // flips ink / inkA / wa to dark tones on the bright ground
  const orbSrc = selectedOrb.kind === "image" ? selectedOrb.src : null;
  // Melt the image's near-black edge into the ground (both themes) so there's no black disc/halo —
  // on dark it becomes a soft glow, on light the warm ground shows around a soft-edged glass ball.
  const orbMask = "radial-gradient(closest-side, #000 74%, rgba(0,0,0,0.42) 90%, transparent 100%)";
  const imgZoom = selectedOrb.zoom || 1;                 // >1 crops past the glass rim/gloss (bubble-less)
  // Bubble-less orbs melt softly into the ground (no hard rim); glass orbs keep a crisper edge.
  const imgMask = selectedOrb.noBubble ? "radial-gradient(closest-side, #000 42%, rgba(0,0,0,0.5) 72%, transparent 94%)" : orbMask;
  // Readout ink/shadow: dark text with a soft white halo on the white ground, light text with a
  // dark halo on every other ground.
  const roInk = onWhite ? "#26203f" : "#F8F5FF";
  const roShadow = onWhite ? "0 1px 2px rgba(255,255,255,0.85)" : "0 1px 3px rgba(0,0,0,0.6)";
  const roShadowBig = onWhite ? "0 1px 2px rgba(255,255,255,0.9)" : "0 1px 3px rgba(0,0,0,0.66), 0 2px 18px rgba(0,0,0,0.5)";
  const roShadowActive = onWhite ? "0 1px 2px rgba(255,255,255,0.9)" : "0 1px 3px rgba(0,0,0,0.6), 0 2px 22px rgba(0,0,0,0.55)";
  const ink = lightUI ? "#2b2447" : "#F3EFFF";
  const inkA = (a) => (lightUI ? `rgba(43,36,71,${a})` : `rgba(243,239,255,${a})`);
  const wa = (a) => (lightUI ? `rgba(70,52,120,${a})` : `rgba(255,255,255,${a})`);
  const LIGHT_ROOT = "radial-gradient(125% 110% at 50% 6%, #faf4ee 0%, #f2eaef 55%, #ece1e9 100%)";
  const WHITE_ROOT = "radial-gradient(125% 120% at 50% 4%, #ffffff 0%, #fbfbfe 58%, #f3f3f8 100%)";
  const DARK_ROOT = "radial-gradient(120% 120% at 50% 32%, #0a0711 0%, #050308 60%, #020104 100%)";
  const groundBg = night ? th.rootNight : (selectedOrb.bg || th.rootDay);  // each orb's own matching ground
  // Solid fallback under the gradient so full-screen (position:fixed) modals never let the dark page
  // body bleed through — critical for light orbs, where a non-painting gradient would look dark.
  const groundSolid = isLight ? "#f8f4fd" : "#0a0613";
  const root = { minHeight: "100vh", width: "100%", display: "flex", alignItems: "center", justifyContent: "center", position: "relative", overflow: "hidden", background: groundBg, color: ink, fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", Roboto, sans-serif', WebkitFontSmoothing: "antialiased", transition: "background 1.4s ease, color 1.4s ease" };
  const frame = { position: "relative", zIndex: 2, width: "100%", maxWidth: 460, minHeight: "min(100vh, 820px)", padding: "max(26px, calc(env(safe-area-inset-top) + 6px)) 26px calc(40px + env(safe-area-inset-bottom))", display: "flex", flexDirection: "column", alignItems: "center" };
  const css = `
    * { box-sizing: border-box; }
    body { margin: 0; }
    @keyframes orbIdle { 0%,100% { transform: scale(0.8);} 50% { transform: scale(1.08);} }
    @keyframes ringSpin { to { transform: rotate(360deg); } }
    @keyframes drift1 { 0%,100% { transform: translate(0,0);} 50% { transform: translate(40px,-30px);} }
    @keyframes drift2 { 0%,100% { transform: translate(0,0);} 50% { transform: translate(-50px,40px);} }
    /* Scale baked in so the (inset:0, 100%) image fills the container exactly and stays centred,
       while the rotation still can't expose a corner of the masked circle. */
    @keyframes swirlSpin { from { transform: scale(1.3) rotate(0deg);} to { transform: scale(1.3) rotate(360deg);} }
    @keyframes swirlSpinRev { from { transform: scale(1.3) rotate(360deg);} to { transform: scale(1.3) rotate(0deg);} }
    @keyframes coreScale { 0%,100% { transform: scale(0.95);} 50% { transform: scale(1.1);} }
    /* Orbital loops (4 waypoints) so the blooms circulate and re-mix, not just pulse in place. */
    @keyframes driftA1 { 0%{transform:translate(-9%,-6%) scale(1);} 25%{transform:translate(7%,-10%) scale(1.12);} 50%{transform:translate(10%,7%) scale(1.04);} 75%{transform:translate(-7%,10%) scale(1.1);} 100%{transform:translate(-9%,-6%) scale(1);} }
    @keyframes driftA2 { 0%{transform:translate(8%,5%) scale(1.06);} 25%{transform:translate(-9%,9%) scale(1);} 50%{transform:translate(-10%,-7%) scale(1.12);} 75%{transform:translate(9%,-7%) scale(1.04);} 100%{transform:translate(8%,5%) scale(1.06);} }
    @keyframes driftA3 { 0%{transform:translate(5%,8%) scale(1);} 25%{transform:translate(12%,-5%) scale(1.1);} 50%{transform:translate(-6%,-10%) scale(1.04);} 75%{transform:translate(-12%,5%) scale(1.12);} 100%{transform:translate(5%,8%) scale(1);} }
    @keyframes driftA4 { 0%{transform:translate(-7%,6%) scale(1.08);} 25%{transform:translate(7%,11%) scale(1);} 50%{transform:translate(11%,-6%) scale(1.1);} 75%{transform:translate(-9%,-9%) scale(1.05);} 100%{transform:translate(-7%,6%) scale(1.08);} }
    @keyframes driftA5 { 0%{transform:translate(4%,-5%) scale(1.05);} 25%{transform:translate(-7%,-9%) scale(1.12);} 50%{transform:translate(-10%,6%) scale(1);} 75%{transform:translate(7%,9%) scale(1.08);} 100%{transform:translate(4%,-5%) scale(1.05);} }
    /* Slow whole-cluster swirl layered under the individual loops for constant, calm motion. */
    @keyframes bloomSpin { from { transform: rotate(0deg);} to { transform: rotate(360deg);} }
    @keyframes hueBreath { 0%,100% { filter: saturate(1) brightness(1);} 50% { filter: saturate(1.16) brightness(1.04);} }
    @keyframes orbGlow { 0%,100% { filter: brightness(1) saturate(1);} 50% { filter: brightness(1.09) saturate(1.06);} }
    /* Negative delay starts the breath ~a quarter in (mid-inhale, moving fast) so it never
       stalls small at the beginning; larger amplitude so the resting breath is clearly visible. */
    .orb-idle { animation: orbIdle 6.5s ease-in-out -1.6s infinite; }
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
    .lull-range { -webkit-appearance: none; appearance: none; width: 100%; height: 26px; background: transparent; cursor: pointer; }
    .lull-range::-webkit-slider-runnable-track { height: 4px; border-radius: 999px; background: rgba(255,255,255,0.16); }
    .lull-range::-moz-range-track { height: 4px; border-radius: 999px; background: rgba(255,255,255,0.16); }
    .lull-range::-webkit-slider-thumb { -webkit-appearance: none; appearance: none; width: 18px; height: 18px; margin-top: -7px; border-radius: 50%; background: #efeaff; box-shadow: 0 1px 5px rgba(0,0,0,0.5); }
    .lull-range::-moz-range-thumb { width: 18px; height: 18px; border: none; border-radius: 50%; background: #efeaff; box-shadow: 0 1px 5px rgba(0,0,0,0.5); }
    .lull-range:focus-visible { outline: 2px solid rgba(255,255,255,0.7); outline-offset: 4px; border-radius: 999px; }
    @keyframes readyPop { 0% { opacity: 0; transform: scale(0.6); } 30% { opacity: 1; } 100% { opacity: 0.9; transform: scale(1); } }
    @keyframes onbFade { from { opacity: 0; } to { opacity: 1; } }
    @keyframes onbBreath { 0%,100% { transform: scale(0.97); } 50% { transform: scale(1.03); } }
    .ready-count { animation: readyPop 0.95s cubic-bezier(.2,.8,.2,1) both; }
    @media (prefers-reduced-motion: reduce) { .orb-idle,.amb1,.amb2 { animation: none !important; } .ready-count { animation: none !important; opacity: 1 !important; } }
  `;
  const segWrap = { display: "flex", flexWrap: "wrap", gap: 8, width: "100%", background: wa(0.05), border: "1px solid " + wa(0.1), borderRadius: 18, padding: 6 };
  const seg = (sel) => ({ flex: "1 1 28%", padding: "12px 8px", borderRadius: 13, border: "1px solid transparent", background: sel ? wa(0.12) : "transparent", color: sel ? ink : inkA(0.5), transition: "background .35s ease, color .35s ease", display: "flex", flexDirection: "column", alignItems: "center", gap: 3 });
  const glassBtn = lightUI ? { "--glow": ringFrom, "--glow2": ringTo, position: "relative", overflow: "hidden", padding: "17px 0", width: "100%", borderRadius: 999, color: "#2a1c55", fontSize: 16.5, fontWeight: 600, letterSpacing: 0.8, background: "linear-gradient(178deg, #efe7ff, #c3acff)", border: "1px solid rgba(120,90,220,0.4)", boxShadow: `0 12px 34px ${ringFrom}33, inset 0 1.4px 0.5px rgba(255,255,255,0.7), inset 0 -8px 18px rgba(120,90,200,0.16)`, transition: "transform .2s cubic-bezier(.2,.8,.2,1), box-shadow .3s ease, filter .45s ease" } : { "--glow": ringFrom, "--glow2": ringTo, position: "relative", overflow: "hidden", padding: "17px 0", width: "100%", borderRadius: 999, color: "#FBFAFF", fontSize: 16.5, fontWeight: 600, letterSpacing: 0.8, boxShadow: `0 14px 46px ${ringFrom}40, 0 6px 18px ${ringTo}30, 0 1px 0 rgba(255,255,255,0.18), inset 0 1.4px 0.5px rgba(255,255,255,0.66), inset 0 -1.2px 1px rgba(255,255,255,0.30), inset 0 0 18px rgba(255,255,255,0.10), inset 0 -14px 26px rgba(0,0,0,0.18)`, transition: "transform .2s cubic-bezier(.2,.8,.2,1), box-shadow .3s ease, filter .45s ease" };
  const textBtn = { padding: "12px 18px", color: inkA(0.5), fontSize: 14, letterSpacing: 0.3 };
  // Five-dot calm scale (Tense → Calm), tinted with the current orb's ring palette. One tap fires onPick.
  const moodScale = (value, onPick) => { const c0 = ringColors[0], c1 = ringColors[ringColors.length - 1]; return (
    <div role="radiogroup" aria-label="How calm do you feel, tense to calm" style={{ display: "flex", flexDirection: "column", gap: 9, alignItems: "center" }}>
      <div style={{ display: "flex", gap: 13 }}>
        {[1, 2, 3, 4, 5].map((v) => { const on = value === v; return (
          <button key={v} role="radio" aria-checked={on} aria-label={MOOD_LABELS[v]} className="lull-btn" onClick={() => onPick(v)} style={{ width: 38, height: 38, borderRadius: "50%", border: "1px solid " + (on ? wa(0.55) : wa(0.2)), background: on ? `radial-gradient(circle at 50% 38%, ${c0}, ${c1})` : wa(0.05), boxShadow: on ? `0 0 20px -3px ${c1}` : "none", transform: on ? "scale(1.14)" : "scale(1)", transition: "transform .2s cubic-bezier(.2,.8,.2,1), background .2s ease, box-shadow .25s ease, border-color .2s ease" }} />); })}
      </div>
      <div style={{ display: "flex", justifyContent: "space-between", width: 38 * 5 + 13 * 4, fontSize: 11, opacity: 0.5, letterSpacing: 0.4 }}><span>Tense</span><span>Calm</span></div>
    </div>
  ); };

  // a rotating, turbulence-displaced, masked smoke layer (cool + warm crossfaded)
  const smokeLayer = (coolBg, warmBg, blur, spin, rev, filterId, mask) => (
    <div style={{ position: "absolute", inset: "-38%", borderRadius: "50%", zIndex: 2, animation: prefersReduced ? "none" : `${rev ? "swirlSpinRev" : "swirlSpin"} ${spin}s linear infinite`, filter: `${filterId ? `url(#${filterId}) ` : ""}blur(${blur}px)`, WebkitMaskImage: mask, maskImage: mask, WebkitMaskRepeat: "no-repeat", maskRepeat: "no-repeat", willChange: "transform" }}>
      <div style={{ position: "absolute", inset: 0, backgroundImage: coolBg, opacity: coolOp, transition: "opacity 1.2s ease", mixBlendMode: "screen" }} />
      <div style={{ position: "absolute", inset: 0, backgroundImage: warmBg, opacity: warmOp, transition: "opacity 1.2s ease", mixBlendMode: "screen" }} />
    </div>
  );

  const tagline = active ? `${pats[patternId].name} · ${pats[patternId].ratio}` : night ? "A slow exhale into sleep." : mode === "meditate" ? "A few quiet minutes." : "A minute to breathe.";

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

      <div className="amb1" style={{ position: "absolute", top: "-10%", left: "-15%", width: 520, height: 520, borderRadius: "50%", background: amb1, filter: "blur(20px)", zIndex: 0, opacity: selectedOrb.bg ? 0 : 1, transition: "background 1.4s ease, opacity 1.2s ease" }} />
      <div className="amb2" style={{ position: "absolute", bottom: "-12%", right: "-18%", width: 560, height: 560, borderRadius: "50%", background: amb2, filter: "blur(20px)", zIndex: 0, opacity: selectedOrb.bg ? 0 : 1, transition: "background 1.4s ease, opacity 1.2s ease" }} />
      <div style={{ position: "absolute", inset: 0, background: isCool ? tintCool : tintWarm, opacity: selectedOrb.bg ? 0 : 1, transition: "background 1.5s ease, opacity 1.2s ease", zIndex: 1, pointerEvents: "none" }} />
      {/* Light orb: slowly-drifting pastel blobs give the bright ground gentle motion (disabled by reduced-motion via .amb classes). */}
      {isLight && (<>
        <div className="amb1" style={{ position: "absolute", top: "-14%", left: "-12%", width: 560, height: 560, borderRadius: "50%", background: "radial-gradient(circle, rgba(255,170,205,0.55), rgba(255,170,205,0) 70%)", filter: "blur(46px)", zIndex: 0, pointerEvents: "none" }} />
        <div className="amb2" style={{ position: "absolute", bottom: "-16%", right: "-12%", width: 600, height: 600, borderRadius: "50%", background: "radial-gradient(circle, rgba(150,200,255,0.55), rgba(150,200,255,0) 70%)", filter: "blur(46px)", zIndex: 0, pointerEvents: "none" }} />
        <div className="amb1" style={{ position: "absolute", top: "34%", right: "-14%", width: 460, height: 460, borderRadius: "50%", background: "radial-gradient(circle, rgba(170,235,200,0.5), rgba(170,235,200,0) 70%)", filter: "blur(50px)", zIndex: 0, pointerEvents: "none", animationDelay: "-9s" }} />
        <div className="amb2" style={{ position: "absolute", bottom: "30%", left: "-12%", width: 480, height: 480, borderRadius: "50%", background: "radial-gradient(circle, rgba(255,215,165,0.5), rgba(255,215,165,0) 70%)", filter: "blur(50px)", zIndex: 0, pointerEvents: "none", animationDelay: "-15s" }} />
      </>)}

      <div style={frame}>
        <div style={{ position: "relative", width: "100%", display: "flex", alignItems: "center", justifyContent: "center", minHeight: 36, marginBottom: 8 }}>
          <span style={{ fontSize: 14, letterSpacing: 6, textTransform: "uppercase", fontWeight: 500, opacity: 0.82, paddingLeft: 6 }}>Lull</span>
          {false && (<button className="lull-btn" aria-label="theme" onClick={() => setLight((v) => !v)} style={{ position: "absolute", left: 0, padding: 8, opacity: 0.7 }}>{lightUI ? <Moon size={19} /> : <Sun size={19} />}</button>)}
          <div style={{ position: "absolute", right: 0, display: "flex", alignItems: "center", gap: 2 }}>
            {screen === "home" && (<button className="lull-btn" aria-label="Ambient sounds" onClick={() => { setEditingPresetId(null); setSavingMix(false); setMixerOpen(true); }} style={{ padding: 8, opacity: mixPlaying ? 1 : 0.7, display: "flex", color: mixPlaying ? "#8ce0b0" : undefined }}><Waves size={19} /></button>)}
            {screen === "home" && (<button className="lull-btn" aria-label="Your breaths" onClick={() => setShowHistory(true)} style={{ padding: 8, opacity: 0.7, display: "flex" }}><CalendarDays size={19} /></button>)}
            <button className="lull-btn" aria-label={soundOn ? "Mute sound" : "Unmute sound"} aria-pressed={soundOn} onClick={toggleSound} style={{ padding: 8, opacity: 0.7, display: "flex" }}>{soundOn ? <Volume2 size={20} /> : <VolumeX size={20} />}</button>
          </div>
        </div>

        {screen !== "done" && (<p style={{ fontSize: 13, opacity: 0.45, margin: "2px 0 0", letterSpacing: 0.3, minHeight: 18 }}>{tagline}</p>)}

        {screen === "home" && (
          <div style={{ ...segWrap, flexWrap: "nowrap", maxWidth: 300, marginTop: 14 }}>
            {["breathe", "meditate", "sleep"].map((m) => { const sel = mode === m; return (<button key={m} className="lull-seg lull-btn" aria-pressed={sel} onClick={() => switchMode(m)} style={seg(sel)}><span style={{ fontSize: 14, fontWeight: 500, textTransform: "capitalize" }}>{m}</span></button>); })}
          </div>
        )}

        {showStage && (
          <div style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14, width: "100%", opacity: dim, transition: "opacity 1.2s ease" }}>
            <div style={{ position: "relative", width: S, height: S, display: "flex", alignItems: "center", justifyContent: "center" }}>
              <svg width={S} height={S} style={{ position: "absolute", inset: 0, transform: "rotate(-90deg)", zIndex: 3, pointerEvents: "none" }}>
                <circle cx={S / 2} cy={S / 2} r={R} fill="none" stroke={inkA(0.14)} strokeWidth={2} />
                <circle cx={S / 2} cy={S / 2} r={R} fill="none" stroke="url(#ring)" strokeWidth={3} strokeLinecap="round" strokeDasharray={C} strokeDashoffset={C * (1 - (active ? progress : screen === "done" ? 1 : 0))} style={{ transition: "stroke-dashoffset .3s linear", opacity: active || screen === "done" ? 1 : 0 }} />
                <defs><linearGradient id="ring" x1="0" y1="0" x2="1" y2="1">{ringColors.map((c, i, a) => (<stop key={i} offset={`${a.length === 1 ? 0 : (i / (a.length - 1)) * 100}%`} stopColor={c} />))}</linearGradient></defs>
              </svg>

              <div className={idle ? "orb-idle" : ""} style={{ width: ORB, height: ORB, borderRadius: "50%", position: "relative", display: "flex", alignItems: "center", justifyContent: "center", willChange: "transform", ...(idle ? {} : { transform: `scale(${orb.scale})`, transition: `transform ${orb.dur}s ${orb.ease}` }) }}>
                <div style={{ position: "absolute", inset: -46, borderRadius: "50%", background: isCool ? glowCool : glowWarm, filter: "blur(36px)", opacity: selectedOrb.kind === "coded" ? 1 : 0, transition: "background 1.2s ease, opacity 1s ease", zIndex: 0 }} />
                <div style={{ position: "absolute", inset: 0, borderRadius: "50%", overflow: "hidden", zIndex: 2, display: selectedOrb.kind === "coded" ? "block" : "none", boxShadow: "inset 0 0 42px rgba(0,0,0,0.6), inset 0 1px 14px rgba(255,255,255,0.12)" }}>
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
                {/* Siri-style orb — the generated image. Circle-masked; on dark it glows on the deep ground, on
                    light it seats as a glass ball. Breathing scale comes from the parent wrapper; here a gentle
                    idle brightness shimmer, and a breath-brightness during a session (cool/inhale brighter,
                    warm/exhale softer). No mix-blend-mode: the parent's transform isolates it, so we mask the
                    near-black edge to blend into the ground instead. */}
                {selectedOrb.kind === "coded" ? null : selectedOrb.kind === "rings" ? (
                  <div style={{ position: "absolute", inset: 0, borderRadius: "50%", overflow: "hidden", zIndex: 2, filter: active ? (isCool ? "brightness(1.14) saturate(1.08)" : "brightness(0.94)") : undefined, animation: (idle && !prefersReduced) ? "orbGlow 9s ease-in-out infinite" : "none", transition: active ? `filter ${orb.dur}s ${orb.ease || "ease"}` : "filter 1s ease" }}>
                    {ringsSVG(selectedOrb.palette, { anim: !prefersReduced })}
                  </div>
                ) : selectedOrb.kind === "plasma" ? (
                  <div style={{ position: "absolute", inset: 0, borderRadius: "50%", overflow: "hidden", zIndex: 2, filter: active ? (isCool ? "brightness(1.14) saturate(1.08)" : "brightness(0.92)") : undefined, animation: (idle && !prefersReduced) ? "orbGlow 8s ease-in-out infinite" : "none", transition: active ? `filter ${orb.dur}s ${orb.ease || "ease"}` : "filter 1s ease" }}>
                    <svg viewBox="0 0 300 300" preserveAspectRatio="xMidYMid meet" style={{ position: "absolute", inset: 0, width: "100%", height: "100%", display: "block" }}>
                      <defs>
                        <radialGradient id="plBody" cx="44%" cy="38%" r="68%">
                          <stop offset="0%" stopColor="#060a18" /><stop offset="46%" stopColor="#0a1e46" /><stop offset="82%" stopColor="#164fc8" /><stop offset="96%" stopColor="#4fb0ff" /><stop offset="100%" stopColor="#9fe6ff" />
                        </radialGradient>
                        <radialGradient id="plRim" cx="50%" cy="50%" r="50%">
                          <stop offset="80%" stopColor="rgba(120,220,255,0)" /><stop offset="92%" stopColor="rgba(150,232,255,0.35)" /><stop offset="97.5%" stopColor="rgba(150,235,255,0.98)" /><stop offset="100%" stopColor="rgba(120,200,255,0)" />
                        </radialGradient>
                        <radialGradient id="plCore" cx="50%" cy="52%" r="46%">
                          <stop offset="0%" stopColor="rgba(2,6,18,0)" /><stop offset="60%" stopColor="rgba(2,6,18,0)" /><stop offset="100%" stopColor="rgba(2,6,18,0.55)" />
                        </radialGradient>
                        <filter id="plCrack" x="-10%" y="-10%" width="120%" height="120%">
                          <feTurbulence type="turbulence" baseFrequency="0.09 0.06" numOctaves="5" seed="4" result="n">
                            {!prefersReduced && (<animate attributeName="baseFrequency" dur="14s" values="0.08 0.055;0.1 0.07;0.08 0.055" repeatCount="indefinite" />)}
                          </feTurbulence>
                          <feColorMatrix in="n" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  9 0 0 0 -4.6" result="a" />
                          <feFlood floodColor="#e6faff" result="f" />
                          <feComposite in="f" in2="a" operator="in" result="v" />
                          <feGaussianBlur in="v" stdDeviation="0.2" />
                        </filter>
                        <clipPath id="plClip"><circle cx="150" cy="150" r="122" /></clipPath>
                      </defs>
                      <g clipPath="url(#plClip)">
                        <circle cx="150" cy="150" r="122" fill="url(#plBody)" />
                        <rect x="0" y="0" width="300" height="300" filter="url(#plCrack)" style={{ mixBlendMode: "screen", opacity: 0.6 }} />
                        <circle cx="150" cy="150" r="122" fill="url(#plCore)" />
                        <ellipse cx="118" cy="86" rx="52" ry="24" fill="rgba(200,235,255,0.10)" />
                      </g>
                      <circle cx="150" cy="150" r="122" fill="url(#plRim)" />
                    </svg>
                  </div>
                ) : selectedOrb.kind === "particles" ? (
                  <div style={{ position: "absolute", inset: 0, borderRadius: "50%", overflow: "hidden", zIndex: 2, filter: active ? (isCool ? "brightness(1.12) saturate(1.05)" : "brightness(0.92)") : undefined, animation: (idle && !prefersReduced) ? "orbGlow 8s ease-in-out infinite" : "none", transition: active ? `filter ${orb.dur}s ${orb.ease || "ease"}` : "filter 1s ease" }}>
                    <canvas ref={particleRef} style={{ position: "absolute", inset: 0, width: "100%", height: "100%", display: "block" }} />
                  </div>
                ) : selectedOrb.kind === "image" ? (
                  <div style={{ position: "absolute", inset: 0, borderRadius: "50%", overflow: "hidden", isolation: "isolate", zIndex: 2, WebkitMaskImage: imgMask, maskImage: imgMask, filter: active ? (isCool ? "brightness(1.13) saturate(1.06)" : "brightness(0.9) saturate(1.0)") : undefined, animation: (idle && !prefersReduced) ? "orbGlow 7s ease-in-out infinite" : "none", transition: active ? `filter ${orb.dur}s ${orb.ease || "ease"}` : "filter 1s ease" }}>
                    {/* Two copies of the swirl counter-rotate and screen-blend so the ribbons churn.
                        `zoom` crops past the glass rim/gloss for a bubble-less, free-flowing look. */}
                    <div style={{ position: "absolute", inset: 0, transform: imgZoom !== 1 ? `scale(${imgZoom})` : undefined, transformOrigin: "center", filter: selectedOrb.hue ? `hue-rotate(${selectedOrb.hue}deg) saturate(${selectedOrb.sat || 1.1})` : undefined }}>
                      <img src={orbSrc} alt="" draggable="false" style={{ position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover", transformOrigin: "center", display: "block", pointerEvents: "none", willChange: "transform", animation: prefersReduced ? "none" : "swirlSpin 46s linear infinite" }} />
                      <img src={orbSrc} alt="" draggable="false" style={{ position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover", transformOrigin: "center", display: "block", pointerEvents: "none", mixBlendMode: "screen", opacity: 0.45, willChange: "transform", animation: prefersReduced ? "none" : "swirlSpinRev 63s linear infinite" }} />
                    </div>
                    {!selectedOrb.noBubble && (<div aria-hidden="true" style={{ position: "absolute", inset: 0, borderRadius: "50%", pointerEvents: "none", background: "radial-gradient(58% 52% at 37% 30%, rgba(255,255,255,0.32), rgba(255,255,255,0.06) 42%, transparent 62%)" }} />)}
                  </div>
                ) : (
                  /* Soft glow orb (coded). A symmetric ring of blurred colour blobs (from the orb's
                     palette) rotates evenly around a centred core, melting into the ground through a
                     soft mask — clean on white, a gentle glow on dark. Even by construction (equal
                     angles), so it never looks lopsided; breathing comes from the wrapper scale.
                     A generated image can later drop in as an image-kind orb instead. */
                  <div style={{ position: "absolute", inset: 0, borderRadius: "50%", overflow: "hidden", zIndex: 2, WebkitMaskImage: "radial-gradient(closest-side, #000 80%, rgba(0,0,0,0.5) 93%, transparent 100%)", maskImage: "radial-gradient(closest-side, #000 80%, rgba(0,0,0,0.5) 93%, transparent 100%)", filter: active ? (isCool ? "brightness(1.07) saturate(1.08)" : "brightness(0.97) saturate(1.0)") : undefined, animation: (idle && !prefersReduced) ? "orbGlow 8s ease-in-out infinite" : "none", transition: active ? `filter ${orb.dur}s ${orb.ease || "ease"}` : "filter 1s ease" }}>
                    <div style={{ position: "absolute", inset: "-20%", filter: "blur(17px)", animation: prefersReduced ? "none" : "bloomSpin 48s linear infinite" }}>
                      {(selectedOrb.colors || []).map((c, i, arr) => { const a = (i / arr.length) * Math.PI * 2 - Math.PI / 2; const x = (50 + Math.cos(a) * 29).toFixed(1); const y = (50 + Math.sin(a) * 29).toFixed(1); return (<div key={i} style={{ position: "absolute", inset: 0, background: `radial-gradient(50% 50% at ${x}% ${y}%, rgba(${c},0.92), transparent 66%)` }} />); })}
                    </div>
                    <div aria-hidden="true" style={{ position: "absolute", inset: 0, background: "radial-gradient(30% 30% at 50% 50%, rgba(255,255,255,0.88), rgba(255,255,255,0) 62%)" }} />
                  </div>
                )}
              </div>

              {/* soft dark core behind the readout so it stays legible over the bright, shifting bloom */}
              <div aria-hidden="true" style={{ position: "absolute", inset: 0, zIndex: 5, pointerEvents: "none", display: "flex", alignItems: "center", justifyContent: "center" }}>
                <div style={{ width: ORB * 0.66, height: ORB * 0.46, borderRadius: "50%", background: "radial-gradient(ellipse at center, rgba(7,4,18,0.5) 0%, rgba(7,4,18,0.3) 42%, rgba(7,4,18,0) 72%)", filter: "blur(7px)", opacity: onWhite ? 0 : 1, transition: "opacity 1s ease" }} />
              </div>
              <div style={{ position: "absolute", textAlign: "center", zIndex: 6, pointerEvents: "none", color: roInk }}>
                {active ? (<div style={{ fontSize: mode === "meditate" ? 19 : 30, fontWeight: 300, letterSpacing: mode === "meditate" ? 0.2 : 1, lineHeight: mode === "meditate" ? 1.35 : 1.1, maxWidth: mode === "meditate" ? ORB * 0.84 : "none", textShadow: roShadowActive }}>{phaseLabel}</div>)
                  : sleepDone ? null : (<>
                    <div style={{ fontSize: 11, fontWeight: 600, letterSpacing: 6, textIndent: 6, opacity: 0.62, marginBottom: 10, textShadow: roShadow }}>LULL</div>
                    <div style={{ fontSize: 23, fontWeight: 400, letterSpacing: 0.5, textShadow: roShadowBig }}>{pats[patternId].name}</div>
                    <div style={{ fontSize: 12.5, letterSpacing: 3, opacity: 0.92, marginTop: 4, textShadow: roShadow }}>{pats[patternId].ratio}</div></>)}
              </div>
            </div>
            <div style={{ fontSize: 15, opacity: 0.65, fontVariantNumeric: "tabular-nums", letterSpacing: 1, minHeight: 22 }}>{active ? fmt(remaining) : ""}</div>
          </div>
        )}

        {screen === "home" && (
          <div style={{ width: "100%", display: "flex", flexDirection: "column", gap: 12 }}>
            <div style={{ display: "flex", flexWrap: "wrap", justifyContent: "center", alignItems: "center", gap: 8 }}>
              <button className="lull-btn" aria-label="Choose your orb and sound" onClick={() => setOrbStoreOpen(true)} style={{ flexShrink: 0, display: "flex", alignItems: "center", gap: 10, padding: "6px 14px 6px 6px", borderRadius: 999, background: wa(0.06), border: "1px solid " + wa(0.16), color: ink }}>
                <span style={{ display: "flex", alignItems: "center", gap: 8 }}>
                  {orbChip(orbId, 26)}
                  <span style={{ fontSize: 13, fontWeight: 500, letterSpacing: 0.3 }}>{selectedOrb.name}</span>
                </span>
                <span aria-hidden="true" style={{ width: 1, height: 18, background: wa(0.18) }} />
                <span style={{ display: "flex", alignItems: "center", gap: 8 }}>
                  {soundChipFor(activeSoundId, 26)}
                  <span style={{ fontSize: 13, fontWeight: 500, letterSpacing: 0.3 }}>{soundLabel(activeSoundId)}</span>
                </span>
                <span style={{ fontSize: 13, opacity: 0.5, letterSpacing: 0.5, marginLeft: 1 }}>›</span>
              </button>
            </div>
            {mixPlaying && (() => {
              const active = NATURE_IDS.filter((id) => (mix[id] || 0) > 0 && soundOwned(id));
              if (!active.length) return null;
              const names = active.map((id) => (SOUND_BY_ID[id] || {}).name).filter(Boolean).join(" · ");
              return (
                <div style={{ display: "flex", justifyContent: "center" }}>
                  <div style={{ display: "inline-flex", alignItems: "center", gap: 6, padding: "5px 6px 5px 12px", borderRadius: 999, background: wa(0.05), border: "1px solid " + wa(0.13) }}>
                    <button className="lull-btn" aria-label="Open ambient sounds" onClick={() => setMixerOpen(true)} style={{ display: "inline-flex", alignItems: "center", gap: 7, color: ink }}>
                      <span aria-hidden="true" style={{ width: 7, height: 7, borderRadius: "50%", background: "#8ce0b0", boxShadow: "0 0 6px #8ce0b0" }} />
                      <span style={{ fontSize: 12, fontWeight: 500, letterSpacing: 0.2, opacity: 0.82 }}>{names}</span>
                    </button>
                    <button className="lull-btn" aria-label="Stop ambient sound" onClick={stopMix} style={{ padding: "4px 12px", borderRadius: 999, fontSize: 11.5, fontWeight: 600, letterSpacing: 0.4, color: inkA(0.75), background: wa(0.08) }}>Stop</button>
                  </div>
                </div>
              );
            })()}
            {selectedOrb.kind === "coded" && (
            <div style={{ display: "flex", gap: 12, justifyContent: "center", padding: "2px 0 4px" }}>
              {Object.entries(THEMES).map(([id, t]) => { const sel = themeId === id; return (
                <button key={id} className="lull-dot lull-btn" aria-label={`Orb colour: ${t.name}`} aria-pressed={sel} title={t.name} onClick={() => setThemeId(id)} style={{ width: 30, height: 30, borderRadius: "50%", padding: 0, backgroundImage: t.swatch, border: "1px solid " + wa(0.3), boxShadow: sel ? (lightUI ? "0 0 0 2px rgba(70,50,140,0.8), 0 3px 12px rgba(80,60,140,0.25)" : "0 0 0 2px rgba(255,255,255,0.9), 0 3px 12px rgba(0,0,0,0.45)") : (lightUI ? "0 2px 8px rgba(80,60,140,0.2)" : "0 2px 8px rgba(0,0,0,0.35)"), transform: sel ? "scale(1.14)" : "scale(1)", transition: "transform .2s ease, box-shadow .2s ease" }} />); })}
            </div>
            )}
            {(() => { const entries = Object.entries(pats); const cols = entries.length === 4 ? 2 : Math.min(entries.length, 3); return (
              <div style={{ ...segWrap, display: "grid", gridTemplateColumns: `repeat(${cols}, 1fr)` }}>
                {entries.map(([id, p]) => { const sel = patternId === id; return (<button key={id} className="lull-seg lull-btn" aria-pressed={sel} onClick={() => setPatternId(id)} style={seg(sel)}><span style={{ fontSize: 14, fontWeight: 500 }}>{p.name}</span><span style={{ fontSize: 10.5, opacity: 0.6, letterSpacing: 0.3, textAlign: "center" }}>{p.goal || p.ratio}</span></button>); })}
              </div>
            ); })()}
            {PATTERN_INFO[mode] && PATTERN_INFO[mode][patternId] && (<p style={{ fontSize: 12.5, opacity: 0.5, textAlign: "center", margin: "0 4px", lineHeight: 1.5, letterSpacing: 0.2, transition: "opacity .2s ease" }}>{PATTERN_INFO[mode][patternId]}</p>)}
            {mode !== "meditate" && (<button className="lull-btn" onClick={openCustom} style={{ alignSelf: "center", display: "flex", alignItems: "center", gap: 8, padding: "9px 18px", borderRadius: 999, fontSize: 13, fontWeight: 600, letterSpacing: 0.3, color: ink, background: wa(0.06), border: "1px dashed " + wa(0.32), boxShadow: "0 2px 10px -6px rgba(0,0,0,0.5)" }}><span aria-hidden style={{ fontSize: 13, opacity: 0.85 }}>✎</span>{customPat ? "Edit your pattern" : "Make your own"}</button>)}
            {(() => {
              const durs = DURATIONS[mode]; const isSleep = mode === "sleep";
              const cols = durs.length + (isSleep ? 1 : 0);
              return (
                <div style={{ ...segWrap, display: "grid", gridTemplateColumns: `repeat(${cols}, 1fr)` }}>
                  {durs.map((m) => { const sel = durationMin === m; const { big, unit } = fmtDur(m); return (<button key={m} className="lull-seg lull-btn" aria-pressed={sel} onClick={() => { setDurationMin(m); setRemaining(m * 60); }} style={seg(sel)}><span style={{ fontSize: 16, fontWeight: 500 }}>{big}</span><span style={{ fontSize: 11, opacity: 0.6, letterSpacing: 1 }}>{unit}</span></button>); })}
                  {isSleep && (() => {
                    const has = sleepCustomMin != null; const sel = has && durationMin === sleepCustomMin && !durs.includes(sleepCustomMin);
                    const lbl = has ? fmtDur(sleepCustomMin) : null;
                    return (<button key="sleep-custom" className="lull-seg lull-btn" aria-label={has ? `Your custom sleep time, ${lbl.big} ${lbl.unit}. Tap again to change it.` : "Make your own sleep time"} aria-pressed={sel} onClick={() => { if (has && !sel) { setDurationMin(sleepCustomMin); setRemaining(sleepCustomMin * 60); } else { openSleepTime(); } }} style={{ ...seg(sel), position: "relative", border: "1px dashed " + wa(sel ? 0.44 : 0.3) }}>
                      {has ? (<><span aria-hidden style={{ position: "absolute", top: 4, right: 5, fontSize: 9, opacity: 0.7 }}>✎</span><span style={{ fontSize: 16, fontWeight: 500 }}>{lbl.big}</span><span style={{ fontSize: 9.5, opacity: 0.6, letterSpacing: 0.5 }}>{lbl.unit} · yours</span></>)
                           : (<><span style={{ fontSize: 17, fontWeight: 300, lineHeight: 1.1 }}>＋</span><span style={{ fontSize: 10.5, opacity: 0.6, letterSpacing: 0.5 }}>yours</span></>)}
                    </button>);
                  })()}
                </div>
              );
            })()}
            <button className="lull-btn lull-cta" onClick={beginWithCheckin} style={{ ...glassBtn, marginTop: 4 }}>Begin</button>
            {sessions.length > 0 && (<button className="lull-btn" onClick={() => setShowHistory(true)} style={{ marginTop: 2, padding: "7px 0", fontSize: 12.5, letterSpacing: 0.4, color: inkA(0.5), alignSelf: "center" }}>{(() => { const w = minutesSince(sessions, Date.now() - 7 * DAY_MS); return w > 0 ? `You’ve breathed ${w} min this week` : "Your breaths"; })()}</button>)}
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
            <div style={{ marginBottom: 14, borderRadius: "50%", boxShadow: `0 0 60px ${(selectedOrb.ring && selectedOrb.ring[0]) || th.ringTo}66` }}>{orbChip(orbId, 96)}</div>
            <div style={{ fontSize: 28, fontWeight: 300, letterSpacing: 0.5 }}>That's it.</div>
            <p style={{ fontSize: 14, opacity: 0.6, margin: 0, maxWidth: 260 }}>You gave yourself {durationMin} {durationMin === 1 ? "minute" : "minutes"}. Carry it with you.</p>
            {!(PATTERNS[mode][patternId] && PATTERNS[mode][patternId].sos) && (() => {
              if (moodAfter == null) return (
                <div style={{ marginTop: 16, display: "flex", flexDirection: "column", alignItems: "center", gap: 12 }}>
                  <div style={{ fontSize: 13, opacity: 0.6, letterSpacing: 0.3 }}>How do you feel now?</div>
                  {moodScale(null, recordMoodAfter)}
                </div>
              );
              const before = moodBeforeRef.current; let msg;
              if (typeof before === "number") { const d = moodAfter - before; msg = d >= 2 ? "Much calmer than when you started." : d === 1 ? "A little calmer than when you started." : d === 0 ? (moodAfter >= 4 ? "You held your calm." : "Steady. However you feel is okay.") : "However you feel is okay. You showed up."; }
              else msg = "Noticed. However you feel is okay.";
              return (<p style={{ fontSize: 13.5, opacity: 0.62, margin: "12px 0 0", maxWidth: 260, letterSpacing: 0.2 }}>{msg}</p>);
            })()}
            <div style={{ display: "flex", flexDirection: "column", gap: 8, width: "100%", maxWidth: 240, marginTop: 26 }}>
              <button className="lull-btn lull-cta" onClick={beginWithCheckin} style={glassBtn}>Again</button>
              <button className="lull-btn" onClick={goHome} style={textBtn}>Done</button>
            </div>
          </div>
        )}
      </div>

      {orbStoreOpen && (
        <div style={{ position: "fixed", inset: 0, zIndex: 60, backgroundColor: groundSolid, backgroundImage: groundBg, color: ink, display: "flex", flexDirection: "column", padding: "max(30px, calc(env(safe-area-inset-top) + 12px)) 26px calc(34px + env(safe-area-inset-bottom))", overflowY: "auto" }}>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 8 }}>
            <span style={{ fontSize: 12, letterSpacing: 5, textTransform: "uppercase", fontWeight: 500, opacity: 0.6 }}>Store</span>
            <button className="lull-btn" aria-label="Done" onClick={() => setOrbStoreOpen(false)} style={{ padding: "6px 4px", opacity: 0.75, fontSize: 15 }}>Done</button>
          </div>
          <p style={{ fontSize: 14, lineHeight: 1.5, opacity: 0.6, margin: "0 0 24px", maxWidth: "42ch" }}>Tap to choose your orb and sound. Unlock packs to add more. Yours forever, no subscription.</p>

          {/* Your orbs — free + everything you own, tap to breathe with it */}
          <div style={{ fontSize: 11, letterSpacing: 3, textTransform: "uppercase", fontWeight: 600, opacity: 0.5, marginBottom: 13 }}>Your orbs</div>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(94px, 1fr))", gap: 11, marginBottom: 28 }}>
            {ORB_ORDER.filter(orbOwned).map((id) => {
              const o = ORBS[id]; const sel = orbId === id;
              return (
                <button key={id} className="lull-btn" aria-pressed={sel} onClick={() => selectOrb(id)} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 9, padding: "15px 8px 12px", borderRadius: 18, background: sel ? wa(0.09) : wa(0.03), border: "1px solid " + (sel ? wa(0.34) : wa(0.1)), boxShadow: sel ? "0 8px 22px -14px rgba(0,0,0,0.55)" : "none", transition: "border-color .2s ease, background .2s ease" }}>
                  {orbChip(id, 58)}
                  <span style={{ fontSize: 13, fontWeight: 600, letterSpacing: 0.2 }}>{o.name}</span>
                  <span style={{ fontSize: 10, fontWeight: 700, letterSpacing: 0.7, textTransform: "uppercase", color: sel ? inkA(0.72) : inkA(0.36) }}>{sel ? "In use" : "Tap to use"}</span>
                </button>
              );
            })}
          </div>

          {/* Your sounds — free + everything you own, tap to breathe with it */}
          <div style={{ fontSize: 11, letterSpacing: 3, textTransform: "uppercase", fontWeight: 600, opacity: 0.5, marginBottom: 13 }}>Your sounds</div>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(94px, 1fr))", gap: 11, marginBottom: 16 }}>
            {SOUND.filter((s) => soundOwned(s.id) && (!editingSleepSound || s.bed)).map((s) => {
              const sel = activeSoundId === s.id;
              return (
                <button key={s.id} className="lull-btn" aria-pressed={sel} onClick={() => selectSound(s.id)} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 9, padding: "15px 8px 12px", borderRadius: 18, background: sel ? wa(0.09) : wa(0.03), border: "1px solid " + (sel ? wa(0.34) : wa(0.1)), boxShadow: sel ? "0 8px 22px -14px rgba(0,0,0,0.55)" : "none", transition: "border-color .2s ease, background .2s ease" }}>
                  {soundChip(s.id, 58)}
                  <span style={{ fontSize: 13, fontWeight: 600, letterSpacing: 0.2 }}>{s.name}</span>
                  <span style={{ fontSize: 10, fontWeight: 700, letterSpacing: 0.7, textTransform: "uppercase", color: sel ? inkA(0.72) : inkA(0.36) }}>{sel ? "In use" : "Tap to use"}</span>
                </button>
              );
            })}
          </div>
          {soundOwned("binaural") && (<p style={{ fontSize: 12, opacity: 0.5, margin: "0 0 24px", letterSpacing: 0.2 }}>Binaural is best with headphones.</p>)}

          {/* Your mixes — saved blends live here with the sounds. Tap to use, ✎ to edit, or build a new one. */}
          <div style={{ fontSize: 11, letterSpacing: 3, textTransform: "uppercase", fontWeight: 600, opacity: 0.5, marginBottom: 13 }}>Your mixes</div>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(94px, 1fr))", gap: 11, marginBottom: 24 }}>
            {mixPresets.map((pr) => {
              const ref = "mix:" + pr.id; const sel = activeSoundId === ref;
              return (
                <div key={pr.id} style={{ position: "relative" }}>
                  <button className="lull-btn" aria-pressed={sel} aria-label={"Use mix " + pr.name} onClick={() => selectSound(ref)} style={{ width: "100%", display: "flex", flexDirection: "column", alignItems: "center", gap: 9, padding: "15px 8px 12px", borderRadius: 18, background: sel ? wa(0.09) : wa(0.03), border: "1px solid " + (sel ? wa(0.34) : wa(0.1)), boxShadow: sel ? "0 8px 22px -14px rgba(0,0,0,0.55)" : "none", transition: "border-color .2s ease, background .2s ease" }}>
                    {soundChipFor(ref, 58)}
                    <span style={{ fontSize: 13, fontWeight: 600, letterSpacing: 0.2, textAlign: "center", lineHeight: 1.15 }}>{pr.name}</span>
                    <span style={{ fontSize: 10, fontWeight: 700, letterSpacing: 0.7, textTransform: "uppercase", color: sel ? inkA(0.72) : inkA(0.36) }}>{sel ? "In use" : "Tap to use"}</span>
                  </button>
                  <button className="lull-btn" aria-label={"Edit " + pr.name} onClick={() => editMix(pr)} style={{ position: "absolute", top: 7, right: 7, width: 26, height: 26, borderRadius: "50%", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 12, color: inkA(0.72), background: wa(0.16), border: "1px solid " + wa(0.16) }}>✎</button>
                </div>
              );
            })}
            <button className="lull-btn" aria-label="Create a new mix" onClick={newMix} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 9, padding: "15px 8px 12px", borderRadius: 18, background: wa(0.02), border: "1px dashed " + wa(0.28), transition: "border-color .2s ease, background .2s ease" }}>
              <div style={{ width: 58, height: 58, borderRadius: "50%", display: "flex", alignItems: "center", justifyContent: "center", background: wa(0.05), border: "1px solid " + wa(0.14), fontSize: 26, fontWeight: 200, lineHeight: 1 }}>＋</div>
              <span style={{ fontSize: 13, fontWeight: 600, letterSpacing: 0.2 }}>New mix</span>
              <span style={{ fontSize: 10, fontWeight: 700, letterSpacing: 0.7, textTransform: "uppercase", color: inkA(0.36) }}>Build a blend</span>
            </button>
          </div>

          {/* Offers — bundle hero + packs, each hidden once fully owned */}
          {!allOwned && (
            <>
              <div style={{ fontSize: 11, letterSpacing: 3, textTransform: "uppercase", fontWeight: 600, opacity: 0.5, marginBottom: 13 }}>Unlock more</div>
              <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
                <div style={{ padding: 18, borderRadius: 22, background: "linear-gradient(152deg, rgba(154,134,255,0.18), rgba(111,92,255,0.05))", border: "1px solid " + wa(0.2) }}>
                  <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 13 }}>
                    <span style={{ fontSize: 18, fontWeight: 700, letterSpacing: 0.2 }}>Everything</span>
                    <span style={{ fontSize: 10, fontWeight: 700, letterSpacing: 0.6, textTransform: "uppercase", padding: "3px 9px", borderRadius: 999, background: wa(0.15), color: inkA(0.82) }}>Best value</span>
                  </div>
                  <div style={{ display: "flex", marginBottom: 14 }}>
                    {["ember", "verdant", "blossom", "nova", "frost"].map((id, i) => (
                      <div key={id} style={{ marginLeft: i ? -14 : 0, borderRadius: "50%", boxShadow: "0 0 0 2.5px rgba(8,5,16,0.92)" }}>{orbChip(id, 46)}</div>
                    ))}
                  </div>
                  <div style={{ fontSize: 13, lineHeight: 1.5, opacity: 0.72, marginBottom: 15 }}>{BUNDLE.tag}. Unlocked forever.</div>
                  <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 12 }}>
                    <span style={{ fontSize: 15, fontWeight: 700, letterSpacing: 0.2 }}>{fmtPrice(BUNDLE.price)}<span style={{ fontSize: 12, fontWeight: 500, opacity: 0.55 }}> · one time</span></span>
                    <button className="lull-btn" onClick={() => buyProduct(IAP_PRODUCTS.everything, () => { setBundleOwned(true); unlockBundle(); })} style={{ padding: "11px 22px", borderRadius: 999, fontSize: 14, fontWeight: 700, letterSpacing: 0.3, whiteSpace: "nowrap", color: "#fff", background: "linear-gradient(180deg, #9a86ff 0%, #6f5cff 100%)", boxShadow: "0 10px 22px -10px rgba(111,92,255,0.9)" }}>Unlock all</button>
                  </div>
                </div>
                {PACK_ORDER.map((pid) => {
                  const p = PACKS[pid]; if (packOwned(p)) return null;
                  return (
                    <div key={pid} style={{ padding: 16, borderRadius: 20, background: wa(0.05), border: "1px solid " + wa(0.12) }}>
                      <div style={{ display: "flex", marginBottom: 13 }}>
                        {p.orbs.map((id, i) => (
                          <div key={id} style={{ marginLeft: i ? -12 : 0, borderRadius: "50%", boxShadow: "0 0 0 2.5px rgba(8,5,16,0.92)" }}>{orbChip(id, 40)}</div>
                        ))}
                      </div>
                      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 12 }}>
                        <div style={{ minWidth: 0 }}>
                          <div style={{ fontSize: 15.5, fontWeight: 600, letterSpacing: 0.2 }}>{p.name}</div>
                          <div style={{ fontSize: 12, opacity: 0.55, marginTop: 3 }}>{p.tag}</div>
                        </div>
                        <button className="lull-btn" onClick={() => buyProduct(IAP_PRODUCTS[pid], () => unlockPack(pid))} style={{ padding: "10px 18px", borderRadius: 999, fontSize: 13.5, fontWeight: 600, letterSpacing: 0.3, whiteSpace: "nowrap", color: ink, background: wa(0.12), border: "1px solid " + wa(0.22) }}>{fmtPrice(p.price)}</button>
                      </div>
                    </div>
                  );
                })}
                {SOUND_PACK_ORDER.map((pid) => {
                  const p = SOUND_PACKS[pid]; if (soundPackOwned(p)) return null;
                  return (
                    <div key={pid} style={{ padding: 16, borderRadius: 20, background: wa(0.05), border: "1px solid " + wa(0.12) }}>
                      <div style={{ display: "flex", marginBottom: 13 }}>
                        {p.sounds.map((id, i) => (
                          <div key={id} style={{ marginLeft: i ? -12 : 0, borderRadius: "50%", boxShadow: "0 0 0 2.5px rgba(8,5,16,0.92)" }}>{soundChip(id, 40)}</div>
                        ))}
                      </div>
                      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 12 }}>
                        <div style={{ minWidth: 0 }}>
                          <div style={{ fontSize: 15.5, fontWeight: 600, letterSpacing: 0.2 }}>{p.name}</div>
                          <div style={{ fontSize: 12, opacity: 0.55, marginTop: 3 }}>{p.tag}</div>
                        </div>
                        <button className="lull-btn" onClick={() => buyProduct(IAP_PRODUCTS[pid], () => unlockSoundPack(pid))} style={{ padding: "10px 18px", borderRadius: 999, fontSize: 13.5, fontWeight: 600, letterSpacing: 0.3, whiteSpace: "nowrap", color: ink, background: wa(0.12), border: "1px solid " + wa(0.22) }}>{fmtPrice(p.price)}</button>
                      </div>
                    </div>
                  );
                })}
              </div>
            </>
          )}
          <button className="lull-btn" onClick={restoreOrbs} style={{ alignSelf: "center", marginTop: 22, padding: "8px 0", fontSize: 12.5, letterSpacing: 0.4, color: inkA(0.5) }}>Restore purchases</button>
          <p style={{ fontSize: 11.5, lineHeight: 1.5, opacity: 0.42, textAlign: "center", margin: "6px auto 0", maxWidth: "40ch" }}>One time purchases, no subscription. Restore anytime.</p>
        </div>
      )}
      {showCustom && (
        <div style={{ position: "fixed", inset: 0, zIndex: 60, backgroundColor: groundSolid, backgroundImage: groundBg, color: ink, display: "flex", flexDirection: "column", padding: "max(30px, calc(env(safe-area-inset-top) + 12px)) 26px calc(34px + env(safe-area-inset-bottom))", overflowY: "auto" }}>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 22 }}>
            <span style={{ fontSize: 12, letterSpacing: 5, textTransform: "uppercase", fontWeight: 500, opacity: 0.6 }}>Your pattern</span>
            <button className="lull-btn" aria-label="Cancel" onClick={() => setShowCustom(false)} style={{ padding: "6px 4px", opacity: 0.75, fontSize: 15 }}>Cancel</button>
          </div>
          {(() => {
            const parts = [draft.inhale, draft.hold, draft.exhale, draft.hold2].filter((n) => n > 0);
            const total = draft.inhale + draft.hold + draft.exhale + draft.hold2;
            const rows = [["inhale", "Inhale", 2, 12], ["hold", "Hold", 0, 20], ["exhale", "Exhale", 2, 20], ["hold2", "Hold after", 0, 20]];
            const stepBtn = { width: 44, height: 44, borderRadius: 14, border: "1px solid " + wa(0.16), background: wa(0.06), color: ink, fontSize: 22, fontWeight: 300, display: "flex", alignItems: "center", justifyContent: "center" };
            return (<>
              <div style={{ textAlign: "center", marginBottom: 6 }}>
                <div style={{ fontSize: 42, fontWeight: 200, letterSpacing: 1, fontVariantNumeric: "tabular-nums" }}>{parts.join(" · ")}</div>
                <div style={{ fontSize: 13, opacity: 0.5, marginTop: 6 }}>{total}s per breath</div>
              </div>
              <div style={{ display: "flex", flexDirection: "column", gap: 10, marginTop: 22, maxWidth: 340, width: "100%", alignSelf: "center" }}>
                {rows.map(([k, label, lo, hi]) => (
                  <div key={k} style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 12 }}>
                    <span style={{ fontSize: 15 }}>{label}</span>
                    <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
                      <button className="lull-btn" aria-label={`decrease ${label}`} onClick={() => bump(k, -1, lo, hi)} style={stepBtn}>−</button>
                      <span style={{ minWidth: 34, textAlign: "center", fontSize: 20, fontWeight: 400, fontVariantNumeric: "tabular-nums" }}>{draft[k]}</span>
                      <button className="lull-btn" aria-label={`increase ${label}`} onClick={() => bump(k, 1, lo, hi)} style={stepBtn}>+</button>
                    </div>
                  </div>
                ))}
              </div>
              <button className="lull-btn lull-cta" onClick={saveCustomPat} style={{ ...glassBtn, maxWidth: 340, alignSelf: "center", marginTop: 28 }}>Save pattern</button>
              <div style={{ marginTop: "auto", paddingTop: 24, fontSize: 12.5, opacity: 0.4, textAlign: "center", letterSpacing: 0.3 }}>Set a hold to 0 to skip it. Your pattern stays on this device.</div>
            </>);
          })()}
        </div>
      )}

      {showSleepTime && (
        <div style={{ position: "fixed", inset: 0, zIndex: 60, backgroundColor: groundSolid, backgroundImage: groundBg, color: ink, display: "flex", flexDirection: "column", padding: "max(30px, calc(env(safe-area-inset-top) + 12px)) 26px calc(34px + env(safe-area-inset-bottom))", overflowY: "auto" }}>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 22 }}>
            <span style={{ fontSize: 12, letterSpacing: 5, textTransform: "uppercase", fontWeight: 500, opacity: 0.6 }}>Sleep timer</span>
            <button className="lull-btn" aria-label="Cancel" onClick={() => setShowSleepTime(false)} style={{ padding: "6px 4px", opacity: 0.75, fontSize: 15 }}>Cancel</button>
          </div>
          {(() => {
            const stepBtn = { width: 44, height: 44, borderRadius: 14, border: "1px solid " + wa(0.16), background: wa(0.06), color: ink, fontSize: 22, fontWeight: 300, display: "flex", alignItems: "center", justifyContent: "center" };
            const rows = [["h", "Hours", 0, 12, 1], ["m", "Minutes", 0, 45, 15]];
            return (<>
              <div style={{ textAlign: "center", marginBottom: 6 }}>
                <div style={{ fontSize: 42, fontWeight: 200, letterSpacing: 1, fontVariantNumeric: "tabular-nums" }}>{sleepDraft.h}h {sleepDraft.m}m</div>
                <div style={{ fontSize: 13, opacity: 0.5, marginTop: 6 }}>Sound plays until the time is up. Set it and drift off.</div>
              </div>
              <div style={{ display: "flex", flexDirection: "column", gap: 10, marginTop: 22, maxWidth: 340, width: "100%", alignSelf: "center" }}>
                {rows.map(([k, label, lo, hi, step]) => (
                  <div key={k} style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 12 }}>
                    <span style={{ fontSize: 15 }}>{label}</span>
                    <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
                      <button className="lull-btn" aria-label={`decrease ${label}`} onClick={() => bumpSleep(k, -step, lo, hi)} style={stepBtn}>−</button>
                      <span style={{ minWidth: 44, textAlign: "center", fontSize: 20, fontWeight: 400, fontVariantNumeric: "tabular-nums" }}>{sleepDraft[k]}</span>
                      <button className="lull-btn" aria-label={`increase ${label}`} onClick={() => bumpSleep(k, step, lo, hi)} style={stepBtn}>+</button>
                    </div>
                  </div>
                ))}
              </div>
              <button className="lull-btn lull-cta" onClick={saveSleepTime} style={{ ...glassBtn, maxWidth: 340, alignSelf: "center", marginTop: 28 }}>Set timer</button>
              <div style={{ marginTop: "auto", paddingTop: 24, fontSize: 12.5, opacity: 0.4, textAlign: "center", letterSpacing: 0.3, maxWidth: "42ch", alignSelf: "center" }}>Keep Lull open with the screen on for the full timer. Background play with the phone locked comes with the iOS app.</div>
            </>);
          })()}
        </div>
      )}

      {onboard && (() => { const s = ONBOARD_SLIDES[onboardStep] || ONBOARD_SLIDES[0]; const last = onboardStep === ONBOARD_SLIDES.length - 1; return (
        <div style={{ position: "fixed", inset: 0, zIndex: 70, backgroundColor: groundSolid, backgroundImage: groundBg, color: ink, display: "flex", flexDirection: "column", padding: "max(30px, calc(env(safe-area-inset-top) + 14px)) 28px calc(30px + env(safe-area-inset-bottom))", overflowY: "auto" }}>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
            <span style={{ fontSize: 13, letterSpacing: 6, fontWeight: 600, opacity: 0.85 }}>LULL</span>
            <button className="lull-btn" onClick={finishOnboard} style={{ ...textBtn, padding: "6px 4px", fontSize: 13 }}>Skip</button>
          </div>
          <div style={{ flex: "1 1 auto", minHeight: 0, overflow: "hidden", display: "flex", alignItems: "center", justifyContent: "center" }}>
            <div style={{ position: "relative", width: 240, height: 240, flex: "0 0 auto", display: "flex", alignItems: "center", justifyContent: "center", animation: "onbBreath 7s ease-in-out infinite" }}>
              <div style={{ position: "absolute", inset: 0, borderRadius: "50%", border: "1px solid " + wa(0.07) }} />
              <div style={{ position: "absolute", inset: "17%", borderRadius: "50%", border: "1px solid " + wa(0.11) }} />
              <div style={{ borderRadius: "50%", boxShadow: `0 0 80px ${ringFrom}55` }}>{orbChip(orbId, 150)}</div>
            </div>
          </div>
          <div key={onboardStep} style={{ animation: "onbFade .5s ease both" }}>
            <div style={{ fontSize: 11, letterSpacing: 3, textTransform: "uppercase", fontWeight: 600, opacity: 0.5, marginBottom: 13 }}>{s.eyebrow}</div>
            <h1 style={{ fontSize: "clamp(26px, 7.4vw, 37px)", fontWeight: 300, lineHeight: 1.08, letterSpacing: -0.5, margin: 0 }}>{s.title[0]}<br />{s.title[1]}</h1>
            <p style={{ fontSize: 15.5, lineHeight: 1.55, opacity: 0.55, margin: "16px 0 0", maxWidth: "34ch" }}>{s.body}</p>
          </div>
          <div style={{ display: "flex", gap: 7, margin: "22px 0 16px" }}>
            {ONBOARD_SLIDES.map((_, i) => (
              <div key={i} style={{ height: 6, width: i === onboardStep ? 26 : 6, borderRadius: 999, background: i === onboardStep ? inkA(0.75) : inkA(0.22), transition: "width .3s ease, background .3s ease" }} />
            ))}
          </div>
          <button className="lull-btn" onClick={nextOnboard} style={{ ...glassBtn, position: "relative", zIndex: 1 }}>{last ? "Begin" : "Continue"}</button>
          <div style={{ textAlign: "center", fontSize: 12.5, opacity: 0.4, marginTop: 14 }}>{s.foot}</div>
        </div>
      ); })()}

      {preCheck && (
        <div style={{ position: "fixed", inset: 0, zIndex: 65, backgroundColor: groundSolid, backgroundImage: groundBg, color: ink, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", textAlign: "center", gap: 18, padding: "max(30px, calc(env(safe-area-inset-top) + 12px)) 30px calc(34px + env(safe-area-inset-bottom))" }}>
          <div style={{ fontSize: 11, letterSpacing: 3, textTransform: "uppercase", fontWeight: 600, opacity: 0.5 }}>Before you begin</div>
          <div style={{ fontSize: 25, fontWeight: 300, letterSpacing: 0.4 }}>How do you feel?</div>
          <p style={{ fontSize: 13.5, opacity: 0.5, margin: "-6px 0 4px", maxWidth: "30ch", lineHeight: 1.5 }}>One tap, and we’ll check in again after. Just for you, stays on this device.</p>
          {moodScale(null, startAfterCheckin)}
          <button className="lull-btn" onClick={() => startAfterCheckin(null)} style={{ ...textBtn, marginTop: 8 }}>Skip</button>
        </div>
      )}

      {ready && (
        <div style={{ position: "fixed", inset: 0, zIndex: 66, backgroundColor: groundSolid, backgroundImage: groundBg, color: ink, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", textAlign: "center", gap: 16, padding: "max(30px, calc(env(safe-area-inset-top) + 12px)) 30px calc(34px + env(safe-area-inset-bottom))" }}>
          <div style={{ fontSize: 11, letterSpacing: 3, textTransform: "uppercase", fontWeight: 600, opacity: 0.5 }}>Get ready</div>
          <div key={readyN} className="ready-count" style={{ fontVariantNumeric: "tabular-nums", fontWeight: readyN > 0 ? 200 : 300, fontSize: readyN > 0 ? 96 : 42, letterSpacing: readyN > 0 ? -2 : 1, lineHeight: 1, minHeight: 100, display: "flex", alignItems: "center", justifyContent: "center" }}>{readyN > 0 ? readyN : "Breathe"}</div>
          <p style={{ fontSize: 15, opacity: 0.62, margin: 0, maxWidth: "26ch", lineHeight: 1.5, minHeight: 44 }}>{readySaying}</p>
          <button className="lull-btn" onClick={skipReady} style={{ ...textBtn, marginTop: 6 }}>Begin now</button>
        </div>
      )}

      {showHistory && (
        <div style={{ position: "fixed", inset: 0, zIndex: 60, backgroundColor: groundSolid, backgroundImage: groundBg, color: ink, display: "flex", flexDirection: "column", padding: "max(30px, calc(env(safe-area-inset-top) + 12px)) 26px calc(34px + env(safe-area-inset-bottom))", overflowY: "auto" }}>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 28 }}>
            <span style={{ fontSize: 12, letterSpacing: 5, textTransform: "uppercase", fontWeight: 500, opacity: 0.6 }}>Insights</span>
            <button className="lull-btn" aria-label="Close" onClick={() => setShowHistory(false)} style={{ padding: "6px 4px", opacity: 0.75, fontSize: 15 }}>Done</button>
          </div>
          {(() => {
            const week = minutesSince(sessions, Date.now() - 7 * DAY_MS);
            const all = minutesSince(sessions);
            const lift = moodLift(sessions);
            const recent = sessions.slice(-9).reverse();
            const liftGreen = lightUI ? "#2e8b57" : "#8fe0b0";
            return (<>
              <div style={{ marginTop: 4 }}>
                <div style={{ fontSize: 58, fontWeight: 200, letterSpacing: -1, lineHeight: 1, fontVariantNumeric: "tabular-nums" }}>{week}<span style={{ fontSize: 20, fontWeight: 300, opacity: 0.55, marginLeft: 8 }}>min</span></div>
                <div style={{ fontSize: 14, opacity: 0.55, marginTop: 8, maxWidth: 300 }}>{week > 0 ? "to breathe, this week" : "A quiet week. Your breaths are here when you need them."}</div>
              </div>
              <div style={{ fontSize: 13, opacity: 0.42, marginTop: 18, letterSpacing: 0.2 }}>{all} minutes · {sessions.length} {sessions.length === 1 ? "breath" : "breaths"}, all-time</div>
              {lift && (
                <div style={{ marginTop: 22, padding: "16px 18px", borderRadius: 16, background: wa(0.05), border: "1px solid " + wa(0.1) }}>
                  {lift.avg > 0.05 ? (<>
                    <div style={{ fontSize: 27, fontWeight: 300, letterSpacing: -0.2, fontVariantNumeric: "tabular-nums", color: liftGreen }}>+{lift.avg.toFixed(1)}<span style={{ fontSize: 13, fontWeight: 400, opacity: 0.75, marginLeft: 9, letterSpacing: 0.3, color: ink }}>calmer, on average</span></div>
                    <div style={{ fontSize: 12.5, opacity: 0.5, marginTop: 6, lineHeight: 1.5 }}>Across {lift.n} mood {lift.n === 1 ? "rating" : "ratings"}, on a 1 to 5 scale. How much a session tends to settle you.</div>
                  </>) : (<>
                    <div style={{ fontSize: 18, fontWeight: 300, letterSpacing: 0.2 }}>You show up for yourself.</div>
                    <div style={{ fontSize: 12.5, opacity: 0.5, marginTop: 6, lineHeight: 1.5 }}>{lift.n} mood {lift.n === 1 ? "rating" : "ratings"} recorded. However you feel is okay.</div>
                  </>)}
                </div>
              )}
              <div style={{ marginTop: 24, display: "flex", flexDirection: "column" }}>
                {recent.map((s, i) => { const d = new Date(s.t); const day = d.toLocaleDateString(undefined, { weekday: "short", month: "short", day: "numeric" }); const pn = (PATTERNS[s.mode] && PATTERNS[s.mode][s.pattern] && PATTERNS[s.mode][s.pattern].name) || s.pattern; const hasMood = typeof s.moodBefore === "number" && typeof s.moodAfter === "number"; const md = hasMood ? s.moodAfter - s.moodBefore : null; return (
                  <div key={i} style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "13px 2px", borderBottom: "1px solid " + wa(0.08) }}>
                    <span style={{ fontSize: 14 }}>{day}</span>
                    <span style={{ display: "flex", alignItems: "center", gap: 9 }}>
                      {hasMood && (<span style={{ fontSize: 11, fontWeight: 600, letterSpacing: 0.2, padding: "2px 7px", borderRadius: 999, fontVariantNumeric: "tabular-nums", color: md > 0 ? liftGreen : inkA(0.6), background: md > 0 ? (lightUI ? "rgba(46,139,87,0.12)" : "rgba(140,224,176,0.14)") : wa(0.06) }}>{md > 0 ? `+${md}` : md === 0 ? "±0" : `${md}`}</span>)}
                      <span style={{ fontSize: 13, opacity: 0.55 }}>{s.mode === "sleep" ? "Sleep" : pn} · {s.min} min</span>
                    </span>
                  </div>); })}
              </div>
              <div style={{ marginTop: "auto", paddingTop: 30, display: "flex", flexWrap: "wrap", gap: 10, justifyContent: "center" }}>
                <button className="lull-btn" onClick={() => { setShowHistory(false); replayOnboard(); }} style={{ padding: "9px 16px", borderRadius: 999, fontSize: 12.5, letterSpacing: 0.3, color: inkA(0.7), background: wa(0.05), border: "1px solid " + wa(0.12) }}>Replay intro</button>
                <button className="lull-btn" onClick={exportData} style={{ padding: "9px 16px", borderRadius: 999, fontSize: 12.5, letterSpacing: 0.3, color: inkA(0.7), background: wa(0.05), border: "1px solid " + wa(0.12) }}>Export my breaths</button>
                <button className="lull-btn" onClick={eraseData} style={{ padding: "9px 16px", borderRadius: 999, fontSize: 12.5, letterSpacing: 0.3, color: inkA(0.55), background: "transparent", border: "1px solid " + wa(0.12) }}>Erase everything</button>
              </div>
              <div style={{ paddingTop: 16, fontSize: 12.5, opacity: 0.4, textAlign: "center", letterSpacing: 0.3 }}>No streaks. No goals. Just the breaths you’ve taken. Private to this device.</div>
            </>);
          })()}
        </div>
      )}

      {mixerOpen && (
        <div style={{ position: "fixed", inset: 0, zIndex: 70, backgroundColor: groundSolid, backgroundImage: groundBg, color: ink, display: "flex", flexDirection: "column", padding: "max(30px, calc(env(safe-area-inset-top) + 12px)) 26px calc(34px + env(safe-area-inset-bottom))", overflowY: "auto" }}>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 6 }}>
            <span style={{ fontSize: 12, letterSpacing: 5, textTransform: "uppercase", fontWeight: 500, opacity: 0.6 }}>Ambient sounds</span>
            <button className="lull-btn" aria-label="Close" onClick={closeMixer} style={{ padding: "6px 4px", opacity: 0.75, fontSize: 15 }}>Done</button>
          </div>
          <p style={{ fontSize: 13, lineHeight: 1.5, opacity: 0.55, margin: "0 0 24px", maxWidth: "42ch" }}>{editingPresetId ? "Editing a saved mix. Adjust the sliders, then Update to save your changes." : "Blend nature sounds into your own mix and let it play. No timer, no session. Slide a sound up to hear it."}</p>
          {(() => {
            const owned = NATURE_IDS.filter((id) => soundOwned(id));
            if (!owned.length) return (
              <div style={{ marginTop: 10, textAlign: "center" }}>
                <p style={{ fontSize: 14, opacity: 0.6, lineHeight: 1.6, margin: "0 auto 18px", maxWidth: "34ch" }}>The Nature pack (rain, ocean, forest &amp; fire) unlocks the mixer.</p>
                <button className="lull-btn" onClick={() => { setMixerOpen(false); setOrbStoreOpen(true); }} style={{ padding: "11px 22px", borderRadius: 999, fontSize: 14, fontWeight: 600, letterSpacing: 0.3, color: "#fff", background: "linear-gradient(180deg, #9a86ff 0%, #6f5cff 100%)", boxShadow: "0 10px 22px -12px rgba(111,92,255,0.9)" }}>Get the Nature pack</button>
              </div>
            );
            return (<>
              <div style={{ display: "flex", flexDirection: "column", gap: 18 }}>
                {owned.map((id) => { const s = SOUND_BY_ID[id] || {}; const lvl = mix[id] || 0; const on = mixPlaying && lvl > 0; return (
                  <div key={id} style={{ display: "flex", alignItems: "center", gap: 14 }}>
                    <div style={{ position: "relative", flexShrink: 0 }}>{soundChip(id, 44)}{on && (<span aria-hidden="true" style={{ position: "absolute", right: -1, bottom: -1, width: 11, height: 11, borderRadius: "50%", background: "#8ce0b0", boxShadow: "0 0 0 2px " + groundSolid }} />)}</div>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", marginBottom: 3 }}>
                        <span style={{ fontSize: 14.5, fontWeight: 500 }}>{s.name}</span>
                        <span style={{ fontSize: 11, opacity: 0.45, fontVariantNumeric: "tabular-nums", letterSpacing: 0.3 }}>{lvl > 0 ? Math.round(lvl * 100) + "%" : "off"}</span>
                      </div>
                      <input className="lull-range" type="range" min="0" max="100" value={Math.round(lvl * 100)} aria-label={(s.name || "sound") + " volume"} onChange={(e) => onMixSlide(id, +e.target.value / 100)} />
                    </div>
                  </div>
                ); })}
              </div>
              <div style={{ marginTop: 32, display: "flex", justifyContent: "center" }}>
                <button className="lull-btn" onClick={() => { if (mixPlaying) { stopMix(); return; } const anyOn = owned.some((id) => (mix[id] || 0) > 0); if (!anyOn) setMixLevel(owned[0], 0.6); startMix(); }} style={{ padding: "13px 44px", borderRadius: 999, fontSize: 15, fontWeight: 600, letterSpacing: 0.4, color: "#fff", background: "linear-gradient(180deg, #9a86ff 0%, #6f5cff 100%)", boxShadow: "0 12px 26px -12px rgba(111,92,255,0.9)" }}>{mixPlaying ? "Pause" : "Play"}</button>
              </div>
              <div style={{ marginTop: 28 }}>
                <div style={{ fontSize: 11, letterSpacing: 3, textTransform: "uppercase", fontWeight: 600, opacity: 0.5, marginBottom: 12 }}>Saved mixes</div>
                {mixPresets.length > 0 ? (
                  <div style={{ display: "flex", flexWrap: "wrap", gap: 9 }}>
                    {mixPresets.map((pr) => (
                      <span key={pr.id} style={{ display: "inline-flex", alignItems: "center", gap: 6, padding: "7px 7px 7px 14px", borderRadius: 999, background: wa(0.06), border: "1px solid " + wa(0.16) }}>
                        <button className="lull-btn" onClick={() => loadPreset(pr)} style={{ fontSize: 13.5, fontWeight: 500, letterSpacing: 0.2, color: ink }}>{pr.name}</button>
                        <button className="lull-btn" aria-label={"Delete " + pr.name} onClick={() => deletePreset(pr.id)} style={{ width: 20, height: 20, borderRadius: "50%", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 14, lineHeight: 1, color: inkA(0.5), background: wa(0.09) }}>×</button>
                      </span>
                    ))}
                  </div>
                ) : (<p style={{ fontSize: 12.5, opacity: 0.42, margin: 0, lineHeight: 1.5 }}>Dial in a blend, then save it to bring it back anytime.</p>)}
                {savingMix ? (
                  <div style={{ display: "flex", gap: 8, marginTop: 14, alignItems: "center" }}>
                    <input autoFocus value={mixName} maxLength={24} onChange={(e) => setMixName(e.target.value)} onKeyDown={(e) => { if (e.key === "Enter") saveMixPreset(); else if (e.key === "Escape") { setSavingMix(false); setMixName(""); } }} placeholder="Name this mix" style={{ flex: 1, minWidth: 0, padding: "10px 14px", borderRadius: 999, background: wa(0.06), border: "1px solid " + wa(0.22), color: ink, fontSize: 14, fontFamily: "inherit", outline: "none" }} />
                    <button className="lull-btn" onClick={saveMixPreset} style={{ padding: "10px 18px", borderRadius: 999, fontSize: 13.5, fontWeight: 600, color: "#fff", background: "linear-gradient(180deg, #9a86ff 0%, #6f5cff 100%)" }}>{editingPresetId ? "Update" : "Save"}</button>
                    <button className="lull-btn" onClick={() => { setSavingMix(false); setMixName(""); setEditingPresetId(null); }} style={{ padding: "10px 4px", fontSize: 13, color: inkA(0.5) }}>Cancel</button>
                  </div>
                ) : (owned.some((id) => (mix[id] || 0) > 0) && (
                  <button className="lull-btn" onClick={beginSaveMix} style={{ marginTop: 14, padding: "9px 18px", borderRadius: 999, fontSize: 13, fontWeight: 600, letterSpacing: 0.3, color: ink, background: wa(0.06), border: "1px dashed " + wa(0.3), display: "inline-flex", alignItems: "center", gap: 7 }}><span aria-hidden="true" style={{ fontSize: 14, opacity: 0.85 }}>＋</span>Save this mix</button>
                ))}
              </div>
              <p style={{ marginTop: 22, fontSize: 11.5, opacity: 0.4, textAlign: "center", letterSpacing: 0.3, lineHeight: 1.5 }}>Lock-screen controls appear while it plays. Your blend is saved on this device.</p>
            </>);
          })()}
        </div>
      )}

      {exportOpen && (
        <div style={{ position: "fixed", inset: 0, zIndex: 70, backgroundColor: groundSolid, backgroundImage: groundBg, color: ink, display: "flex", flexDirection: "column", padding: "max(30px, calc(env(safe-area-inset-top) + 12px)) 26px calc(34px + env(safe-area-inset-bottom))", overflow: "hidden" }}>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 6 }}>
            <span style={{ fontSize: 12, letterSpacing: 5, textTransform: "uppercase", fontWeight: 500, opacity: 0.6 }}>Your breaths</span>
            <button className="lull-btn" aria-label="Close" onClick={() => setExportOpen(false)} style={{ padding: "6px 4px", opacity: 0.75, fontSize: 15 }}>Done</button>
          </div>
          <p style={{ fontSize: 13, lineHeight: 1.5, opacity: 0.55, margin: "0 0 16px", maxWidth: "44ch" }}>Everything Lull has saved: {sessions.length} {sessions.length === 1 ? "session" : "sessions"}. Copy it or download it as a file. It never leaves your device.</p>
          <textarea id="lull-export-ta" readOnly value={exportJson()} onFocus={(e) => e.target.select()} spellCheck={false} style={{ flex: 1, minHeight: 0, width: "100%", resize: "none", boxSizing: "border-box", padding: 14, borderRadius: 16, background: wa(0.05), border: "1px solid " + wa(0.14), color: inkA(0.85), fontSize: 12, lineHeight: 1.5, fontFamily: "ui-monospace, SFMono-Regular, Menlo, monospace", WebkitOverflowScrolling: "touch" }} />
          <div style={{ marginTop: 16, display: "flex", gap: 10, justifyContent: "center" }}>
            <button className="lull-btn" onClick={copyExport} style={{ padding: "11px 22px", borderRadius: 999, fontSize: 14, fontWeight: 600, letterSpacing: 0.3, color: "#fff", background: "linear-gradient(180deg, #9a86ff 0%, #6f5cff 100%)", boxShadow: "0 10px 22px -12px rgba(111,92,255,0.9)" }}>{copied ? "Copied ✓" : "Copy"}</button>
            <button className="lull-btn" onClick={downloadExport} style={{ padding: "11px 20px", borderRadius: 999, fontSize: 14, fontWeight: 500, letterSpacing: 0.3, color: ink, background: wa(0.06), border: "1px solid " + wa(0.16) }}>Download file</button>
          </div>
          <p style={{ paddingTop: 14, fontSize: 11.5, opacity: 0.4, textAlign: "center", letterSpacing: 0.3, lineHeight: 1.5 }}>On phones, Copy is the reliable one. Paste into Notes, email or a doc to keep it.</p>
        </div>
      )}

      {sleepDone && (
        <div onClick={goHome} role="button" aria-label="Exit" style={{ position: "fixed", inset: 0, zIndex: 50, display: "flex", alignItems: "center", justifyContent: "center", background: "#050302", opacity: sleepVeil, transition: "opacity 3.4s ease", cursor: "pointer" }}>
          <span style={{ fontSize: 16, fontWeight: 300, letterSpacing: 3, color: "rgba(243,239,255,0.5)", opacity: sleepVeil, transition: "opacity 4s ease 1s" }}>Sleep well.</span>
        </div>
      )}
    </div>
  );
}
