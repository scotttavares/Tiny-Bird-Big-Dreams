import type { Contact } from './types';

const P = 'https://randomuser.me/api/portraits/';

export const SEED: Contact[] = [
  { id: 'mom',    name: 'Mom',        initials: 'M',  grad: 'g-mom',   role: 'Family',           unit: '7 days',   ring: 1, angle: -122, drift: false, photo: P + 'women/65.jpg', group: 'Family' },
  { id: 'sarah',  name: 'Sarah',      initials: 'S',  grad: 'g-sarah', role: 'Close Friend',     unit: '24 days',  ring: 2, angle: -18,  drift: false, photo: P + 'women/44.jpg', group: 'Friends' },
  { id: 'jess',   name: 'Jess',       initials: 'J',  grad: 'g-jess',  role: 'Coworker',         unit: '58 days',  ring: 2, angle: 46,   drift: true,  photo: P + 'women/68.jpg', group: 'Work' },
  { id: 'david',  name: 'David Chen', initials: 'DC', grad: 'g-david', role: 'College Roommate', unit: '90 days',  ring: 3, angle: 104,  drift: true,  photo: P + 'men/32.jpg',   group: 'Friends' },
  { id: 'leo',    name: 'Leo',        initials: 'L',  grad: 'g-leo',   role: 'Old Friend',       unit: '75 days',  ring: 3, angle: -150, drift: true,  photo: P + 'men/75.jpg',   group: 'Friends' },
  { id: 'priya',  name: 'Priya',      initials: 'P',  grad: 'g-1',     role: 'Friend',           unit: '15 days',  ring: 2, angle: 128,  drift: false, photo: P + 'women/12.jpg', group: 'Friends' },
  { id: 'marcus', name: 'Marcus',     initials: 'Ma', grad: 'g-4',     role: 'Mentor',           unit: '110 days', ring: 4, angle: 24,   drift: true,  photo: P + 'men/41.jpg',   group: 'Work' },
  { id: 'nina',   name: 'Nina',       initials: 'N',  grad: 'g-2',     role: 'Cousin',           unit: '130 days', ring: 4, angle: 205,  drift: true,  photo: P + 'women/22.jpg', group: 'Family' },
];
