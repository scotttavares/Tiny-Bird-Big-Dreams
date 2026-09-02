import * as FileSystem from 'expo-file-system';
import * as Sharing from 'expo-sharing';
import * as DocumentPicker from 'expo-document-picker';
import type { Contact } from './types';
import type { ThemeName } from './theme';

// A self-contained backup of the whole orbit: everyone you track, their history,
// your appearance, and your center photo — written to one JSON file you can save
// to Files / iCloud Drive, AirDrop, or email to yourself. No account, no server;
// this is the manual, private way to move your orbit to a new phone or to survive
// deleting and reinstalling the app.
const BACKUP_TYPE = 'orbit-backup';
const BACKUP_VERSION = 1;

export interface RestorePayload {
  contacts: Record<string, Contact>;
  theme?: ThemeName;
  onboarded?: boolean;
  mePhoto?: string | null;
}

const docDir = () => FileSystem.documentDirectory ?? FileSystem.cacheDirectory ?? '';
const safe = (s: string) => s.replace(/[^a-zA-Z0-9_-]/g, '') || 'x';

// A local file/asset URI → an embedded data URI, so photos travel *inside* the
// backup (the original files don't exist on a new phone). Best-effort: remote
// URLs are kept as references, and anything unreadable falls back to initials.
async function embed(uri?: string | null): Promise<string | null> {
  if (!uri) return null;
  if (uri.startsWith('data:')) return uri;
  if (/^https?:/i.test(uri)) return uri;
  try {
    const b64 = await FileSystem.readAsStringAsync(uri, { encoding: FileSystem.EncodingType.Base64 });
    return `data:image/jpeg;base64,${b64}`;
  } catch {
    return null;
  }
}

// An embedded data URI → a real file on this device. Restoring to files (instead
// of keeping big data URIs in state) keeps the live store small, so the frequent
// saves on every check-in stay fast.
async function rehydrate(uri: string | null | undefined, name: string): Promise<string | null> {
  if (!uri) return null;
  if (!uri.startsWith('data:')) return uri; // already a normal URI (or remote) — leave it
  const m = /^data:[^;]+;base64,(.*)$/s.exec(uri);
  if (!m) return null;
  try {
    const dest = docDir() + name;
    await FileSystem.writeAsStringAsync(dest, m[1], { encoding: FileSystem.EncodingType.Base64 });
    return dest;
  } catch {
    return null;
  }
}

// Write a portable backup file and open the share sheet.
export async function exportBackup(state: {
  contacts: Record<string, Contact>; theme: ThemeName; onboarded: boolean; mePhoto: string | null;
}): Promise<'shared' | 'unavailable'> {
  // Embed every photo so the backup works even where the original files are gone.
  const contacts: Record<string, Contact> = {};
  for (const [id, c] of Object.entries(state.contacts)) {
    contacts[id] = { ...c, photo: await embed(c.photo) };
  }
  const mePhoto = await embed(state.mePhoto);

  const payload = {
    app: 'orbit',
    type: BACKUP_TYPE,
    version: BACKUP_VERSION,
    exportedAt: Date.now(),
    count: Object.keys(contacts).length,
    data: { contacts, theme: state.theme, onboarded: state.onboarded, mePhoto },
  };

  const stamp = new Date().toISOString().slice(0, 10);
  const fileUri = `${FileSystem.cacheDirectory ?? docDir()}orbit-backup-${stamp}.json`;
  await FileSystem.writeAsStringAsync(fileUri, JSON.stringify(payload));

  if (!(await Sharing.isAvailableAsync())) return 'unavailable';
  await Sharing.shareAsync(fileUri, {
    mimeType: 'application/json',
    UTI: 'public.json',
    dialogTitle: 'Back up your orbit',
  });
  return 'shared';
}

// Let the user pick a backup file, validate it, and return a ready-to-apply
// payload with photos restored to on-device files. Returns null if they cancel;
// throws with a friendly message if the file isn't an Orbit backup.
export async function importBackup(): Promise<RestorePayload | null> {
  // Allow any file (a JSON saved to iCloud Drive / mail can carry different UTIs,
  // and a strict filter greys valid backups out); we validate the contents below.
  const res = await DocumentPicker.getDocumentAsync({
    type: '*/*',
    copyToCacheDirectory: true,
  });
  if (res.canceled || !res.assets?.[0]) return null;

  const raw = await FileSystem.readAsStringAsync(res.assets[0].uri);
  let parsed: any;
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new Error('That file isn’t a valid Orbit backup.');
  }
  const data = parsed?.data;
  if (parsed?.type !== BACKUP_TYPE || !data || typeof data.contacts !== 'object' || data.contacts === null) {
    throw new Error('That file isn’t an Orbit backup.');
  }

  const contacts: Record<string, Contact> = {};
  for (const [id, raw0] of Object.entries<any>(data.contacts)) {
    const c = raw0 as Contact;
    contacts[id] = { ...c, photo: await rehydrate(c.photo, `orbit-photo-${safe(id)}.jpg`) };
  }
  const mePhoto = await rehydrate(data.mePhoto, `me-restored-${Date.now()}.jpg`);

  return { contacts, theme: data.theme, onboarded: data.onboarded, mePhoto };
}
