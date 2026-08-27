import * as FileSystem from 'expo-file-system';
import type { StateStorage } from 'zustand/middleware';

// A zustand `persist` storage backed by a JSON file in the app's document
// directory. We use expo-file-system (already a dependency) instead of adding
// @react-native-async-storage — no extra native module, no version-skew risk.
// The whole persisted store lives in one file; the `name` arg is ignored.
//
// Writes are atomic. `writeAsStringAsync` truncates in place, so a process kill
// part-way through leaves a half-written file — which then fails to parse and
// the app boots as if freshly installed, losing the user's whole orbit. Instead
// we write a temp file, rotate the previous good copy to .bak, then move temp
// into place; a read falls back to .bak if the main file is missing or corrupt.
const dir = FileSystem.documentDirectory ?? FileSystem.cacheDirectory ?? null;
const FILE = dir ? dir + 'orbit-store-v1.json' : null;
const TMP = FILE ? FILE + '.tmp' : null;
const BAK = FILE ? FILE + '.bak' : null;

/** Last failure, if any — surfaced so a silent data-loss bug is diagnosable. */
export let lastPersistError: string | null = null;
const note = (what: string, e: unknown) => {
  lastPersistError = `${what}: ${e instanceof Error ? e.message : String(e)}`;
  console.warn(`[orbit/persist] ${lastPersistError}`);
};

/** Read a file only if it exists and holds parseable JSON. */
async function readValid(uri: string): Promise<string | null> {
  try {
    const info = await FileSystem.getInfoAsync(uri);
    if (!info.exists || info.size === 0) return null;
    const raw = await FileSystem.readAsStringAsync(uri);
    JSON.parse(raw); // guard: a truncated file must not reach zustand
    return raw;
  } catch {
    return null; // caller decides whether to try the backup
  }
}

export const fileStorage: StateStorage = {
  getItem: async (): Promise<string | null> => {
    if (!FILE || !BAK) {
      note('no writable directory', 'documentDirectory and cacheDirectory are both unavailable');
      return null;
    }
    const main = await readValid(FILE);
    if (main !== null) return main;
    // Main file missing or corrupt — fall back to the last good copy rather
    // than silently starting over.
    const backup = await readValid(BAK);
    if (backup !== null) {
      note('recovered from backup', 'primary store file was missing or unreadable');
      return backup;
    }
    return null;
  },

  setItem: async (_name: string, value: string): Promise<void> => {
    if (!FILE || !TMP || !BAK) return;
    try {
      // 1. stage the new content
      await FileSystem.writeAsStringAsync(TMP, value);
      // 2. rotate the current good copy out of the way
      const cur = await FileSystem.getInfoAsync(FILE);
      if (cur.exists) {
        await FileSystem.deleteAsync(BAK, { idempotent: true });
        await FileSystem.moveAsync({ from: FILE, to: BAK });
      }
      // 3. swap the staged file in
      await FileSystem.moveAsync({ from: TMP, to: FILE });
      lastPersistError = null;
    } catch (e) {
      note('write failed', e);
      // Leave whatever is on disk alone — a stale-but-valid orbit beats none.
    }
  },

  removeItem: async (): Promise<void> => {
    if (!FILE || !TMP || !BAK) return;
    try {
      await Promise.all([
        FileSystem.deleteAsync(FILE, { idempotent: true }),
        FileSystem.deleteAsync(TMP, { idempotent: true }),
        FileSystem.deleteAsync(BAK, { idempotent: true }),
      ]);
    } catch (e) {
      note('delete failed', e);
    }
  },
};
