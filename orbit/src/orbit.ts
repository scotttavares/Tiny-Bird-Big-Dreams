import type { Contact, GroupName } from './types';

// Ring geometry + revolution speed (ported from the prototype).
export const FIELD = 340;
export const CENTER = FIELD / 2;
// Ring 6 sits much farther out — "beyond the galaxy" — so a year-plus of
// silence reads as a real distance you have to reach across.
export const radius = (n: number) => 42 + (n - 1) * 48 + (n >= 6 ? 60 : 0); // px from centre
export const ringDur = (n: number) => 34 + n * 16;               // seconds per revolution (outer = slower)

// Each ring is a time-since-last-contact bucket.
export const ORBIT_NAME: Record<number, string> = {
  1: 'Within 2 weeks', 2: 'Within a month', 3: 'Within 3 months',
  4: 'Within 6 months', 5: 'Within a year', 6: 'Beyond the galaxy',
};

export const GROUPS: GroupName[] = ['Family', 'Friends', 'Work', 'Other'];
export const GROUP_COLOR: Record<GroupName, string> = {
  Family: '#ef6196', Friends: '#7b6ef6', Work: '#36b08f', Other: '#f1973f',
};

export const PROMPTS = [
  'Who made you smile this week?',
  'Is there someone you keep meaning to call?',
  'Who would love to hear from you out of the blue?',
  'Whose good news did you forget to celebrate?',
  "Who's been on your mind lately?",
];

// Human "time since you last connected", from the real timestamp.
export function sinceLabel(lastContactAt?: number): string {
  if (lastContactAt == null) return '';
  const days = Math.floor((Date.now() - lastContactAt) / (24 * 60 * 60 * 1000));
  if (days <= 0) return 'today';
  if (days === 1) return 'yesterday';
  if (days < 7) return `${days} days`;
  const weeks = Math.floor(days / 7);
  if (days < 30) return weeks === 1 ? '1 week' : `${weeks} weeks`;
  const months = Math.floor(days / 30);
  if (days < 365) return months === 1 ? '1 month' : `${months} months`;
  const years = Math.floor(days / 365);
  return years === 1 ? '1 year' : `${years} years`;
}

export const roleLine = (c: Contact) => {
  const since = c.lastContactAt != null ? sinceLabel(c.lastContactAt) : c.unit;
  return `${c.role} · ${ORBIT_NAME[c.ring] ?? 'Orbit'} (${since})`;
};

export const initialsOf = (name: string) =>
  name.trim().split(/\s+/).map((w) => w[0]).slice(0, 2).join('').toUpperCase();

// ── Duplicate detection ──────────────────────────────────────────────────────
// Used to warn before the same person lands in the orbit twice. Phone is the
// strong signal (last 10 digits, tolerant of country-code formatting); the
// normalized name is the fallback when there's no number to compare.
export const phoneKey = (phone?: string | null): string => {
  const d = (phone ?? '').replace(/\D/g, '');
  return d.length >= 7 ? d.slice(-10) : d;
};
export const nameKey = (name: string): string => name.trim().toLowerCase().replace(/\s+/g, ' ');

/** The existing contact that `person` looks like a duplicate of, or null. */
export function matchExisting(
  contacts: Contact[],
  person: { name: string; phone?: string | null },
): Contact | null {
  const pk = phoneKey(person.phone);
  const nk = nameKey(person.name);
  for (const c of contacts) {
    if (pk && phoneKey(c.phone) === pk) return c;
    if (nk && nameKey(c.name) === nk) return c;
  }
  return null;
}
