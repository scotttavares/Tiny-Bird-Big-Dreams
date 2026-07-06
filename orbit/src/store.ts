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
  sheet: 'add' | 'action' | null;

  setScreen: (s: Screen) => void;
  openContact: (id: string) => void;
  openAdd: () => void;
  openActions: () => void;
  closeSheet: () => void;
  setTheme: (t: ThemeName) => void;
  toggleTheme: () => void;
  setFilter: (g: FilterGroup) => void;
  dismissOnboarding: () => void;
  showToast: (msg: string) => void;

  addContact: (input: { name: string; role?: string; ring: number; group: GroupName }) => void;
  updateContact: (id: string, patch: Partial<Contact>) => void;
  removeContact: (id: string) => void;
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
  driftTick: () => void;
}

const seedMap = (): Record<string, Contact> =>
  Object.fromEntries(SEED.map((c) => [c.id, { ...c }]));

const driftOf = (ring: number, anchored?: boolean) => ring >= 3 && !anchored;

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

      // Load the demo people so a first-time user can see how Orbit feels.
      loadSampleOrbit: () => set({ contacts: seedMap() }),
      // Wipe the orbit back to empty (used by "Start over" in Settings).
      resetOrbit: () => set({ contacts: {}, screen: 'orbit', currentId: null }),

      pull: (id) =>
        set((s) => {
          const c = s.contacts[id];
          if (!c) return s;
          const ring = Math.max(1, c.ring - 1);
          return { contacts: { ...s.contacts, [id]: { ...c, ring, unit: 'just now', drift: driftOf(ring, c.anchored) } } };
        }),

      moveOrbit: (id, ring) =>
        set((s) => {
          const c = s.contacts[id];
          if (!c) return s;
          return { contacts: { ...s.contacts, [id]: { ...c, ring, unit: 'moved just now', drift: driftOf(ring, c.anchored) } } };
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

      driftTick: () =>
        set((s) => {
          // weight by per-person drift speed: Brisk drifts ~3x, Gentle ~1x
          const weighted: string[] = [];
          for (const c of Object.values(s.contacts)) {
            if (c.ring < 5 && !c.anchored) {
              const w = c.speed === 'Brisk' ? 3 : c.speed === 'Gentle' ? 1 : 2;
              for (let k = 0; k < w; k++) weighted.push(c.id);
            }
          }
          if (!weighted.length) return s;
          const id = weighted[Math.floor(Math.random() * weighted.length)];
          const c = s.contacts[id];
          const ring = c.ring + 1;
          return { contacts: { ...s.contacts, [id]: { ...c, ring, drift: driftOf(ring, c.anchored) } } };
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
