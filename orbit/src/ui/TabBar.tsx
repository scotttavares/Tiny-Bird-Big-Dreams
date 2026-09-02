import React from 'react';
import { View, Text, Pressable, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useStore } from '../store';
import { THEMES } from '../theme';
import type { Screen } from '../types';

const TABS: { key: Screen; label: string; icon: keyof typeof Ionicons.glyphMap; active: keyof typeof Ionicons.glyphMap }[] = [
  { key: 'orbit', label: 'Orbit', icon: 'planet-outline', active: 'planet' },
  { key: 'today', label: 'Today', icon: 'sunny-outline', active: 'sunny' },
  { key: 'people', label: 'People', icon: 'people-outline', active: 'people' },
  { key: 'settings', label: 'Settings', icon: 'options-outline', active: 'options' },
];

export default function TabBar() {
  const theme = THEMES[useStore((s) => s.theme)];
  const screen = useStore((s) => s.screen);
  const setScreen = useStore((s) => s.setScreen);

  return (
    <View style={[styles.bar, { backgroundColor: theme.bg, borderTopColor: theme.border }]}>
      {TABS.map((t) => {
        const on = screen === t.key;
        return (
          <Pressable key={t.key} style={styles.tab} onPress={() => setScreen(t.key)}>
            <Ionicons name={on ? t.active : t.icon} size={22} color={on ? theme.accent : theme.tabInactive} />
            <Text style={[styles.label, { color: on ? theme.accent : theme.tabInactive }]}>{t.label}</Text>
          </Pressable>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  bar: { height: 60, flexDirection: 'row', borderTopWidth: StyleSheet.hairlineWidth },
  tab: { flex: 1, alignItems: 'center', justifyContent: 'center', gap: 3, paddingTop: 6 },
  label: { fontSize: 10.5, fontWeight: '600' },
});
