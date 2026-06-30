import React, { useState } from 'react';
import { View, Text, Pressable, ScrollView, Switch, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useStore } from '../store';
import { THEMES } from '../theme';

export default function SettingsScreen() {
  const theme = THEMES[useStore((s) => s.theme)];
  const dark = useStore((s) => s.theme) === 'dark';
  const toggleTheme = useStore((s) => s.toggleTheme);
  const setScreen = useStore((s) => s.setScreen);
  const showToast = useStore((s) => s.showToast);

  const [weekend, setWeekend] = useState(true);
  const [badges, setBadges] = useState(true);
  const speeds = ['Gentle', 'Steady', 'Brisk'];
  const freqs = ['Low', 'Medium', 'High'];
  const [speed, setSpeed] = useState(0);
  const [freq, setFreq] = useState(0);
  const card = { backgroundColor: theme.card, borderColor: theme.border };

  const Row = ({ title, sub, right, onPress, top }: { title: string; sub?: string; right?: React.ReactNode; onPress?: () => void; top?: boolean }) => (
    <Pressable disabled={!onPress} onPress={onPress}
      style={[styles.row, top ? { borderTopWidth: 1, borderTopColor: theme.border } : null]}>
      <View style={{ flex: 1 }}>
        <Text style={{ fontWeight: '600', fontSize: 14, color: theme.text }}>{title}</Text>
        {sub ? <Text style={{ color: theme.dim, fontSize: 12, marginTop: 2 }}>{sub}</Text> : null}
      </View>
      {right}
    </Pressable>
  );
  const Value = ({ v }: { v: string }) => (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4 }}>
      <Text style={{ color: theme.dim, fontSize: 13, fontWeight: '600' }}>{v}</Text>
      <Ionicons name="chevron-forward" size={15} color={theme.dim} />
    </View>
  );
  const sw = (val: boolean, on: (v: boolean) => void) => (
    <Switch value={val} onValueChange={on} trackColor={{ true: theme.accent, false: theme.border2 }} thumbColor="#fff" />
  );

  return (
    <View style={{ flex: 1 }}>
      <View style={styles.head}>
        <Text style={[styles.h1, { color: theme.text }]}>Settings</Text>
        <Pressable onPress={() => setScreen('orbit')}><Text style={{ color: theme.accent, fontWeight: '700', fontSize: 15 }}>Done</Text></Pressable>
      </View>
      <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={{ paddingBottom: 30 }}>
        <Text style={[styles.intro, { color: theme.dim }]}>Orbit is designed to reduce guilt. Adjust how gravity works below to suit your natural social battery.</Text>
        <View style={{ paddingHorizontal: 20 }}>
          <Text style={[styles.sect, { color: theme.faint }]}>GRAVITY MECHANICS</Text>
          <View style={[styles.cardList, card]}>
            <Row title="Default Drift Speed" sub="How fast contacts move outward" right={<Value v={speeds[speed]} />} onPress={() => setSpeed((speed + 1) % 3)} />
            <Row title="Slow Drift on Weekends" sub="Pause gravity on your days off" right={sw(weekend, setWeekend)} top />
          </View>

          <Text style={[styles.sect, { color: theme.faint, marginTop: 22 }]}>QUIET NOTIFICATIONS</Text>
          <View style={[styles.cardList, card]}>
            <Row title="Nudge Frequency" sub="Max 1 alert per week" right={<Value v={freqs[freq]} />} onPress={() => setFreq((freq + 1) % 3)} />
            <Row title="Subtle Badges" sub="No red dots, only soft glows" right={sw(badges, setBadges)} top />
          </View>

          <Text style={[styles.sect, { color: theme.faint, marginTop: 22 }]}>APPEARANCE</Text>
          <View style={[styles.cardList, card]}>
            <Row title="Dark Sky" sub="Switch between night and day" right={sw(dark, toggleTheme)} />
          </View>

          <Text style={[styles.sect, { color: theme.faint, marginTop: 22 }]}>WIDGETS</Text>
          <View style={[styles.cardList, card]}>
            <Row title="Home Screen Widget" sub="A real WidgetKit extension — coming soon" right={<Value v="" />} onPress={() => showToast('Native widget is on the roadmap')} />
          </View>

          <Text style={[styles.sect, { color: theme.faint, marginTop: 22 }]}>DATA</Text>
          <View style={[styles.cardList, card]}>
            <Row title="Sync from Contacts" right={<Value v="Updated today" />} onPress={() => showToast('Synced from Contacts')} />
            <Row title="Export Connection History" onPress={() => showToast('Exporting…')} top />
            <Row title="Clear Orbit Data" right={null} onPress={() => showToast('Hold to confirm — your orbit is safe')} top />
          </View>
          <Text style={{ textAlign: 'center', color: theme.faint, fontSize: 11, paddingVertical: 18 }}>Orbit · gravity for the people who matter</Text>
        </View>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  head: { paddingHorizontal: 20, paddingTop: 8, paddingBottom: 2, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  h1: { fontSize: 26, fontWeight: '800' },
  intro: { fontSize: 13.5, lineHeight: 20, paddingHorizontal: 20, paddingTop: 6, paddingBottom: 18 },
  sect: { fontSize: 11, fontWeight: '700', letterSpacing: 1, marginBottom: 9, marginLeft: 4 },
  cardList: { borderRadius: 18, borderWidth: 1, overflow: 'hidden' },
  row: { flexDirection: 'row', alignItems: 'center', gap: 13, padding: 14, minHeight: 56 },
});
