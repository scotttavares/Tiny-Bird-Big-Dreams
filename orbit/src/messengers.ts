import { Linking } from 'react-native';

// A cleaned phone number in the two shapes different apps expect:
//   raw    — digits plus + * # (what sms:/tel: want)
//   digits — digits only, no punctuation, for apps that take ?phone=<intl number>
export type CleanNum = { raw: string; digits: string };

export function cleanNumber(phone?: string | null): CleanNum | null {
  if (!phone) return null;
  const raw = phone.replace(/[^\d+*#]/g, '');
  const digits = phone.replace(/[^\d]/g, '');
  if (!digits) return null;
  return { raw, digits };
}

type IconSet = 'ion' | 'fa5'; // Ionicons, or FontAwesome5 brand glyph
type Messenger = {
  key: string;
  label: string;
  tint: string; // brand color for the row's icon tile
  icon: string;
  iconSet: IconSet;
  query?: string; // scheme probed with canOpenURL; omitted = always offered
  build: (n: CleanNum) => string;
};

export type ReadyMessenger = Omit<Messenger, 'build'> & { url: string };

// Popular messengers that can open a conversation from just a phone number.
// Apple Messages is always offered; the rest surface only when the app is
// installed — detected via canOpenURL, which on iOS needs each scheme listed
// under LSApplicationQueriesSchemes in app.json. (Signal has no brand glyph in
// our icon fonts, so it uses a neutral chat bubble.)
const CATALOG: Messenger[] = [
  { key: 'messages', label: 'Messages', tint: '#34C759', icon: 'chatbubble', iconSet: 'ion',
    build: (n) => `sms:${n.raw}` },
  { key: 'whatsapp', label: 'WhatsApp', tint: '#25D366', icon: 'whatsapp', iconSet: 'fa5', query: 'whatsapp://send',
    build: (n) => `whatsapp://send?phone=${n.digits}` },
  { key: 'telegram', label: 'Telegram', tint: '#26A5E4', icon: 'telegram', iconSet: 'fa5', query: 'tg://resolve',
    build: (n) => `tg://resolve?phone=${n.digits}` },
  { key: 'signal', label: 'Signal', tint: '#3A76F0', icon: 'chatbubble-ellipses', iconSet: 'ion', query: 'sgnl://',
    build: (n) => `https://signal.me/#p/+${n.digits}` },
  { key: 'viber', label: 'Viber', tint: '#7360F2', icon: 'viber', iconSet: 'fa5', query: 'viber://',
    build: (n) => `viber://chat?number=%2B${n.digits}` },
];

// Which messengers can actually reach this number right now — Messages plus any
// installed apps — each with its deep link built and ready to open.
export async function availableMessengers(n: CleanNum): Promise<ReadyMessenger[]> {
  const out: ReadyMessenger[] = [];
  for (const m of CATALOG) {
    if (m.query) {
      try {
        if (!(await Linking.canOpenURL(m.query))) continue;
      } catch {
        continue;
      }
    }
    const { build, ...rest } = m;
    out.push({ ...rest, url: build(n) });
  }
  return out;
}
