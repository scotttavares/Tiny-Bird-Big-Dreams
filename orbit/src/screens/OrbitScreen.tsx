import React from 'react';
import { View, Text, Pressable, ScrollView, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import OrbitMap from './OrbitMap';
import OrbitLogo from '../ui/OrbitLogo';
import Avatar from '../ui/Avatar';
import { useStore, pickNudgeId } from '../store';
import { THEMES } from '../theme';
import { GROUPS, GROUP_COLOR } from '../orbit';
import type { GroupName } from '../types';

export default function OrbitScreen() {
  const theme = THEMES[useStore((s) => s.theme)];
  const contacts = useStore((s) => s.contacts);
  const activeGroup = useStore((s) => s.activeGroup);
  const setFilter = useStore((s) => s.setFilter);
  const openAdd = useStore((s) => s.openAdd);
  const openContact = useStore((s) => s.openContact);
  const showToast = useStore((s) => s.showToast);
  const loadSample = useStore((s) => s.loadSampleOrbit);
  const openImport = useStore((s) => s.openImport);
  const openReach = useStore((s) => s.openReach);

  const list = Object.values(contacts);
  const driftCount = list.filter((c) => c.drift).length;
  const nudgeId = pickNudgeId(contacts);
  const nudge = nudgeId ? contacts[nudgeId] : null;
  const light = !theme.dark;

  const chips: ('All' | GroupName)[] = ['All', ...GROUPS.filter((g) => list.some((c) => c.group === g))];

  return (
    <View style={{ flex: 1 }}>
      <View style={styles.head}>
        <View>
          <OrbitLogo color={theme.accent} textColor={theme.text} />
          <Text style={{ color: theme.dim, fontSize: 13.5, marginTop: 3 }}>
            {driftCount} {driftCount === 1 ? 'person is' : 'people are'} drifting further away.
          </Text>
        </View>
        <Pressable style={[styles.iconbtn, { backgroundColor: theme.card, borderColor: theme.border2 }]} onPress={openAdd}>
          <Ionicons name="add" size={20} color={theme.text} />
        </Pressable>
      </View>

      <View>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.chiprow}>
          {chips.map((g) => {
            const on = activeGroup === g;
            return (
              <Pressable key={g} onPress={() => setFilter(g)}
                style={[styles.chip, { backgroundColor: on ? theme.accentSoft : theme.card, borderColor: on ? theme.accent : theme.border2 }]}>
                {g !== 'All' ? <View style={[styles.gdot, { backgroundColor: GROUP_COLOR[g] }]} /> : null}
                <Text style={{ color: on ? theme.accent : theme.dim, fontWeight: '600', fontSize: 12.5 }}>{g}</Text>
              </Pressable>
            );
          })}
        </ScrollView>
      </View>

      <OrbitMap contacts={list} onOpen={openContact} />

      {list.length === 0 ? (
        <View style={[styles.driftcard, { backgroundColor: light ? '#fff' : '#171b2c', borderColor: light ? theme.border : 'rgba(255,255,255,0.09)' }]}>
          <Text style={{ fontWeight: '800', fontSize: 16, color: light ? theme.text : '#fff' }}>Your orbit is empty</Text>
          <Text style={{ fontSize: 13, marginTop: 4, lineHeight: 18, color: light ? theme.dim : '#b9bed0' }}>
            Add the people who matter — they’ll orbit around you, gently drifting outward as time passes.
          </Text>
          <View style={{ flexDirection: 'row', gap: 10, marginTop: 14 }}>
            <Pressable onPress={openImport} style={[styles.emptyBtn, { flex: 1, backgroundColor: theme.accent2 }]}>
              <Ionicons name="people" size={16} color="#fff" />
              <Text style={{ color: '#fff', fontWeight: '700', fontSize: 13.5 }}>Import Contacts</Text>
            </Pressable>
            <Pressable onPress={openAdd} style={[styles.emptyBtn, styles.emptyGhost, { flex: 1, borderColor: theme.border2 }]}>
              <Ionicons name="add" size={17} color={theme.dim} />
              <Text style={{ color: theme.dim, fontWeight: '600', fontSize: 13.5 }}>Add manually</Text>
            </Pressable>
          </View>
          <Pressable onPress={() => { loadSample(); showToast('Loaded a sample orbit ✨'); }} style={{ marginTop: 10, alignSelf: 'flex-start' }} hitSlop={6}>
            <Text style={{ color: theme.faint, fontSize: 12.5, fontWeight: '600' }}>or see a sample orbit</Text>
          </Pressable>
        </View>
      ) : nudge ? (
        <View style={[styles.driftcard, { backgroundColor: light ? '#fff' : '#171b2c', borderColor: light ? theme.border : 'rgba(255,255,255,0.09)' }]}>
          <View style={{ flexDirection: 'row', gap: 11, alignItems: 'flex-start' }}>
            <Avatar grad={nudge.grad} initials={nudge.initials} photo={nudge.photo} size={38} cutout={light ? '#fff' : '#171b2c'} />
            <View style={{ flex: 1 }}>
              <Text style={{ fontWeight: '700', fontSize: 15, color: light ? theme.text : '#fff' }}>{nudge.name.split(' ')[0]} is drifting.</Text>
              <Text style={{ fontSize: 12.5, marginTop: 2, lineHeight: 17, color: light ? theme.dim : '#b9bed0' }}>
                It's been a while — a small hello would pull {nudge.name.split(' ')[0]} back in.
              </Text>
            </View>
            <Pressable hitSlop={8} onPress={() => showToast('We’ll keep them gently in view')}>
              <Text style={{ color: '#9aa0b6', fontSize: 18 }}>✕</Text>
            </Pressable>
          </View>
          <Pressable
            onPress={() => {
              const num = (nudge.phone ?? '').replace(/[^\d+*#]/g, '');
              if (!num) return openContact(nudge.id);
              openReach(nudge.id);
            }}
            style={[styles.qt, { backgroundColor: light ? theme.accentSoft : 'rgba(255,255,255,0.10)', borderColor: light ? 'rgba(108,92,231,0.28)' : 'rgba(255,255,255,0.12)' }]}>
            <Ionicons name="chatbubble-outline" size={16} color={light ? theme.accent2 : '#cdd1e2'} />
            <Text style={{ fontSize: 13.5, color: light ? theme.accent2 : '#cdd1e2' }}>Quick Text</Text>
          </Pressable>
        </View>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  head: { paddingHorizontal: 22, paddingTop: 8, paddingBottom: 4, flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start' },
  iconbtn: { width: 38, height: 38, borderRadius: 19, borderWidth: 1, alignItems: 'center', justifyContent: 'center' },
  chiprow: { gap: 8, paddingHorizontal: 20, paddingVertical: 4 },
  chip: { flexDirection: 'row', alignItems: 'center', borderWidth: 1, borderRadius: 999, paddingVertical: 7, paddingHorizontal: 13 },
  gdot: { width: 7, height: 7, borderRadius: 3.5, marginRight: 6 },
  driftcard: { marginHorizontal: 16, marginBottom: 12, borderRadius: 22, borderWidth: 1, padding: 16 },
  qt: { marginTop: 13, flexDirection: 'row', alignItems: 'center', gap: 10, borderWidth: 1, borderRadius: 13, paddingVertical: 11, paddingHorizontal: 14 },
  emptyBtn: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 6, borderRadius: 13, paddingVertical: 12, paddingHorizontal: 16 },
  emptyGhost: { borderWidth: 1, backgroundColor: 'transparent' },
});
