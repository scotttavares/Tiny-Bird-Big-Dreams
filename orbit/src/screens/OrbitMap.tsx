import React, { useEffect } from 'react';
import { View, Text, Pressable, StyleSheet, Image } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import Animated, {
  useSharedValue, useAnimatedStyle, withRepeat, withTiming, Easing,
  useFrameCallback, runOnJS, type SharedValue,
} from 'react-native-reanimated';
import * as ImagePicker from 'expo-image-picker';
import * as FileSystem from 'expo-file-system';
import { Ionicons } from '@expo/vector-icons';
import Avatar from '../ui/Avatar';
import { FIELD, CENTER, radius, ringDur, GROUP_COLOR } from '../orbit';
import { THEMES, YOU_GRAD, type Theme } from '../theme';
import { useStore } from '../store';
import type { Contact } from '../types';

function clampW(v: number, min: number, max: number) {
  'worklet';
  return Math.min(max, Math.max(min, v));
}

function Satellite({ c, elapsed, theme, dimmed, onOpen }: {
  c: Contact; elapsed: SharedValue<number>; theme: Theme; dimmed: boolean; onOpen: (id: string) => void;
}) {
  const r = useSharedValue(radius(c.ring));
  useEffect(() => {
    r.value = withTiming(radius(c.ring), { duration: 900, easing: Easing.out(Easing.cubic) });
  }, [c.ring, r]);

  const dur = ringDur(c.ring);
  const orbiter = useAnimatedStyle(() => {
    const ang = c.angle + (elapsed.value / (dur * 1000)) * 360;
    return { transform: [{ rotate: `${ang}deg` }] };
  });
  const arm = useAnimatedStyle(() => ({ transform: [{ translateX: r.value }] }));
  const counter = useAnimatedStyle(() => {
    const ang = c.angle + (elapsed.value / (dur * 1000)) * 360;
    return { transform: [{ rotate: `${-ang}deg` }] };
  });

  const tap = Gesture.Tap().maxDistance(14).onEnd(() => runOnJS(onOpen)(c.id));
  const AV = c.ring >= 3 ? 40 : 46;

  return (
    <Animated.View style={[styles.orbiter, orbiter]}>
      <Animated.View style={[styles.zero, arm]}>
        <Animated.View style={[styles.zero, counter, { opacity: dimmed ? 0.16 : c.ring >= 3 ? 0.85 : 1 }]}>
          <GestureDetector gesture={tap}>
            <View style={[styles.holder, { top: -AV / 2 }]}>
              <Avatar grad={c.grad} initials={c.initials} photo={c.photo} size={AV}
                drift={c.drift} driftColor={theme.drift} cutout={theme.bg} fav={c.fav} />
              <View style={styles.nameRow}>
                <View style={[styles.gdot, { backgroundColor: GROUP_COLOR[c.group] }]} />
                <Text style={[styles.nm, { color: theme.dim }]} numberOfLines={1}>{c.name.split(' ')[0]}</Text>
              </View>
            </View>
          </GestureDetector>
        </Animated.View>
      </Animated.View>
    </Animated.View>
  );
}

export default function OrbitMap({ contacts, onOpen }: { contacts: Contact[]; onOpen: (id: string) => void }) {
  const theme = THEMES[useStore((s) => s.theme)];
  const activeGroup = useStore((s) => s.activeGroup);
  const mePhoto = useStore((s) => s.mePhoto);
  const setMePhoto = useStore((s) => s.setMePhoto);
  const showToast = useStore((s) => s.showToast);

  // Let the user put their own face at the center. The photo is copied into the
  // app's document directory (so it persists) and stored on-device only.
  const pickFace = async () => {
    try {
      const perm = await ImagePicker.requestMediaLibraryPermissionsAsync();
      if (!perm.granted) { showToast('Allow photo access to set your face'); return; }
      const res = await ImagePicker.launchImageLibraryAsync({
        mediaTypes: ImagePicker.MediaTypeOptions.Images,
        allowsEditing: true, aspect: [1, 1], quality: 0.85,
      });
      if (res.canceled || !res.assets?.[0]) return;
      const dir = FileSystem.documentDirectory ?? '';
      const dest = `${dir}me-${Date.now()}.jpg`;
      await FileSystem.copyAsync({ from: res.assets[0].uri, to: dest });
      const prev = useStore.getState().mePhoto;
      setMePhoto(dest);
      if (prev && prev.startsWith(dir)) FileSystem.deleteAsync(prev, { idempotent: true }).catch(() => {});
    } catch {
      showToast("Couldn't set your photo");
    }
  };
  const youTap = Gesture.Tap().maxDistance(14).onEnd(() => runOnJS(pickFace)());

  // continuous time driving every contact's revolution (UI thread, no re-render)
  const elapsed = useSharedValue(0);
  useFrameCallback((info) => {
    elapsed.value += info.timeSincePreviousFrame ?? 16;
  });

  // breathing "You" core
  const breathe = useSharedValue(1);
  useEffect(() => {
    breathe.value = withRepeat(withTiming(1.05, { duration: 3000, easing: Easing.inOut(Easing.quad) }), -1, true);
  }, [breathe]);
  const youStyle = useAnimatedStyle(() => ({ transform: [{ scale: breathe.value }] }));

  // zoom + pan
  const scale = useSharedValue(0.82);
  const base = useSharedValue(0.82);
  const tx = useSharedValue(0);
  const ty = useSharedValue(0);
  const sx = useSharedValue(0);
  const sy = useSharedValue(0);

  const pinch = Gesture.Pinch()
    .onUpdate((e) => { scale.value = clampW(base.value * e.scale, 0.45, 3); })
    .onEnd(() => { base.value = scale.value; });
  const pan = Gesture.Pan()
    .minDistance(2)
    .onStart(() => { sx.value = tx.value; sy.value = ty.value; })
    .onUpdate((e) => { tx.value = sx.value + e.translationX; ty.value = sy.value + e.translationY; });
  const gesture = Gesture.Simultaneous(pinch, pan);

  const fieldStyle = useAnimatedStyle(() => ({
    transform: [{ translateX: tx.value }, { translateY: ty.value }, { scale: scale.value }],
  }));

  const zoomBy = (f: number) => {
    const v = Math.min(3, Math.max(0.45, scale.value * f));
    scale.value = withTiming(v, { duration: 220 });
    base.value = v;
  };
  const reset = () => {
    scale.value = withTiming(0.82, { duration: 280 });
    base.value = 0.82;
    tx.value = withTiming(0, { duration: 280 });
    ty.value = withTiming(0, { duration: 280 });
  };

  const maxRing = Math.max(3, ...contacts.map((c) => c.ring));
  const rings = Array.from({ length: maxRing }, (_, i) => i + 1);

  return (
    <View style={styles.wrap}>
      <GestureDetector gesture={gesture}>
        <Animated.View style={[styles.field, fieldStyle]}>
          {rings.map((n) => {
            const d = radius(n) * 2;
            return (
              <View key={n} style={{
                position: 'absolute', width: d, height: d, borderRadius: d / 2,
                left: CENTER - radius(n), top: CENTER - radius(n),
                borderWidth: theme.name === 'light' ? 1.4 : 1,
                borderColor: n === 1 ? theme.ring : theme.ringFaint,
              }} />
            );
          })}

          <GestureDetector gesture={youTap}>
            <Animated.View style={[styles.youWrap, youStyle]}>
              <View style={styles.you}>
                {mePhoto ? (
                  <Image source={{ uri: mePhoto }} style={StyleSheet.absoluteFill} />
                ) : (
                  <>
                    <LinearGradient colors={YOU_GRAD} start={{ x: 0.3, y: 0.2 }} end={{ x: 1, y: 1 }} style={StyleSheet.absoluteFill} />
                    <Text style={styles.youText}>You</Text>
                  </>
                )}
              </View>
              <View style={[styles.youBadge, { borderColor: theme.bg }]}>
                <Ionicons name="camera" size={11} color="#fff" />
              </View>
            </Animated.View>
          </GestureDetector>

          {contacts.map((c) => (
            <Satellite key={c.id} c={c} elapsed={elapsed} theme={theme} onOpen={onOpen}
              dimmed={activeGroup !== 'All' && c.group !== activeGroup} />
          ))}
        </Animated.View>
      </GestureDetector>

      <View style={styles.zoomctl}>
        <Pressable onPress={() => zoomBy(1.3)} style={[styles.zbtn, { backgroundColor: theme.card, borderColor: theme.border2 }]}>
          <Text style={{ color: theme.text, fontSize: 20, fontWeight: '600' }}>+</Text>
        </Pressable>
        <Pressable onPress={() => zoomBy(1 / 1.3)} style={[styles.zbtn, { backgroundColor: theme.card, borderColor: theme.border2 }]}>
          <Text style={{ color: theme.text, fontSize: 20, fontWeight: '600' }}>−</Text>
        </Pressable>
        <Pressable onPress={reset} style={[styles.zbtn, { backgroundColor: theme.card, borderColor: theme.border2 }]}>
          <Text style={{ color: theme.text, fontSize: 15, fontWeight: '600' }}>⤢</Text>
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { flex: 1, alignItems: 'center', justifyContent: 'center', overflow: 'hidden' },
  field: { width: FIELD, height: FIELD },
  zero: { position: 'absolute', left: 0, top: 0, width: 0, height: 0 },
  orbiter: { position: 'absolute', left: CENTER, top: CENTER, width: 0, height: 0 },
  holder: { position: 'absolute', left: -44, width: 88, alignItems: 'center' },
  nameRow: { flexDirection: 'row', alignItems: 'center', marginTop: 5 },
  gdot: { width: 7, height: 7, borderRadius: 3.5, marginRight: 5 },
  nm: { fontSize: 11.5, fontWeight: '600' },
  youWrap: {
    position: 'absolute', left: CENTER - 32, top: CENTER - 32, width: 64, height: 64, borderRadius: 32,
    backgroundColor: '#6C5CE7', alignItems: 'center', justifyContent: 'center',
    shadowColor: '#6C5CE7', shadowOpacity: 0.5, shadowRadius: 18, shadowOffset: { width: 0, height: 10 },
  },
  you: { width: 64, height: 64, borderRadius: 32, overflow: 'hidden', alignItems: 'center', justifyContent: 'center' },
  youText: { color: '#fff', fontWeight: '700', fontSize: 14 },
  youBadge: {
    position: 'absolute', right: -2, bottom: -2, width: 22, height: 22, borderRadius: 11,
    backgroundColor: '#8E7BFF', borderWidth: 2, alignItems: 'center', justifyContent: 'center',
  },
  zoomctl: { position: 'absolute', right: 12, bottom: 12, gap: 6 },
  zbtn: { width: 36, height: 36, borderRadius: 11, borderWidth: 1, alignItems: 'center', justifyContent: 'center' },
});
