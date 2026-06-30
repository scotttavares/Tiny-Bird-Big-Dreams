import React from 'react';
import { Text, StyleSheet } from 'react-native';
import Animated, { FadeInDown, FadeOutDown } from 'react-native-reanimated';
import { useStore } from '../store';

export default function Toast() {
  const toast = useStore((s) => s.toast);
  if (!toast) return null;
  return (
    <Animated.View entering={FadeInDown.duration(240)} exiting={FadeOutDown.duration(220)} style={styles.toast} pointerEvents="none">
      <Text style={styles.text}>{toast}</Text>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  toast: {
    position: 'absolute', bottom: 90, alignSelf: 'center', maxWidth: '84%',
    backgroundColor: '#1d2236', borderRadius: 13, paddingVertical: 11, paddingHorizontal: 18,
    shadowColor: '#000', shadowOpacity: 0.5, shadowRadius: 16, shadowOffset: { width: 0, height: 10 },
  },
  text: { color: '#fff', fontSize: 13, fontWeight: '600' },
});
