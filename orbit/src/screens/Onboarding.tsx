import React from 'react';
import { View, Text, Pressable, StyleSheet } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import Animated, { FadeIn, FadeOut } from 'react-native-reanimated';
import OrbitLogo from '../ui/OrbitLogo';
import { useStore } from '../store';
import { THEMES, YOU_GRAD } from '../theme';

const BULLETS: [string, string, string][] = [
  ['🪐', 'People drift outward over time', 'The longer since you connected, the farther they orbit.'],
  ['✨', 'Small gestures pull them back', 'A text, a call, or just thinking of them adds gravity.'],
  ['🌙', 'No guilt, no red dots', 'Only gentle, quiet nudges — tuned to your social battery.'],
];

export default function Onboarding() {
  const theme = THEMES[useStore((s) => s.theme)];
  const onboarded = useStore((s) => s.onboarded);
  const dismiss = useStore((s) => s.dismissOnboarding);
  if (onboarded) return null;

  return (
    <Animated.View entering={FadeIn.duration(300)} exiting={FadeOut.duration(300)} style={StyleSheet.absoluteFill}>
      <LinearGradient colors={theme.name === 'dark' ? ['#20264a', theme.bg] : ['#e7e3ff', theme.bg]} style={StyleSheet.absoluteFill} />
      <View style={styles.center}>
        <View style={styles.logo}>
          <LinearGradient colors={YOU_GRAD} start={{ x: 0.3, y: 0.2 }} end={{ x: 1, y: 1 }} style={StyleSheet.absoluteFill} />
        </View>
        <OrbitLogo color={theme.accent} textColor={theme.text} fontSize={30} />
        <Text style={{ color: theme.dim, fontSize: 14, marginTop: 8 }}>Gravity for the people who matter.</Text>

        <View style={{ marginVertical: 28, gap: 16, width: '100%' }}>
          {BULLETS.map(([e, t, s], i) => (
            <View key={i} style={{ flexDirection: 'row', gap: 13 }}>
              <Text style={{ fontSize: 20, width: 26, textAlign: 'center' }}>{e}</Text>
              <View style={{ flex: 1 }}>
                <Text style={{ color: theme.text, fontWeight: '600', fontSize: 14 }}>{t}</Text>
                <Text style={{ color: theme.dim, fontSize: 12.5, marginTop: 1, lineHeight: 18 }}>{s}</Text>
              </View>
            </View>
          ))}
        </View>

        <Pressable style={[styles.cta, { backgroundColor: theme.accent2 }]} onPress={dismiss}>
          <Text style={{ color: '#fff', fontWeight: '700', fontSize: 15 }}>Enter your orbit</Text>
        </Pressable>
      </View>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  center: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 34 },
  logo: {
    width: 96, height: 96, borderRadius: 48, overflow: 'hidden', marginBottom: 22,
    shadowColor: '#6C5CE7', shadowOpacity: 0.5, shadowRadius: 24, shadowOffset: { width: 0, height: 14 },
  },
  cta: { width: '100%', borderRadius: 16, paddingVertical: 16, alignItems: 'center' },
});
