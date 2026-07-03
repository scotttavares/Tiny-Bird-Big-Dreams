import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  useFrameCallback,
  withRepeat,
  withTiming,
  Easing,
} from 'react-native-reanimated';

// ⚠️ TEMPORARY DIAGNOSTIC #2 ⚠️
// Renders ONLY Reanimated (a shared value + animated style + withRepeat, plus
// useFrameCallback — the exact APIs the app uses), and nothing else (no gestures,
// no gradient, no screens). This pinpoints the native launch crash:
//   • Text PULSES ("Reanimated OK") → Reanimated is healthy; the crash is in
//     gesture-handler / expo-linear-gradient / the screens. I bisect those next.
//   • White-screens and quits → Reanimated itself is the crash (a native/JSI
//     issue), and I pin/repair it.
export default function Root() {
  const op = useSharedValue(0.25);
  const frames = useSharedValue(0);
  useFrameCallback((info) => {
    frames.value += info.timeSincePreviousFrame ?? 16;
  });
  React.useEffect(() => {
    op.value = withRepeat(withTiming(1, { duration: 900, easing: Easing.inOut(Easing.quad) }), -1, true);
  }, [op]);
  const style = useAnimatedStyle(() => ({ opacity: op.value }));

  return (
    <View style={styles.wrap}>
      <Animated.View style={style}>
        <Text style={styles.title}>Reanimated OK ✓</Text>
      </Animated.View>
      <Text style={styles.sub}>
        Diagnostic. If this text is pulsing, the animation engine works and the crash is elsewhere.
        If you got a white flash instead, Reanimated is the culprit. Tell Claude which.
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { flex: 1, backgroundColor: '#0A0C16', alignItems: 'center', justifyContent: 'center', paddingHorizontal: 34 },
  title: { color: '#EDEFF7', fontSize: 26, fontWeight: '800', marginBottom: 16, textAlign: 'center' },
  sub: { color: '#949ab2', fontSize: 13.5, textAlign: 'center', lineHeight: 20 },
});
