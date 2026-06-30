import React, { useState } from 'react';
import { View, Text, Pressable, ScrollView, TextInput, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import Avatar from '../ui/Avatar';
import { useStore } from '../store';
import { THEMES } from '../theme';
import { roleLine, GROUP_COLOR } from '../orbit';
import type { Contact } from '../types';

export default function PeopleScreen() {
  const theme = THEMES[useStore((s) => s.theme)];
  const contacts = useStore((s) => s.contacts);
  const openContact = useStore((s) => s.openContact);
  const openAdd = useStore((s) => s.openAdd);
  const [q, setQ] = useState('');

  const list = Object.values(contacts).filter((c) => (c.name + ' ' + c.role).toLowerCase().includes(q.toLowerCase()));
  const drifting = list.filter((c) => c.drift);
  const inorbit = list.filter((c) => !c.drift);
  const card = { backgroundColor: theme.card, borderColor: theme.border };

  const Row = ({ c, i }: { c: Contact; i: number }) => (
    <Pressable onPress={() => openContact(c.id)} style={[styles.row, i > 0 ? { borderTopWidth: 1, borderTopColor: theme.border } : null]}>
      <Avatar grad={c.grad} initials={c.initials} photo={c.photo} size={42} cutout={theme.card} fav={c.fav} />
      <View style={{ flex: 1 }}>
        <View style={{ flexDirection: 'row', alignItems: 'center' }}>
          <View style={[styles.gdot, { backgroundColor: GROUP_COLOR[c.group] }]} />
          <Text style={{ fontWeight: '600', fontSize: 14, color: theme.text }}>{c.fav ? '⭐ ' : ''}{c.name}</Text>
        </View>
        <Text style={{ color: theme.dim, fontSize: 12, marginTop: 2 }}>{roleLine(c)}</Text>
      </View>
      <Text style={{ color: c.drift ? theme.drift : theme.dim, fontSize: 13, fontWeight: c.drift ? '700' : '400' }}>
        {c.drift ? 'drifting' : 'in orbit'}
      </Text>
      <Ionicons name="chevron-forward" size={16} color={theme.dim} />
    </Pressable>
  );

  const Group = ({ title, arr }: { title: string; arr: Contact[] }) =>
    arr.length ? (
      <>
        <Text style={[styles.sect, { color: theme.faint }]}>{title}</Text>
        <View style={[styles.cardList, card]}>{arr.map((c, i) => <Row key={c.id} c={c} i={i} />)}</View>
      </>
    ) : null;

  return (
    <View style={{ flex: 1 }}>
      <View style={styles.head}>
        <View>
          <Text style={[styles.h1, { color: theme.text }]}>People</Text>
          <Text style={{ color: theme.dim, fontSize: 13.5, marginTop: 3 }}>{Object.keys(contacts).length} people in your orbit</Text>
        </View>
        <Pressable style={[styles.iconbtn, { backgroundColor: theme.card, borderColor: theme.border2 }]} onPress={openAdd}>
          <Ionicons name="add" size={20} color={theme.text} />
        </Pressable>
      </View>
      <View style={[styles.search, { backgroundColor: theme.card2, borderColor: theme.border }]}>
        <Ionicons name="search" size={17} color={theme.faint} />
        <TextInput value={q} onChangeText={setQ} placeholder="Search your orbit" placeholderTextColor={theme.faint}
          style={{ flex: 1, color: theme.text, fontSize: 14, padding: 0 }} />
      </View>
      <ScrollView contentContainerStyle={{ padding: 20, paddingTop: 2 }} showsVerticalScrollIndicator={false}>
        <Group title="DRIFTING" arr={drifting} />
        <Group title="IN ORBIT" arr={inorbit} />
        {list.length === 0 ? <Text style={{ textAlign: 'center', color: theme.dim, padding: 30 }}>No one matches “{q}”.</Text> : null}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  head: { paddingHorizontal: 20, paddingTop: 8, paddingBottom: 4, flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start' },
  h1: { fontSize: 30, fontWeight: '800', letterSpacing: -0.5 },
  iconbtn: { width: 38, height: 38, borderRadius: 19, borderWidth: 1, alignItems: 'center', justifyContent: 'center' },
  search: { marginHorizontal: 20, marginTop: 4, marginBottom: 8, flexDirection: 'row', alignItems: 'center', gap: 9, borderWidth: 1, borderRadius: 13, paddingVertical: 11, paddingHorizontal: 13 },
  sect: { fontSize: 11, fontWeight: '700', letterSpacing: 1, marginTop: 14, marginBottom: 9, marginLeft: 4 },
  cardList: { borderRadius: 18, borderWidth: 1, overflow: 'hidden' },
  row: { flexDirection: 'row', alignItems: 'center', gap: 13, padding: 14 },
  gdot: { width: 7, height: 7, borderRadius: 3.5, marginRight: 6 },
});
