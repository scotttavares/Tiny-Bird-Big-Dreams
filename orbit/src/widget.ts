// Bridge between the app's live orbit data and the native home-screen widget.
// We write a compact JSON snapshot into the shared App Group container via
// ExtensionStorage; the WidgetKit extension (targets/widget/index.swift) reads
// the same key and renders it. reloadWidget() nudges the OS to refresh.
import { ExtensionStorage } from '@bacons/apple-targets';
import type { Contact } from './types';
import type { Theme } from './theme';
import { GROUP_COLOR } from './orbit';

// Must match the App Group in app.json (ios.entitlements) and the suiteName the
// Swift widget reads from.
export const APP_GROUP = 'group.com.tinybirdbigdreams.orbit';
const KEY = 'orbit';
const MAX_PEOPLE = 8;

const storage = new ExtensionStorage(APP_GROUP);

export interface WidgetPerson {
  name: string;      // first name
  initials: string;
  ring: number;      // 1 = closest; larger = farther out
  angle: number;     // position around the ring, degrees (for the orbit widget)
  color: string;     // group color hex
  drift: boolean;
}
// The colors the widget needs to match the app's current theme. Mirrors
// WidgetTheme in targets/widget/index.swift.
export interface WidgetTheme {
  bg: string;        // widget background
  text: string;      // primary text (light on dark themes, dark on light ones)
  accent: string;    // logo mark / primary accent
  drift: string;     // "drifting away" highlight
  you0: string;      // "You" core gradient, start
  you1: string;      // "You" core gradient, end
}
export interface WidgetPayload {
  updatedAt: number;
  driftCount: number;
  total: number;      // everyone in the orbit (people[] is capped for drawing)
  people: WidgetPerson[];
  theme: WidgetTheme; // so the home-screen widget matches the color style in use
}

const widgetThemeOf = (t: Theme): WidgetTheme => ({
  bg: t.bg, text: t.text, accent: t.accent, drift: t.drift, you0: t.youGrad[0], you1: t.youGrad[1],
});

/** Drifters first (farthest out), then the nearest people, capped for a widget. */
export function buildWidgetPayload(contacts: Contact[], now: number, theme: Theme): WidgetPayload {
  const drifters = contacts.filter((c) => c.drift && !c.snoozed).sort((a, b) => b.ring - a.ring);
  const rest = contacts
    .filter((c) => !(c.drift && !c.snoozed))
    .sort((a, b) => a.ring - b.ring);
  const ordered = [...drifters, ...rest].slice(0, MAX_PEOPLE);
  return {
    updatedAt: now,
    driftCount: drifters.length,
    total: contacts.length,
    people: ordered.map((c) => ({
      name: c.name.trim().split(/\s+/)[0],
      initials: c.initials,
      ring: c.ring,
      angle: c.angle,
      color: GROUP_COLOR[c.group],
      drift: c.drift && !c.snoozed,
    })),
    theme: widgetThemeOf(theme),
  };
}

/** Push the current orbit into the shared container and refresh the widget. */
export function syncWidget(contacts: Contact[], now: number, theme: Theme): void {
  try {
    storage.set(KEY, JSON.stringify(buildWidgetPayload(contacts, now, theme)));
    ExtensionStorage.reloadWidget();
  } catch {
    // No-op on Android / in Expo Go where the native App Group module is absent.
  }
}
