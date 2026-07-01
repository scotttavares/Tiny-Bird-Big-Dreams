// Bridge between the app's live orbit data and the native home-screen widget.
// We write a compact JSON snapshot into the shared App Group container via
// ExtensionStorage; the WidgetKit extension (targets/widget/index.swift) reads
// the same key and renders it. reloadWidget() nudges the OS to refresh.
import { ExtensionStorage } from '@bacons/apple-targets';
import type { Contact } from './types';
import { GROUP_COLOR } from './orbit';

// Must match the App Group in app.json (ios.entitlements) and the suiteName the
// Swift widget reads from.
export const APP_GROUP = 'group.com.tinybirdbigdreams.orbit';
const KEY = 'orbit';
const MAX_PEOPLE = 4;

const storage = new ExtensionStorage(APP_GROUP);

export interface WidgetPerson {
  name: string;      // first name
  initials: string;
  ring: number;
  color: string;     // group color hex
  drift: boolean;
}
export interface WidgetPayload {
  updatedAt: number;
  driftCount: number;
  people: WidgetPerson[];
}

/** Drifters first (farthest out), then the nearest people, capped for a widget. */
export function buildWidgetPayload(contacts: Contact[], now: number): WidgetPayload {
  const drifters = contacts.filter((c) => c.drift && !c.snoozed).sort((a, b) => b.ring - a.ring);
  const rest = contacts
    .filter((c) => !(c.drift && !c.snoozed))
    .sort((a, b) => a.ring - b.ring);
  const ordered = [...drifters, ...rest].slice(0, MAX_PEOPLE);
  return {
    updatedAt: now,
    driftCount: drifters.length,
    people: ordered.map((c) => ({
      name: c.name.trim().split(/\s+/)[0],
      initials: c.initials,
      ring: c.ring,
      color: GROUP_COLOR[c.group],
      drift: c.drift && !c.snoozed,
    })),
  };
}

/** Push the current orbit into the shared container and refresh the widget. */
export function syncWidget(contacts: Contact[], now: number): void {
  try {
    storage.set(KEY, JSON.stringify(buildWidgetPayload(contacts, now)));
    ExtensionStorage.reloadWidget();
  } catch {
    // No-op on Android / in Expo Go where the native App Group module is absent.
  }
}
