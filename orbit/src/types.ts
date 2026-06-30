export type GroupName = 'Family' | 'Friends' | 'Work' | 'Other';
export type Speed = 'Gentle' | 'Steady' | 'Brisk';
export type Screen = 'orbit' | 'today' | 'people' | 'contact' | 'settings';

export interface Contact {
  id: string;
  name: string;
  initials: string;
  grad: string;
  role: string;
  unit: string;          // e.g. "90 days" — how long since last contact
  ring: number;          // 1 = inner, grows outward
  angle: number;         // starting angle on the ring, degrees
  drift: boolean;        // drifting outward / overdue
  photo?: string | null;
  group: GroupName;
  fav?: boolean;
  anchored?: boolean;    // exempt from drift
  snoozed?: boolean;     // excluded from nudges
  speed?: Speed;         // per-person drift speed
  note?: string;
  reminder?: string | null;
}
