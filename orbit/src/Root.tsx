import React from 'react';
import { View, Text, StyleSheet } from 'react-native';

// ⚠️ TEMPORARY DIAGNOSTIC BUILD ⚠️
// Renders a bare screen WITHOUT importing the app (so Reanimated, the screens,
// and expo-linear-gradient are not pulled into the bundle or initialized). This
// isolates the launch crash:
//   • If this screen appears  → React Native core + native pods start fine, and
//     the crash is in the app's animation/UI layer (Reanimated is the suspect).
//   • If it still white-screens and quits → the crash is lower: RN core, Hermes,
//     or a native module's startup — a build-config problem, not app code.
// The real app (App.tsx) is untouched; this just swaps what gets rendered.
export default function Root() {
  return (
    <View style={styles.wrap}>
      <Text style={styles.title}>Orbit core loaded ✓</Text>
      <Text style={styles.sub}>
        Diagnostic build. If you can read this, the app's foundation is healthy — the crash is in
        the animation layer, and the fix is close. Send Claude a screenshot.
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { flex: 1, backgroundColor: '#0A0C16', alignItems: 'center', justifyContent: 'center', paddingHorizontal: 34 },
  title: { color: '#EDEFF7', fontSize: 24, fontWeight: '800', marginBottom: 14, textAlign: 'center' },
  sub: { color: '#949ab2', fontSize: 14, textAlign: 'center', lineHeight: 21 },
});
