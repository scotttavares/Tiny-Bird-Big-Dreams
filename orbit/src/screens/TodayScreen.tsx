import React, { useState } from 'react';
import { View, Text, Pressable, ScrollView, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import Avatar from '../ui/Avatar';
import { useStore, pickNudgeId } from '../store';
import { THEMES } from '../theme';
import { PROMPTS, roleLine } from '../orbit';

export default function TodayScreen() {
  const theme = THEMES[useStore((s) => s.theme)];
  const contacts = useStore((s) => s.contacts);
  const openContact = useStore((s) => s.openContact);
  const pull = useStore((s) => s.pull);
  const toggleSnooze = useStore((s) => s.toggleSnooze);
  const showToast = useStore((s) => s.showToast);
  const [pi, setPi] = useState(0);

  const list = Object.values(contacts);
  const nudgeId = pickNudgeId(contacts);
  const nudge = nudgeId ? contacts[nudgeId] : null;
  const stats: [string, number, string][] = [
    ['🌍', list.length, 'in orbit'],
    ['🌗', list.filter((c) => c.drift).length, 'drifting'],
    ['🧲', list.filter((c) => c.anchored).length, 'anchored'],
    ['⭐', list.filter((c) => c.fav).length, 'favorites'],
  ];
  const upcoming = list.filter((c) => c.reminder);
  const card = { backgroundColor: theme.card, borderColor: theme.border };

  return (
    <View style={{ flex: 1 }}>
      <View style={styles.head}>
        <Text style={[styles.h1, { color: theme.text }]}>Today</Text>
        <Text style={{ color: theme.dim, fontSize: 13.5, marginTop: 3 }}>A gentle moment for your people</Text>
      </View>
      <ScrollView contentContainerStyle={{ padding: 20, paddingTop: 6 }} showsVerticalScrollIndicator={false}>
        {nudge ? (
          <View style={[styles.hero, card]}>
            <Text style={[styles.label, { color: theme.accent }]}>ONE GENTLE NUDGE</Text>
            <View style={{ flexDirection: 'row', gap: 13, alignItems: 'center' }}>
              <Avatar grad={nudge.grad} initials={nudge.initials} photo={nudge.photo} size={60} cutout={theme.card} drift={nudge.drift} driftColor={theme.drift} />
              <View style={{ flex: 1 }}>
                <Text style={{ fontSize: 19, fontWeight: '800', color: theme.text }}>{nudge.name}</Text>
                <Text style={{ color: theme.dim, fontSize: 13, marginTop: 2 }}>{roleLine(nudge)}</Text>
              </View>
            </View>
            <Text style={{ color: theme.dim, fontSize: 13.5, lineHeight: 20, marginVertical: 13 }}>It's been a while — a small hello would mean a lot.</Text>
            <View style={{ flexDirection: 'row', gap: 10 }}>
              <Pressable style={[styles.btn, { backgroundColor: theme.accent2 }]} onPress={() => openContact(nudge.id)}>
                <Ionicons name="chatbubble-outline" size={16} color="#fff" /><Text style={styles.btnT}>Say hello</Text>
              </Pressable>
              <Pressable style={[styles.btn, { backgroundColor: theme.card2, borderWidth: 1, borderColor: theme.border }]}
                onPress={() => { pull(nudge.id); showToast('You thought of them — pulled closer ✨'); }}>
                <Text style={[styles.btnT, { color: theme.text }]}>💭 Thought of them</Text>
              </Pressable>
            </View>
            <Pressable onPress={() => { toggleSnooze(nudge.id); showToast('Snoozed for now'); }}>
              <Text style={{ textAlign: 'center', color: theme.faint, fontSize: 12.5, marginTop: 10 }}>Not today — snooze</Text>
            </Pressable>
          </View>
        ) : (
          <View style={[styles.hero, card, { alignItems: 'center', paddingVertical: 32 }]}>
            <Text style={{ fontSize: 40, marginBottom: 8 }}>✨</Text>
            <Text style={{ fontSize: 19, fontWeight: '800', color: theme.text }}>You're all caught up</Text>
            <Text style={{ color: theme.dim, fontSize: 13, marginTop: 4 }}>No one's drifting right now. Enjoy the calm.</Text>
          </View>
        )}

        <View style={[styles.prompt, card]}>
          <Text style={{ flex: 1, fontSize: 13.5, fontWeight: '600', color: theme.text }}>💭 {PROMPTS[pi % PROMPTS.length]}</Text>
          <Pressable onPress={() => setPi(pi + 1)} style={[styles.prNext, { backgroundColor: theme.card2 }]}>
            <Text style={{ color: theme.dim, fontSize: 15 }}>↻</Text>
          </Pressable>
        </View>

        <Text style={[styles.sect, { color: theme.faint }]}>YOUR ORBIT AT A GLANCE</Text>
        <View style={styles.statgrid}>
          {stats.map(([e, n, l], i) => (
            <View key={i} style={[styles.stat, card]}>
              <Text style={{ fontSize: 24, fontWeight: '800', color: theme.text }}>{n}</Text>
              <Text style={{ color: theme.dim, fontSize: 12, marginTop: 3 }}>{e} {l}</Text>
            </View>
          ))}
        </View>

        {upcoming.length > 0 ? (
          <>
            <Text style={[styles.sect, { color: theme.faint }]}>UPCOMING CHECK-INS</Text>
            <View style={[styles.cardList, card]}>
              {upcoming.map((c, i) => (
                <Pressable key={c.id} onPress={() => openContact(c.id)}
                  style={[styles.row, i > 0 ? { borderTopWidth: 1, borderTopColor: theme.border } : null]}>
                  <Avatar grad={c.grad} initials={c.initials} photo={c.photo} size={38} cutout={theme.card} />
                  <View>
                    <Text style={{ fontWeight: '600', fontSize: 14, color: theme.text }}>{c.name}</Text>
                    <Text style={{ color: theme.dim, fontSize: 12, marginTop: 2 }}>⏰ {c.reminder}</Text>
                  </View>
                </Pressable>
              ))}
            </View>
          </>
        ) : null}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  head: { paddingHorizontal: 20, paddingTop: 8, paddingBottom: 2 },
  h1: { fontSize: 30, fontWeight: '800', letterSpacing: -0.5 },
  hero: { borderRadius: 20, borderWidth: 1, padding: 18 },
  label: { fontSize: 11, fontWeight: '700', letterSpacing: 1, marginBottom: 12 },
  btn: { flex: 1, borderRadius: 14, paddingVertical: 13, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 8 },
  btnT: { color: '#fff', fontWeight: '700', fontSize: 13.5 },
  prompt: { flexDirection: 'row', alignItems: 'center', gap: 10, marginTop: 14, borderRadius: 16, borderWidth: 1, paddingVertical: 13, paddingHorizontal: 15 },
  prNext: { width: 32, height: 32, borderRadius: 16, alignItems: 'center', justifyContent: 'center' },
  sect: { fontSize: 11, fontWeight: '700', letterSpacing: 1, marginTop: 20, marginBottom: 9, marginLeft: 4 },
  statgrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 10 },
  stat: { width: '47.8%', flexGrow: 1, borderRadius: 14, borderWidth: 1, paddingVertical: 13, paddingHorizontal: 15 },
  cardList: { borderRadius: 18, borderWidth: 1, overflow: 'hidden' },
  row: { flexDirection: 'row', alignItems: 'center', gap: 13, padding: 14 },
});
