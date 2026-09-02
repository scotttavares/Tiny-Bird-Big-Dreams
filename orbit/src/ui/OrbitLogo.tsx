import React, { useEffect } from 'react';
import { View, Text } from 'react-native';
import Animated, { useSharedValue, useAnimatedStyle, withRepeat, withTiming, Easing } from 'react-native-reanimated';

// The Orbit wordmark: a thin ring with a core and a planet that slowly circles it,
// standing in for the "O" — followed by "rbit".
export default function OrbitLogo({ size = 26, color, textColor, fontSize = 30 }: {
  size?: number; color: string; textColor: string; fontSize?: number;
}) {
  const spin = useSharedValue(0);
  useEffect(() => {
    spin.value = withRepeat(withTiming(360, { duration: 9000, easing: Easing.linear }), -1);
  }, [spin]);
  const planet = useAnimatedStyle(() => ({ transform: [{ rotate: `${spin.value}deg` }] }));

  const r = size / 2;
  const dot = Math.max(3, size * 0.13);
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center' }}>
      <View style={{ width: size, height: size, alignItems: 'center', justifyContent: 'center' }}>
        {/* ring */}
        <View style={{ position: 'absolute', width: size, height: size, borderRadius: r, borderWidth: 1.3, borderColor: color }} />
        {/* core */}
        <View style={{ width: dot * 1.5, height: dot * 1.5, borderRadius: dot, backgroundColor: color }} />
        {/* orbiting planet */}
        <Animated.View style={[{ position: 'absolute', width: 0, height: 0 }, planet]}>
          <View style={{ position: 'absolute', left: r - dot, top: -dot, width: dot * 1.4, height: dot * 1.4, borderRadius: dot, backgroundColor: color }} />
        </Animated.View>
      </View>
      <Text style={{ color: textColor, fontSize, fontWeight: '800', letterSpacing: -0.5 }}>rbit</Text>
    </View>
  );
}
