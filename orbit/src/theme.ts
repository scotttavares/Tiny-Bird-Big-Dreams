// Palettes: one dark "night sky" plus four light colorways that mirror the
// Orbit website themes (coral / gold / green / blue).
export type ThemeName = 'dark' | 'coral' | 'gold' | 'green' | 'blue';

export interface Theme {
  name: ThemeName;
  dark: boolean;                 // true for the night sky, false for the light colorways
  accent: string;
  accent2: string;
  accentSoft: string;
  drift: string;
  danger: string;
  bg: string;
  bg2: string;
  card: string;
  card2: string;
  text: string;
  dim: string;
  faint: string;
  border: string;
  border2: string;
  ring: string;
  ringFaint: string;
  tabInactive: string;
  youGrad: [string, string];     // gradient for the "You" core
}

export const THEMES: Record<ThemeName, Theme> = {
  dark: {
    name: 'dark', dark: true,
    accent: '#7b6ef6', accent2: '#6C5CE7', accentSoft: 'rgba(123,110,246,0.16)',
    drift: '#E8A24A', danger: '#F2585E',
    bg: '#0A0C16', bg2: '#0e1120', card: '#141826', card2: '#1a1f31',
    text: '#EDEFF7', dim: '#949ab2', faint: '#5b6178',
    border: 'rgba(255,255,255,0.07)', border2: 'rgba(255,255,255,0.11)',
    ring: 'rgba(123,110,246,0.24)', ringFaint: 'rgba(140,150,200,0.10)',
    tabInactive: '#5b6178',
    youGrad: ['#9a8cff', '#6C5CE7'],
  },
  coral: {
    name: 'coral', dark: false,
    accent: '#EF6A4D', accent2: '#E14E30', accentSoft: 'rgba(239,106,77,0.14)',
    drift: '#E8952A', danger: '#E5484D',
    bg: '#FFF8F2', bg2: '#FCEDE2', card: '#FFFFFF', card2: '#FFF3EA',
    text: '#2C201B', dim: '#6E5C53', faint: '#A08D83',
    border: 'rgba(44,32,27,0.09)', border2: 'rgba(44,32,27,0.14)',
    ring: 'rgba(239,106,77,0.40)', ringFaint: 'rgba(44,32,27,0.10)',
    tabInactive: '#B7A79E',
    youGrad: ['#FF8A5B', '#F0654E'],
  },
  gold: {
    name: 'gold', dark: false,
    accent: '#E8971C', accent2: '#C67D0C', accentSoft: 'rgba(232,151,28,0.14)',
    drift: '#E07016', danger: '#E5484D',
    bg: '#FFFCF3', bg2: '#FBF2DA', card: '#FFFFFF', card2: '#FFF8E8',
    text: '#2E2612', dim: '#6E6142', faint: '#AB9C78',
    border: 'rgba(46,38,18,0.09)', border2: 'rgba(46,38,18,0.14)',
    ring: 'rgba(232,151,28,0.42)', ringFaint: 'rgba(46,38,18,0.10)',
    tabInactive: '#BCAE8A',
    youGrad: ['#F7A81A', '#E4761C'],
  },
  green: {
    name: 'green', dark: false,
    accent: '#4E9E5E', accent2: '#3A8A4A', accentSoft: 'rgba(78,158,94,0.14)',
    drift: '#E8952A', danger: '#E5484D',
    bg: '#F5FAF3', bg2: '#E7F2E2', card: '#FFFFFF', card2: '#EFF7EC',
    text: '#1F2A1E', dim: '#566B51', faint: '#8CA085',
    border: 'rgba(31,42,30,0.09)', border2: 'rgba(31,42,30,0.14)',
    ring: 'rgba(78,158,94,0.42)', ringFaint: 'rgba(31,42,30,0.10)',
    tabInactive: '#9BB093',
    youGrad: ['#6BC079', '#3A8A4A'],
  },
  blue: {
    name: 'blue', dark: false,
    accent: '#3E8FD6', accent2: '#2C77C0', accentSoft: 'rgba(62,143,214,0.14)',
    drift: '#E8952A', danger: '#E5484D',
    bg: '#F4F9FE', bg2: '#E4F0FB', card: '#FFFFFF', card2: '#EEF6FD',
    text: '#1C2632', dim: '#526172', faint: '#8399AD',
    border: 'rgba(28,38,50,0.09)', border2: 'rgba(28,38,50,0.14)',
    ring: 'rgba(62,143,214,0.42)', ringFaint: 'rgba(28,38,50,0.10)',
    tabInactive: '#94A6B8',
    youGrad: ['#5AAAE8', '#2C77C0'],
  },
};

// Order + preview swatch for the theme picker in Settings.
export const THEME_OPTIONS: { name: ThemeName; label: string; swatch: [string, string] }[] = [
  { name: 'dark', label: 'Dark', swatch: ['#3a3f63', '#0A0C16'] },
  { name: 'coral', label: 'Coral', swatch: ['#FF8A5B', '#F0654E'] },
  { name: 'gold', label: 'Gold', swatch: ['#F7A81A', '#E4761C'] },
  { name: 'green', label: 'Green', swatch: ['#6BC079', '#3A8A4A'] },
  { name: 'blue', label: 'Blue', swatch: ['#5AAAE8', '#2C77C0'] },
];

// Avatar gradients keyed like the prototype's g-* classes.
export const GRAD: Record<string, [string, string]> = {
  'g-david': ['#5b8cff', '#3f6fd6'],
  'g-mom': ['#ff8fb1', '#ef5f80'],
  'g-sarah': ['#ffc36b', '#f1973f'],
  'g-jess': ['#7be0c0', '#36b08f'],
  'g-leo': ['#c08bff', '#9a5bf0'],
  'g-0': ['#5b8cff', '#3f6fd6'],
  'g-1': ['#ff8fb1', '#ef5f80'],
  'g-2': ['#ffc36b', '#f1973f'],
  'g-3': ['#7be0c0', '#36b08f'],
  'g-4': ['#c08bff', '#9a5bf0'],
};

export const gradOf = (key: string): [string, string] => GRAD[key] ?? ['#6b7280', '#4b5563'];

// Default "You" gradient (kept for reference); screens now read theme.youGrad.
export const YOU_GRAD: [string, string] = ['#9a8cff', '#6C5CE7'];
