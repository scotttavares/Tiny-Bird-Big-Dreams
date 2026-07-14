import * as FileSystem from 'expo-file-system';
import type { StateStorage } from 'zustand/middleware';

// A zustand `persist` storage backed by a single JSON file in the app's
// document directory. We use expo-file-system (already a dependency) instead of
// adding @react-native-async-storage — no extra native module, no version-skew
// risk. The whole persisted store lives in one file; the `name` arg is ignored.
const dir = FileSystem.documentDirectory ?? FileSystem.cacheDirectory ?? '';
const FILE = dir + 'orbit-store-v1.json';

export const fileStorage: StateStorage = {
  getItem: async (): Promise<string | null> => {
    try {
      const info = await FileSystem.getInfoAsync(FILE);
      if (!info.exists) return null;
      return await FileSystem.readAsStringAsync(FILE);
    } catch {
      return null;
    }
  },
  setItem: async (_name: string, value: string): Promise<void> => {
    try {
      await FileSystem.writeAsStringAsync(FILE, value);
    } catch {
      // best-effort; a failed write just means this change isn't persisted
    }
  },
  removeItem: async (): Promise<void> => {
    try {
      await FileSystem.deleteAsync(FILE, { idempotent: true });
    } catch {
      // ignore
    }
  },
};
