import React from 'react';
import { Text, StyleSheet } from 'react-native';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import { LinearGradient } from 'expo-linear-gradient';
import { Ionicons } from '@expo/vector-icons';

// ⚠️ TEMPORARY DIAGNOSTIC #3 ⚠️
// Reanimated is confirmed healthy. This renders the app's native "shell" — the
// four remaining native libraries — with no screens/store:
//   gesture-handler (GestureHandlerRootView), safe-area-context (SafeAreaProvider),
//   expo-linear-gradient, @expo/vector-icons.
//   • "Shell OK ✓" appears → all four are fine; the crash is app-level code
//     (a screen / the store / notifications-widget module load) which I can read
//     and fix directly.
//   • White flash / crash → one of these four native libs is the culprit, and I
//     bisect that small set.
export default function Root() {
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
        <SafeAreaView style={styles.wrap} edges={['top', 'bottom']}>
          <StatusBar style="light" />
          <LinearGradient colors={['#20264a', '#0A0C16']} style={StyleSheet.absoluteFill} />
          <Ionicons name="planet-outline" size={46} color="#7b6ef6" />
          <Text style={styles.title}>Shell OK ✓</Text>
          <Text style={styles.sub}>gesture-handler · safe-area · gradient · icons all loaded.</Text>
        </SafeAreaView>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}

const styles = StyleSheet.create({
  wrap: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: '#0A0C16', paddingHorizontal: 34, gap: 14 },
  title: { color: '#EDEFF7', fontSize: 24, fontWeight: '800', textAlign: 'center' },
  sub: { color: '#949ab2', fontSize: 13, textAlign: 'center' },
});
