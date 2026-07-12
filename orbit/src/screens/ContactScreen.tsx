import React from 'react';
import { View, Text, Pressable, ScrollView, StyleSheet, Linking } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import Avatar from '../ui/Avatar';
import { useStore } from '../store';
import { THEMES } from '../theme';
import { roleLine, sinceLabel } from '../orbit';

export default function ContactScreen() {
  const theme = THEMES[useStore((s) => s.theme)];
  const id = useStore((s) => s.currentId);
  const c = useStore((s) => (id ? s.contacts[id] : undefined));
  const setScreen = useStore((s) => s.setScreen);
  const openActions = useStore((s) => s.openActions);
  const openReach = useStore((s) => s.openReach);
  const openLog = useStore((s) => s.openLog);
  const logInteraction = useStore((s) => s.logInteraction);
  const pull = useStore((s) => s.pull);
  const showToast = useStore((s) => s.showToast);

  if (!c) return <View style={{ flex: 1 }} />;
  const card = { backgroundColor: theme.card, borderColor: theme.border };

  // Reaching out counts as reconnecting, so it pulls the person back toward the
  // center. Texting opens a chooser (Messages / WhatsApp / Telegram / …) via the
  // reach sheet; calling dials straight through the OS.
  const numberOr = (warn: boolean) => {
    const num = (c.phone ?? '').replace(/[^\d+*#]/g, '');
    if (!num && warn) showToast(`No number saved for ${c.name.split(' ')[0]}`);
    return num;
  };
  const text = () => {
    if (numberOr(true)) openReach(c.id);
  };
  const call = () => {
    const num = numberOr(true);
    if (!num) return;
    pull(c.id);
    Linking.openURL(`tel:${num}`).catch(() => showToast("Couldn't start the call"));
  };
  const tl: [string, string][] = [
    ...(c.log ?? []).map((e) => [e.label, sinceLabel(e.at)] as [string, string]),
    ['Added to Orbit', ''],
  ];
  const chips: string[] = [];
  if (c.fav) chips.push('⭐ Favorite');
  if (c.reminder) chips.push('⏰ ' + c.reminder);
  if (c.speed && c.speed !== 'Steady') chips.push('🌗 ' + c.speed + ' drift');

  return (
    <View style={{ flex: 1 }}>
      <View style={styles.topbar}>
        <Pressable hitSlop={8} onPress={() => setScreen('orbit')}><Ionicons name="chevron-back" size={24} color={theme.text} /></Pressable>
        <Text style={{ color: theme.dim, fontWeight: '600', fontSize: 14 }}>Orbit</Text>
        <Pressable hitSlop={8} onPress={openActions}><Ionicons name="ellipsis-horizontal" size={22} color={theme.text} /></Pressable>
      </View>
      <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={{ paddingBottom: 24 }}>
        <View style={{ alignItems: 'center', paddingTop: 6 }}>
          <Avatar grad={c.grad} initials={c.initials} photo={c.photo} size={96} cutout={theme.bg} fav={c.fav} />
          {c.drift ? <View style={[styles.badge, { backgroundColor: theme.drift }]}><Text style={styles.badgeT}>● DRIFTING</Text></View> : null}
          <Text style={{ fontSize: 24, fontWeight: '800', color: theme.text, marginTop: 12 }}>{c.name}</Text>
          <Text style={{ color: theme.dim, fontSize: 13.5, marginTop: 4 }}>{roleLine(c)}</Text>
        </View>

        <View style={{ flexDirection: 'row', gap: 12, paddingHorizontal: 20, paddingTop: 18 }}>
          <Pressable style={[styles.btn, { backgroundColor: theme.accent2 }]} onPress={text}>
            <Ionicons name="chatbubble-outline" size={18} color="#fff" /><Text style={styles.btnT}>Send a Text</Text>
          </Pressable>
          <Pressable style={[styles.btn, { backgroundColor: theme.card2, borderWidth: 1, borderColor: theme.border }]} onPress={call}>
            <Ionicons name="call-outline" size={18} color={theme.text} /><Text style={[styles.btnT, { color: theme.text }]}>Quick Call</Text>
          </Pressable>
        </View>

        {chips.length > 0 || c.note ? (
          <View style={{ paddingHorizontal: 20, paddingTop: 14 }}>
            {chips.length > 0 ? (
              <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 7 }}>
                {chips.map((t, i) => (
                  <View key={i} style={[styles.metachip, { backgroundColor: theme.accentSoft }]}><Text style={{ color: theme.accent, fontSize: 12, fontWeight: '600' }}>{t}</Text></View>
                ))}
              </View>
            ) : null}
            {c.note ? (
              <View style={[styles.note, card, { marginTop: chips.length ? 12 : 0 }]}>
                <Text style={{ color: theme.faint, fontSize: 11, fontWeight: '700', letterSpacing: 1, marginBottom: 4 }}>NOTE</Text>
                <Text style={{ color: theme.text, fontSize: 13.5, lineHeight: 19 }}>{c.note}</Text>
              </View>
            ) : null}
          </View>
        ) : null}

        <View style={{ padding: 20 }}>
          <Text style={[styles.sect, { color: theme.faint }]}>QUIET CHECK-IN</Text>
          <View style={[styles.cardList, card]}>
            <Pressable style={styles.row} onPress={() => openLog(c.id)}>
              <View style={[styles.emo, { backgroundColor: theme.accentSoft }]}><Text style={{ fontSize: 17 }}>👋</Text></View>
              <View style={{ flex: 1 }}><Text style={{ fontWeight: '600', fontSize: 14, color: theme.text }}>Log an external interaction</Text><Text style={{ color: theme.dim, fontSize: 12, marginTop: 2 }}>Met up, called, ran into them…</Text></View>
            </Pressable>
            <Pressable style={[styles.row, { borderTopWidth: 1, borderTopColor: theme.border }]} onPress={() => { logInteraction(c.id, 'Thought of you'); showToast('You thought of them — pulled closer ✨'); }}>
              <View style={[styles.emo, { backgroundColor: theme.accentSoft }]}><Text style={{ fontSize: 17 }}>💭</Text></View>
              <View style={{ flex: 1 }}><Text style={{ fontWeight: '600', fontSize: 14, color: theme.text }}>Just thought of them</Text><Text style={{ color: theme.dim, fontSize: 12, marginTop: 2 }}>Pulls them slightly closer without contact.</Text></View>
            </Pressable>
          </View>

          <Text style={[styles.sect, { color: theme.faint, marginTop: 22 }]}>RECENT GRAVITY</Text>
          <View style={[styles.cardList, card, { padding: 8 }]}>
            {tl.map(([t, d], i) => (
              <View key={i} style={{ flexDirection: 'row', gap: 13, padding: 7 }}>
                <View style={{ alignItems: 'center' }}>
                  <View style={[styles.tldot, { backgroundColor: theme.accent }]} />
                  {i < tl.length - 1 ? <View style={[styles.tlline, { backgroundColor: theme.border2 }]} /> : null}
                </View>
                <View><Text style={{ fontWeight: '600', fontSize: 13.5, color: theme.text }}>{t}</Text>{d ? <Text style={{ color: theme.faint, fontSize: 11.5, marginTop: 1 }}>{d}</Text> : null}</View>
              </View>
            ))}
          </View>
        </View>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  topbar: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 18, paddingTop: 6, paddingBottom: 2 },
  badge: { flexDirection: 'row', marginTop: -14, paddingVertical: 4, paddingHorizontal: 10, borderRadius: 999 },
  badgeT: { color: '#3a2406', fontSize: 10.5, fontWeight: '800', letterSpacing: 0.6 },
  btn: { flex: 1, borderRadius: 16, paddingVertical: 15, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 9 },
  btnT: { color: '#fff', fontWeight: '700', fontSize: 14.5 },
  metachip: { flexDirection: 'row', alignItems: 'center', paddingVertical: 6, paddingHorizontal: 11, borderRadius: 999 },
  note: { borderRadius: 14, borderWidth: 1, padding: 12 },
  sect: { fontSize: 11, fontWeight: '700', letterSpacing: 1, marginBottom: 9, marginLeft: 4 },
  cardList: { borderRadius: 18, borderWidth: 1, overflow: 'hidden' },
  row: { flexDirection: 'row', alignItems: 'center', gap: 13, padding: 14 },
  emo: { width: 34, height: 34, borderRadius: 10, alignItems: 'center', justifyContent: 'center' },
  tldot: { width: 10, height: 10, borderRadius: 5, marginTop: 4 },
  tlline: { width: 2, flex: 1, marginTop: 3 },
});
