import React from 'react';
import { View, Text, Pressable, ScrollView, StyleSheet } from 'react-native';
import Animated, { FadeIn, FadeOut, SlideInDown, SlideOutDown } from 'react-native-reanimated';
import { THEMES } from '../theme';
import { useStore } from '../store';

export default function Sheet({ visible, onClose, children }: { visible: boolean; onClose: () => void; children: React.ReactNode }) {
  const theme = THEMES[useStore((s) => s.theme)];
  if (!visible) return null;
  return (
    <View style={[StyleSheet.absoluteFill, styles.root]} pointerEvents="box-none">
      <Animated.View entering={FadeIn.duration(220)} exiting={FadeOut.duration(200)} style={StyleSheet.absoluteFill}>
        <Pressable style={styles.backdrop} onPress={onClose} />
      </Animated.View>
      <Animated.View
        entering={SlideInDown.duration(320)}
        exiting={SlideOutDown.duration(240)}
        style={[styles.sheet, { backgroundColor: theme.bg2, borderColor: theme.border2 }]}
      >
        <View style={[styles.grip, { backgroundColor: theme.border2 }]} />
        <Pressable style={[styles.x, { backgroundColor: theme.card, borderColor: theme.border2 }]} onPress={onClose}>
          <Text style={{ color: theme.dim, fontSize: 13 }}>✕</Text>
        </Pressable>
        <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={{ paddingBottom: 8 }}>
          {children}
        </ScrollView>
      </Animated.View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { justifyContent: 'flex-end' },
  backdrop: { flex: 1, backgroundColor: 'rgba(6,8,16,0.55)' },
  sheet: {
    maxHeight: '88%', borderTopLeftRadius: 26, borderTopRightRadius: 26, borderTopWidth: 1,
    paddingHorizontal: 22, paddingTop: 10, paddingBottom: 26,
  },
  grip: { width: 40, height: 4, borderRadius: 99, alignSelf: 'center', marginTop: 4, marginBottom: 14 },
  x: { position: 'absolute', top: 13, right: 15, width: 30, height: 30, borderRadius: 15, borderWidth: 1, alignItems: 'center', justifyContent: 'center', zIndex: 4 },
});
