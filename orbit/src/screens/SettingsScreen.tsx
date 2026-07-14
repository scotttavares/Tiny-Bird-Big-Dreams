import React, { useEffect, useState } from 'react';
import { View, Text, Pressable, ScrollView, Switch, StyleSheet, Alert } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useStore } from '../store';
import { THEMES } from '../theme';
import { scheduleWeeklyReport, cancelWeeklyReport, isWeeklyScheduled } from '../notifications';

export default function SettingsScreen() {
  const theme = THEMES[useStore((s) => s.theme)];
  const dark = useStore((s) => s.theme) === 'dark';
  const toggleTheme = useStore((s) => s.toggleTheme);
  const setScreen = useStore((s) => s.setScreen);
  const showToast = useStore((s) => s.showToast);
  const resetOrbit = useStore((s) => s.resetOrbit);
  const openImport = useStore((s) => s.openImport);

  const confirmClear = () =>
    Alert.alert(
      'Clear your orbit?',
      'This removes everyone from your orbit. This can’t be undone.',
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Clear', style: 'destructive', onPress: () => { resetOrbit(); showToast('Your orbit is clear'); } },
      ],
    );

  const contacts = useStore((s) => s.contacts);
  const [weekend, setWeekend] = useState(true);
  const [badges, setBadges] = useState(true);
  const [weeklyReport, setWeeklyReport] = useState(false);
  const speeds = ['Gentle', 'Steady', 'Brisk'];
  const [speed, setSpeed] = useState(0);
  const card = { backgroundColor: theme.card, borderColor: theme.border };

  useEffect(() => { isWeeklyScheduled().then(setWeeklyReport); }, []);
  const onToggleWeekly = async (on: boolean) => {
    if (on) {
      const ok = await scheduleWeeklyReport(Object.values(contacts));
      setWeeklyReport(ok);
      showToast(ok ? 'Weekly report on — gentle, Sundays' : 'Allow notifications to enable this');
    } else {
      await cancelWeeklyReport();
      setWeeklyReport(false);
      showToast('Weekly report off');
    }
  };

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
            <Row title="Weekly Gravity Report" sub="One gentle Sunday nudge about who's drifting" right={sw(weeklyReport, onToggleWeekly)} />
            <Row title="Subtle Badges" sub="No red dots, only soft glows" right={sw(badges, setBadges)} top />
          </View>

          <Text style={[styles.sect, { color: theme.faint, marginTop: 22 }]}>APPEARANCE</Text>
          <View style={[styles.cardList, card]}>
            <Row title="Dark Sky" sub="Switch between night and day" right={sw(dark, toggleTheme)} />
          </View>

          <Text style={[styles.sect, { color: theme.faint, marginTop: 22 }]}>WIDGETS</Text>
          <View style={[styles.cardList, card]}>
            <Row title="Home Screen Widget" sub="Long-press your home screen → + → Orbit" right={<Value v="" />} onPress={() => showToast('Add Orbit from your home screen: long-press → +')} />
          </View>

          <Text style={[styles.sect, { color: theme.faint, marginTop: 22 }]}>DATA</Text>
          <View style={[styles.cardList, card]}>
            <Row title="Import from Contacts" sub="Pull people from your address book" right={<Ionicons name="chevron-forward" size={15} color={theme.dim} />} onPress={openImport} />
            <Row title="Clear Orbit Data" sub="Remove everyone and start fresh" right={null} onPress={confirmClear} top />
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
