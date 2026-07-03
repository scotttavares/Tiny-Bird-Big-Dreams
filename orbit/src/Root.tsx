import React from 'react';
import { View, Text, Pressable, ScrollView, StyleSheet } from 'react-native';
import * as FileSystem from 'expo-file-system';
import ErrorBoundary from './ui/ErrorBoundary';

// ⚠️ TEMPORARY self-diagnosing entry ⚠️
// The iOS 26 launch crash is a native exception thrown during TurboModule
// setup — it bypasses JavaScript, so JS try/catch can't see it. A patched
// std::terminate handler in React Native (patches/react-native+0.76.5.patch)
// now records that exception's class + reason + stack to this file the instant
// it fires. So:
//   • First launch  → no file yet → we mount the real app, which reproduces the
//     crash; the native handler writes the file; the app dies (white flash).
//   • Second launch → the file exists → we show it (never mounting the app), so
//     the exact cause is on screen to screenshot.
// Once the culprit is fixed, this file goes back to just rendering the app.

const CRASH_FILE = (FileSystem.documentDirectory ?? '') + 'orbit_last_crash.txt';

declare const require: (path: string) => { default: React.ComponentType };

function FatalScreen({ error }: { error: unknown }) {
  const e =
    error instanceof Error ? error : new Error(String((error as { message?: string })?.message ?? error));
  return (
    <View style={styles.wrap}>
      <Text style={styles.title}>Orbit couldn't start (JavaScript)</Text>
      <Text style={styles.hint}>Screenshot this and send it — it names the exact problem.</Text>
      <ScrollView style={styles.box} contentContainerStyle={{ padding: 12 }}>
        <Text selectable style={styles.mono}>
          {e.name}: {e.message}
          {'\n\n'}
          {e.stack}
        </Text>
      </ScrollView>
    </View>
  );
}

/** Renders the real app (this is what reproduces the native crash on iOS 26). */
function RealApp() {
  let App: React.ComponentType | null = null;
  let loadError: unknown = null;
  try {
    App = require('../App').default;
  } catch (e) {
    loadError = e;
  }
  if (!App) return <FatalScreen error={loadError} />;
  return (
    <ErrorBoundary>
      <App />
    </ErrorBoundary>
  );
}

type Phase =
  | { kind: 'checking' }
  | { kind: 'captured'; text: string }
  | { kind: 'run' };

export default function Root() {
  const [phase, setPhase] = React.useState<Phase>({ kind: 'checking' });

  React.useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const info = await FileSystem.getInfoAsync(CRASH_FILE);
        if (info.exists) {
          const text = await FileSystem.readAsStringAsync(CRASH_FILE);
          if (alive && text.trim().length > 0) {
            setPhase({ kind: 'captured', text });
            return;
          }
        }
      } catch {
        // fall through to running the app
      }
      if (alive) setPhase({ kind: 'run' });
    })();
    return () => {
      alive = false;
    };
  }, []);

  if (phase.kind === 'checking') {
    return (
      <View style={[styles.wrap, styles.center]}>
        <Text style={styles.title}>Orbit</Text>
        <Text style={styles.sub}>Checking for a captured crash…</Text>
      </View>
    );
  }

  if (phase.kind === 'captured') {
    return (
      <View style={styles.wrap}>
        <Text style={styles.title}>💥 Crash captured</Text>
        <Text style={styles.hint}>
          Screenshot this whole screen and send it — it names the exact library and reason.
        </Text>
        <ScrollView style={styles.box} contentContainerStyle={{ padding: 12 }}>
          <Text selectable style={styles.mono}>
            {phase.text}
          </Text>
        </ScrollView>
        <Pressable
          style={styles.btn}
          onPress={async () => {
            try {
              await FileSystem.deleteAsync(CRASH_FILE, { idempotent: true });
            } catch {
              // ignore
            }
            setPhase({ kind: 'run' });
          }}
        >
          <Text style={styles.btnText}>Clear & reproduce again</Text>
        </Pressable>
      </View>
    );
  }

  return <RealApp />;
}

const styles = StyleSheet.create({
  wrap: { flex: 1, backgroundColor: '#0A0C16', paddingHorizontal: 22, paddingTop: 70 },
  center: { alignItems: 'center', justifyContent: 'center' },
  title: { color: '#EDEFF7', fontSize: 22, fontWeight: '800', marginBottom: 8 },
  sub: { color: '#949ab2', fontSize: 14 },
  hint: { color: '#E8A24A', fontSize: 13, marginBottom: 14, lineHeight: 19 },
  box: {
    maxHeight: 470,
    backgroundColor: '#141826',
    borderRadius: 14,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.11)',
    marginBottom: 14,
  },
  mono: { color: '#c7ccdd', fontSize: 11.5, fontFamily: 'Courier', lineHeight: 16 },
  btn: {
    backgroundColor: '#141826',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.14)',
    paddingVertical: 14,
    alignItems: 'center',
  },
  btnText: { color: '#EDEFF7', fontSize: 15, fontWeight: '600' },
});
