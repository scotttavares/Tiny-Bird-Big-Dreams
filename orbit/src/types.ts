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
  phone?: string | null;   // for Send a Text / Quick Call (from Contacts or manual)
  group: GroupName;
  fav?: boolean;
  anchored?: boolean;    // exempt from drift
  snoozed?: boolean;     // excluded from nudges
  speed?: Speed;         // per-person drift speed
  note?: string;
  reminder?: string | null;
  lastContactAt?: number; // ms timestamp of last contact; drives real-time drift
  log?: LogEntry[];       // recent interactions, newest first (see RECENT GRAVITY)
}

export interface LogEntry {
  at: number;    // ms timestamp
  label: string; // what the interaction was, e.g. "Met up", "Called"
}
