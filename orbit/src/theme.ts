// Dark / light palettes — ported from the prototype's CSS custom properties.
export type ThemeName = 'dark' | 'light';

export interface Theme {
  name: ThemeName;
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
}

export const THEMES: Record<ThemeName, Theme> = {
  dark: {
    name: 'dark',
    accent: '#7b6ef6', accent2: '#6C5CE7', accentSoft: 'rgba(123,110,246,0.16)',
    drift: '#E8A24A', danger: '#F2585E',
    bg: '#0A0C16', bg2: '#0e1120', card: '#141826', card2: '#1a1f31',
    text: '#EDEFF7', dim: '#949ab2', faint: '#5b6178',
    border: 'rgba(255,255,255,0.07)', border2: 'rgba(255,255,255,0.11)',
    ring: 'rgba(123,110,246,0.24)', ringFaint: 'rgba(140,150,200,0.10)',
    tabInactive: '#5b6178',
  },
  light: {
    name: 'light',
    accent: '#7b6ef6', accent2: '#6C5CE7', accentSoft: 'rgba(123,110,246,0.16)',
    drift: '#E8A24A', danger: '#F2585E',
    bg: '#F4F5FA', bg2: '#eceef6', card: '#FFFFFF', card2: '#F4F5FA',
    text: '#171B2C', dim: '#6A7088', faint: '#9aa0b6',
    border: 'rgba(20,24,46,0.08)', border2: 'rgba(20,24,46,0.12)',
    ring: 'rgba(99,84,231,0.50)', ringFaint: 'rgba(99,84,231,0.30)',
    tabInactive: '#aab0c4',
  },
};

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

export const YOU_GRAD: [string, string] = ['#9a8cff', '#6C5CE7'];
