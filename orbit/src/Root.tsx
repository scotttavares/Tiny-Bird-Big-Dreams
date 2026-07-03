import React from 'react';
import { View, Text, Pressable, StyleSheet } from 'react-native';

// ⚠️ TEMPORARY DIAGNOSTIC #4 — interactive culprit finder ⚠️
// The shell (all 4 native libs) crashed; Reanimated is cleared. This lets you
// load each of the four remaining libraries ONE AT A TIME by tapping a button.
// Each library is required lazily inside its button, so whichever one aborts the
// app — whether at import or on mount — is pinpointed by which button you tapped.

declare const require: (m: string) => any;

const TESTS: { name: string; render: () => React.ReactNode }[] = [
  {
    name: 'safe-area-context',
    render: () => {
      const { SafeAreaProvider, SafeAreaView } = require('react-native-safe-area-context');
      return (
        <SafeAreaProvider>
          <SafeAreaView style={styles.inner}>
            <Text style={styles.ok}>safe-area OK ✓</Text>
          </SafeAreaView>
        </SafeAreaProvider>
      );
    },
  },
  {
    name: 'gesture-handler',
    render: () => {
      const { GestureHandlerRootView } = require('react-native-gesture-handler');
      return (
        <GestureHandlerRootView style={styles.inner}>
          <Text style={styles.ok}>gesture-handler OK ✓</Text>
        </GestureHandlerRootView>
      );
    },
  },
  {
    name: 'linear-gradient',
    render: () => {
      const { LinearGradient } = require('expo-linear-gradient');
      return (
        <View style={styles.inner}>
          <LinearGradient colors={['#3a2f7a', '#141826']} style={StyleSheet.absoluteFill} />
          <Text style={styles.ok}>gradient OK ✓</Text>
        </View>
      );
    },
  },
  {
    name: 'vector-icons',
    render: () => {
      const { Ionicons } = require('@expo/vector-icons');
      return (
        <View style={styles.inner}>
          <Ionicons name="planet" size={38} color="#7b6ef6" />
          <Text style={styles.ok}>icons OK ✓</Text>
        </View>
      );
    },
  },
];

export default function Root() {
  const [active, setActive] = React.useState<number | null>(null);
  return (
    <View style={styles.wrap}>
      <Text style={styles.title}>Tap each — one will crash</Text>
      <Text style={styles.sub}>
        Tap a button. If the app instantly closes, THAT library is the culprit — tell Claude its name.
        If a green “OK ✓” appears in the box, that one’s fine — try the next.
      </Text>
      <View style={styles.box}>
        {active !== null ? TESTS[active].render() : <Text style={styles.dim}>results show here</Text>}
      </View>
      {TESTS.map((t, i) => (
        <Pressable key={t.name} style={styles.btn} onPress={() => setActive(i)}>
          <Text style={styles.btnText}>Test {t.name}</Text>
        </Pressable>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { flex: 1, backgroundColor: '#0A0C16', paddingTop: 70, paddingHorizontal: 22, gap: 10 },
  title: { color: '#EDEFF7', fontSize: 20, fontWeight: '800', textAlign: 'center' },
  sub: { color: '#949ab2', fontSize: 13, textAlign: 'center', lineHeight: 19, marginBottom: 4 },
  box: {
    height: 92,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.11)',
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
    marginBottom: 6,
  },
  inner: { flex: 1, alignSelf: 'stretch', alignItems: 'center', justifyContent: 'center' },
  ok: { color: '#7be0c0', fontSize: 16, fontWeight: '700' },
  dim: { color: '#5b6178', fontSize: 13 },
  btn: {
    backgroundColor: '#141826',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.11)',
    paddingVertical: 14,
    alignItems: 'center',
  },
  btnText: { color: '#EDEFF7', fontSize: 15, fontWeight: '600' },
});
