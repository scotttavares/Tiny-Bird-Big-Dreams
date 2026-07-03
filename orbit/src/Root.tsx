import React from 'react';
import { View, Text, ScrollView, StyleSheet } from 'react-native';
import ErrorBoundary from './ui/ErrorBoundary';

// Root loads the app LAZILY (via require, at render time) so that a crash while
// App — or any module it pulls in (Reanimated, the screens, …) — is being
// evaluated is caught and shown on screen, instead of silently killing the app
// at launch. A render-time ErrorBoundary then catches everything below.
// (Native crashes still bypass JS; but if this is a JavaScript error, it renders.)

declare const require: (path: string) => { default: React.ComponentType };

function FatalScreen({ error }: { error: unknown }) {
  const e =
    error instanceof Error ? error : new Error(String((error as { message?: string })?.message ?? error));
  return (
    <View style={styles.wrap}>
      <Text style={styles.title}>Orbit couldn't start</Text>
      <Text style={styles.hint}>Screenshot this and send it over — it names the exact problem.</Text>
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

export default function Root() {
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

const styles = StyleSheet.create({
  wrap: { flex: 1, backgroundColor: '#0A0C16', paddingHorizontal: 24, paddingTop: 80 },
  title: { color: '#EDEFF7', fontSize: 20, fontWeight: '800', marginBottom: 8 },
  hint: { color: '#E8A24A', fontSize: 13, marginBottom: 16 },
  box: {
    maxHeight: 440,
    backgroundColor: '#141826',
    borderRadius: 14,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.11)',
  },
  mono: { color: '#b9bed0', fontSize: 11.5, fontFamily: 'Courier', lineHeight: 16 },
});
