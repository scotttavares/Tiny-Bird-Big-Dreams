import React from 'react';
import { View, Text, Image, StyleSheet } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { gradOf } from '../theme';

type Props = {
  grad: string;
  initials: string;
  photo?: string | null;
  size?: number;
  drift?: boolean;
  driftColor?: string;
  cutout?: string;   // the surrounding bg color, for the ring border
  fav?: boolean;
};

export default function Avatar({ grad, initials, photo, size = 46, drift, driftColor = '#E8A24A', cutout = '#0A0C16', fav }: Props) {
  const [a, b] = gradOf(grad);
  return (
    <View style={{ width: size, height: size }}>
      <View
        style={[
          styles.wrap,
          { width: size, height: size, borderRadius: size / 2, borderColor: cutout },
          drift ? { borderColor: driftColor } : null,
        ]}
      >
        <LinearGradient colors={[a, b]} start={{ x: 0.15, y: 0.1 }} end={{ x: 0.9, y: 1 }} style={StyleSheet.absoluteFill} />
        <Text style={[styles.ini, { fontSize: size * 0.34 }]}>{initials}</Text>
        {photo ? <Image source={{ uri: photo }} style={StyleSheet.absoluteFill} /> : null}
      </View>
      {drift ? <View style={[styles.ddot, { backgroundColor: driftColor, borderColor: cutout }]} /> : null}
      {fav ? <Text style={styles.fav}>★</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { overflow: 'hidden', borderWidth: 2, alignItems: 'center', justifyContent: 'center' },
  ini: { color: '#fff', fontWeight: '700' },
  ddot: { position: 'absolute', top: -2, right: -2, width: 12, height: 12, borderRadius: 6, borderWidth: 2 },
  fav: { position: 'absolute', top: -5, left: -3, fontSize: 13, color: '#ffcf4d' },
});
