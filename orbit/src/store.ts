import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import type { Contact, GroupName, Screen, Speed } from './types';
import type { ThemeName } from './theme';
import { SEED } from './data';
import { initialsOf } from './orbit';
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
  sheet: 'add' | 'action' | 'import' | null;

  setScreen: (s: Screen) => void;
  openContact: (id: string) => void;
  openAdd: () => void;
  openActions: () => void;
  openImport: () => void;
  closeSheet: () => void;
  setTheme: (t: ThemeName) => void;
  toggleTheme: () => void;
  setFilter: (g: FilterGroup) => void;
  dismissOnboarding: () => void;
  showToast: (msg: string) => void;

  addContact: (input: { name: string; role?: string; ring: number; group: GroupName }) => void;
  updateContact: (id: string, patch: Partial<Contact>) => void;
  removeContact: (id: string) => void;
  importContacts: (people: { name: string; photo?: string | null }[]) => number;
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
  settleDrift: () => void;
}

const seedMap = (): Record<string, Contact> =>
  Object.fromEntries(SEED.map((c) => [c.id, { ...c }]));

const driftOf = (ring: number, anchored?: boolean) => ring >= 3 && !anchored;

// ── Real-time drift ────────────────────────────────────────────────────────
// Drift reflects how long it's been since you last connected — not a fast
// timer. A person moves out one ring every WEEKS_PER_RING weeks (by their
// per-person speed), and reconnecting pulls them back to the center.
const WEEK_MS = 7 * 24 * 60 * 60 * 1000;
const WEEKS_PER_RING: Record<Speed, number> = { Gentle: 3, Steady: 2, Brisk: 1 };
// Backdate a "last contacted" time so a person shows at `ring` right now.
const backdateFor = (ring: number, speed: Speed = 'Steady') =>
  Date.now() - (ring - 1) * WEEKS_PER_RING[speed] * WEEK_MS;
// Which ring a person belongs on now, given when you last connected.
const ringFromElapsed = (lastContactAt: number, speed: Speed = 'Steady') => {
  const weeks = (Date.now() - lastContactAt) / WEEK_MS;
  return Math.min(6, Math.max(1, 1 + Math.floor(weeks / WEEKS_PER_RING[speed])));
};

let toastTimer: ReturnType<typeof setTimeout> | undefined;
let addCounter = 0;

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

      setScreen: (screen) => set({ screen }),
      openContact: (id) => set({ currentId: id, screen: 'contact', sheet: null }),
      openAdd: () => set({ sheet: 'add' }),
      openActions: () => set({ sheet: 'action' }),
      openImport: () => set({ sheet: 'import' }),
      closeSheet: () => set({ sheet: null }),
      setTheme: (theme) => set({ theme }),
      toggleTheme: () => set((s) => ({ theme: s.theme === 'dark' ? 'light' : 'dark' })),
      setFilter: (activeGroup) => set({ activeGroup }),
      dismissOnboarding: () => set({ onboarded: true }),

      showToast: (toast) => {
        set({ toast });
        if (toastTimer) clearTimeout(toastTimer);
        toastTimer = setTimeout(() => set({ toast: null }), 1900);
      },

      addContact: ({ name, role, ring, group }) => {
        const id = 'c' + Date.now() + '_' + addCounter;
        const angle = ((addCounter++) * 87 + 30) % 360 - 180;
        const grad = 'g-' + (name.length % 5);
        set((s) => ({
          contacts: {
            ...s.contacts,
            [id]: {
              id, name, initials: initialsOf(name), grad,
              role: role?.trim() || 'New connection', unit: 'just now',
              ring, angle, drift: driftOf(ring), photo: null, group,
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
        const next = { ...get().contacts };
        let added = 0;
        for (const p of people) {
          const name = p.name.trim();
          if (!name) continue;
          const id = 'c' + Date.now() + '_' + addCounter;
          const angle = ((addCounter++) * 87 + 30) % 360 - 180;
          const ring = (added % 2) + 1;
          next[id] = {
            id, name, initials: initialsOf(name), grad: 'g-' + (name.length % 5),
            role: 'From Contacts', unit: 'just now',
            ring, angle, drift: driftOf(ring), photo: p.photo ?? null, group: 'Friends',
            lastContactAt: backdateFor(ring),
          };
          added++;
        }
        set({ contacts: next });
        return added;
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
          return { contacts: { ...s.contacts, [id]: { ...c, ring: 1, unit: 'just now', drift: false, lastContactAt: Date.now() } } };
        }),

      moveOrbit: (id, ring) =>
        set((s) => {
          const c = s.contacts[id];
          if (!c) return s;
          return { contacts: { ...s.contacts, [id]: { ...c, ring, unit: 'moved just now', drift: driftOf(ring, c.anchored), lastContactAt: backdateFor(ring, c.speed) } } };
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
            const ring = ringFromElapsed(c.lastContactAt, c.speed);
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
      version: 1,
      storage: createJSONStorage(() => fileStorage),
      // Only durable data is written to disk — not ephemeral UI (screen, sheets,
      // toast, filter). Actions are recreated from the initializer on each launch.
      partialize: (s) => ({ contacts: s.contacts, theme: s.theme, onboarded: s.onboarded }),
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
