import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import type { Contact, GroupName, Screen, Speed } from './types';
import type { ThemeName } from './theme';
import { SEED } from './data';
import { initialsOf, phoneKey, nameKey } from './orbit';
import { fileStorage } from './persist';

type FilterGroup = 'All' | GroupName;

interface State {
  contacts: Record<string, Contact>;
  theme: ThemeName;
  screen: Screen;
  currentId: string | null;
  activeGroup: FilterGroup;
  onboarded: boolean;
  hydrated: boolean;
  toast: string | null;
  sheet: 'add' | 'action' | 'import' | 'reach' | 'log' | null;
  reachId: string | null;
  logId: string | null;
  mePhoto: string | null;     // your own photo at the center of the orbit
  heartPing: { n: number; color: string; at: number } | null;  // pulses a floating heart on the orbit when you reconnect

  setScreen: (s: Screen) => void;
  setMePhoto: (uri: string | null) => void;
  openContact: (id: string) => void;
  openAdd: () => void;
  openActions: () => void;
  openImport: () => void;
  openReach: (id: string) => void;
  openLog: (id: string) => void;
  logInteraction: (id: string, label: string) => void;
  closeSheet: () => void;
  setTheme: (t: ThemeName) => void;
  toggleTheme: () => void;
  setFilter: (g: FilterGroup) => void;
  dismissOnboarding: () => void;
  showToast: (msg: string) => void;

  addContact: (input: { name: string; role?: string; ring: number; group: GroupName; phone?: string | null }) => void;
  updateContact: (id: string, patch: Partial<Contact>) => void;
  removeContact: (id: string) => void;
  importContacts: (people: { name: string; photo?: string | null; phone?: string | null }[]) => { added: number; skipped: number };
  loadSampleOrbit: () => void;
  resetOrbit: () => void;

  pull: (id: string) => void;            // pull closer (one ring inward)
  moveOrbit: (id: string, ring: number) => void;
  toggleFav: (id: string) => void;
  toggleAnchor: (id: string) => void;
  toggleSnooze: (id: string) => void;
  setSpeed: (id: string, speed: Speed) => void;
  setNote: (id: string, note: string) => void;
  setGroup: (id: string, group: GroupName) => void;
  setReminder: (id: string, reminder: string | null) => void;
  setPhone: (id: string, phone: string | null) => void;
  settleDrift: () => void;
}

const seedMap = (): Record<string, Contact> =>
  Object.fromEntries(SEED.map((c) => [c.id, { ...c }]));

const driftOf = (ring: number, anchored?: boolean) => ring >= 3 && !anchored;

// ── Real-time drift ────────────────────────────────────────────────────────
// A person's ring reflects how long it's been since you last connected, in
// fixed buckets (not a per-person timer):
//   ring 1: < 2 weeks   ring 2: < 1 month   ring 3: < 3 months
//   ring 4: < 6 months  ring 5: < 1 year    ring 6: 1 year+  (beyond the galaxy)
const DAY_MS = 24 * 60 * 60 * 1000;
const RING_MAX_DAYS = [14, 30, 90, 180, 365]; // upper bound of rings 1..5
const ringFromElapsed = (lastContactAt: number) => {
  const days = (Date.now() - lastContactAt) / DAY_MS;
  for (let i = 0; i < RING_MAX_DAYS.length; i++) {
    if (days < RING_MAX_DAYS[i]) return i + 1;
  }
  return 6; // beyond a year — the far ring, beyond the galaxy
};
// Lower boundary (days) of each ring's bucket — used to backdate a
// "last contacted" time so someone placed on `ring` actually lands there.
const RING_START_DAYS = [0, 0, 14, 30, 90, 180, 365]; // index by ring (1..6)
const backdateFor = (ring: number) => Date.now() - (RING_START_DAYS[ring] ?? 0) * DAY_MS;

let toastTimer: ReturnType<typeof setTimeout> | undefined;
let addCounter = 0;

// A little heart floats up on the orbit whenever you reconnect with someone —
// a quiet check-in or a text. Each pulse gets a random, pleasing color.
const HEART_COLORS = ['#FF5A7A', '#FF7A59', '#F0654E', '#F5A623', '#FF6FB5', '#7C5CFF', '#4CC38A', '#3AA5FF'];
let heartN = 0;
const nextHeart = () => ({ n: ++heartN, color: HEART_COLORS[Math.floor(Math.random() * HEART_COLORS.length)], at: Date.now() });

export const useStore = create<State>()(
  persist(
    (set, get) => ({
      // Start EMPTY — real contacts you add are persisted (see below) and restored
      // on the next launch. Tap "See a sample orbit" on the empty state to preview.
      contacts: {},
      theme: 'dark',
      screen: 'orbit',
      currentId: null,
      activeGroup: 'All',
      onboarded: false,
      hydrated: false,
      toast: null,
      sheet: null,
      reachId: null,
      logId: null,
      mePhoto: null,
      heartPing: null,

      setScreen: (screen) => set({ screen }),
      setMePhoto: (uri) => set({ mePhoto: uri }),
      openContact: (id) => set({ currentId: id, screen: 'contact', sheet: null }),
      openAdd: () => set({ sheet: 'add' }),
      openActions: () => set({ sheet: 'action' }),
      openImport: () => set({ sheet: 'import' }),
      openReach: (id) => set({ sheet: 'reach', reachId: id }),
      openLog: (id) => set({ sheet: 'log', logId: id }),

      // Record what a check-in actually was and pull the person back to center.
      // The entry shows up in RECENT GRAVITY on their profile.
      logInteraction: (id, label) =>
        set((s) => {
          const c = s.contacts[id];
          if (!c) return s;
          const log = [{ at: Date.now(), label }, ...(c.log ?? [])].slice(0, 12);
          return { contacts: { ...s.contacts, [id]: { ...c, ring: 1, unit: 'just now', drift: false, lastContactAt: Date.now(), log } }, heartPing: nextHeart() };
        }),

      closeSheet: () => set({ sheet: null }),
      setTheme: (theme) => set({ theme }),
      toggleTheme: () => set((s) => ({ theme: s.theme === 'dark' ? 'coral' : 'dark' })),
      setFilter: (activeGroup) => set({ activeGroup }),
      dismissOnboarding: () => set({ onboarded: true }),

      showToast: (toast) => {
        set({ toast });
        if (toastTimer) clearTimeout(toastTimer);
        toastTimer = setTimeout(() => set({ toast: null }), 1900);
      },

      addContact: ({ name, role, ring, group, phone }) => {
        const id = 'c' + Date.now() + '_' + addCounter;
        const angle = ((addCounter++) * 87 + 30) % 360 - 180;
        const grad = 'g-' + (name.length % 5);
        set((s) => ({
          contacts: {
            ...s.contacts,
            [id]: {
              id, name, initials: initialsOf(name), grad,
              role: role?.trim() || 'New connection', unit: 'just now',
              ring, angle, drift: driftOf(ring), photo: null, phone: phone ?? null, group,
              lastContactAt: backdateFor(ring),
            },
          },
        }));
      },

      updateContact: (id, patch) =>
        set((s) => (s.contacts[id] ? { contacts: { ...s.contacts, [id]: { ...s.contacts[id], ...patch } } } : s)),

      removeContact: (id) =>
        set((s) => {
          const next = { ...s.contacts };
          delete next[id];
          return { contacts: next, screen: 'orbit', currentId: null };
        }),

      // Add many people at once from the iPhone address book. Places them on the
      // inner rings with spread-out angles so they start close, then drift over
      // time like everyone else. Returns how many were actually added.
      importContacts: (people) => {
        const current = Object.values(get().contacts);
        const next = { ...get().contacts };
        // Skip anyone already in the orbit — and collapse duplicates within this
        // same batch — matching on phone (strong) or normalized name (fallback).
        const seenPhones = new Set(current.map((c) => phoneKey(c.phone)).filter(Boolean));
        const seenNames = new Set(current.map((c) => nameKey(c.name)));
        let added = 0;
        let skipped = 0;
        for (const p of people) {
          const name = p.name.trim();
          if (!name) continue;
          const pk = phoneKey(p.phone);
          const nk = nameKey(name);
          if ((pk && seenPhones.has(pk)) || seenNames.has(nk)) {
            skipped++;
            continue;
          }
          if (pk) seenPhones.add(pk);
          seenNames.add(nk);
          const id = 'c' + Date.now() + '_' + addCounter;
          const angle = ((addCounter++) * 87 + 30) % 360 - 180;
          const ring = (added % 2) + 1;
          next[id] = {
            id, name, initials: initialsOf(name), grad: 'g-' + (name.length % 5),
            role: 'From Contacts', unit: 'just now',
            ring, angle, drift: driftOf(ring), photo: p.photo ?? null, phone: p.phone ?? null, group: 'Friends',
            lastContactAt: backdateFor(ring),
          };
          added++;
        }
        set({ contacts: next });
        return { added, skipped };
      },

      // Load the demo people so a first-time user can see how Orbit feels.
      loadSampleOrbit: () => set({ contacts: seedMap() }),
      // Wipe the orbit back to empty (used by "Start over" in Settings).
      resetOrbit: () => set({ contacts: {}, screen: 'orbit', currentId: null }),

      pull: (id) =>
        set((s) => {
          const c = s.contacts[id];
          if (!c) return s;
          // Reconnecting brings someone back to the center and resets their clock.
          return { contacts: { ...s.contacts, [id]: { ...c, ring: 1, unit: 'just now', drift: false, lastContactAt: Date.now() } }, heartPing: nextHeart() };
        }),

      moveOrbit: (id, ring) =>
        set((s) => {
          const c = s.contacts[id];
          if (!c) return s;
          return { contacts: { ...s.contacts, [id]: { ...c, ring, unit: 'moved just now', drift: driftOf(ring, c.anchored), lastContactAt: backdateFor(ring) } } };
        }),

      toggleFav: (id) =>
        set((s) => (s.contacts[id] ? { contacts: { ...s.contacts, [id]: { ...s.contacts[id], fav: !s.contacts[id].fav } } } : s)),

      toggleAnchor: (id) =>
        set((s) => {
          const c = s.contacts[id];
          if (!c) return s;
          const anchored = !c.anchored;
          return { contacts: { ...s.contacts, [id]: { ...c, anchored, drift: anchored ? false : driftOf(c.ring) } } };
        }),

      toggleSnooze: (id) =>
        set((s) => (s.contacts[id] ? { contacts: { ...s.contacts, [id]: { ...s.contacts[id], snoozed: !s.contacts[id].snoozed } } } : s)),

      setSpeed: (id, speed) => get().updateContact(id, { speed }),
      setNote: (id, note) => get().updateContact(id, { note }),
      setGroup: (id, group) => get().updateContact(id, { group }),
      setReminder: (id, reminder) => get().updateContact(id, { reminder }),
      setPhone: (id, phone) => get().updateContact(id, { phone }),

      // Recompute everyone's ring from real elapsed time since last contact.
      // Called on launch and when the app returns to the foreground — so drift
      // reflects days passing, not a fast in-session timer. Anchored people and
      // any without a timestamp (e.g. the sample orbit) are left untouched.
      settleDrift: () =>
        set((s) => {
          let changed = false;
          const next = { ...s.contacts };
          for (const c of Object.values(s.contacts)) {
            if (c.lastContactAt == null || c.anchored) continue;
            const ring = ringFromElapsed(c.lastContactAt);
            const drift = ring >= 3;
            if (ring !== c.ring || drift !== c.drift) {
              next[c.id] = { ...c, ring, drift };
              changed = true;
            }
          }
          return changed ? { contacts: next } : s;
        }),
    }),
    {
      name: 'orbit-store',
      version: 2,
      // Older builds stored theme 'light'; it's now the 'coral' colorway.
      migrate: (persisted: any) => {
        if (persisted && persisted.theme === 'light') persisted.theme = 'coral';
        return persisted;
      },
      storage: createJSONStorage(() => fileStorage),
      // Only durable data is written to disk — not ephemeral UI (screen, sheets,
      // toast, filter). Actions are recreated from the initializer on each launch.
      partialize: (s) => ({ contacts: s.contacts, theme: s.theme, onboarded: s.onboarded, mePhoto: s.mePhoto }),
      onRehydrateStorage: () => () => {
        useStore.setState({ hydrated: true });
      },
    },
  ),
);

// Selectors / derived helpers
export const contactList = (s: State): Contact[] => Object.values(s.contacts);

export const pickNudgeId = (contacts: Record<string, Contact>): string | null => {
  const drifters = Object.values(contacts).filter((c) => c.drift && !c.snoozed);
  if (!drifters.length) return null;
  drifters.sort((a, b) => b.ring - a.ring);
  return drifters[0].id;
};
