import type { Contact, GroupName } from './types';

// Ring geometry + revolution speed (ported from the prototype).
export const FIELD = 340;
export const CENTER = FIELD / 2;
export const radius = (n: number) => 42 + (n - 1) * 48;          // px from centre
export const ringDur = (n: number) => 34 + n * 16;               // seconds per revolution (outer = slower)

export const ORBIT_NAME: Record<number, string> = {
  1: 'Inner orbit', 2: 'Mid orbit', 3: 'Outer orbit',
  4: 'Distant orbit', 5: 'Far orbit', 6: 'Fringe orbit',
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
