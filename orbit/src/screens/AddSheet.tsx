import React, { useState } from 'react';
import { View, Text, Pressable, StyleSheet } from 'react-native';
import Sheet from '../ui/Sheet';
import Avatar from '../ui/Avatar';
import { Field, TextField, Seg } from '../ui/form';
import { useStore } from '../store';
import { THEMES } from '../theme';
import { ORBIT_NAME, initialsOf, GROUPS } from '../orbit';
import type { GroupName } from '../types';

const RINGS: number[] = [1, 2, 3, 4, 5, 6];

export default function AddSheet() {
  const theme = THEMES[useStore((s) => s.theme)];
  const open = useStore((s) => s.sheet === 'add');
  const close = useStore((s) => s.closeSheet);
  const add = useStore((s) => s.addContact);
  const showToast = useStore((s) => s.showToast);

  const [name, setName] = useState('');
  const [role, setRole] = useState('');
  const [group, setGroup] = useState<GroupName>('Friends');
  const [ring, setRing] = useState<number>(2);

  const submit = () => {
    const n = name.trim();
    if (!n) return;
    add({ name: n, role, ring, group });
    showToast(`Added ${n.split(' ')[0]} to your orbit ✨`);
    setName(''); setRole(''); setGroup('Friends'); setRing(2);
    close();
  };

  return (
    <Sheet visible={open} onClose={close}>
      <Text style={[styles.h3, { color: theme.text }]}>Add to your orbit</Text>
      <Text style={{ color: theme.dim, fontSize: 13, marginBottom: 16 }}>Pick who matters — Orbit keeps the gravity gentle.</Text>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 13, marginBottom: 16 }}>
        <Avatar grad={'g-' + (name.length % 5)} initials={name ? initialsOf(name) : '?'} size={52} cutout={theme.bg2} />
        <View>
          <Text style={{ fontWeight: '700', color: theme.text, fontSize: 15 }}>{name || 'New contact'}</Text>
          <Text style={{ color: theme.dim, fontSize: 12.5 }}>{ORBIT_NAME[ring]}</Text>
        </View>
      </View>
      <Field label="Name"><TextField value={name} onChangeText={setName} placeholder="e.g. Priya" /></Field>
      <Field label="Relationship (optional)"><TextField value={role} onChangeText={setRole} placeholder="e.g. Old friend" /></Field>
      <Field label="Constellation"><Seg options={GROUPS} value={group} onChange={setGroup} /></Field>
      <Field label="Starting orbit — 1 closest · 6 farthest"><Seg options={RINGS} value={ring} onChange={setRing} /></Field>
      <Pressable style={[styles.cta, { backgroundColor: theme.accent2 }]} onPress={submit}>
        <Text style={{ color: '#fff', fontWeight: '700', fontSize: 15 }}>Add to Orbit</Text>
      </Pressable>
    </Sheet>
  );
}

const styles = StyleSheet.create({
  h3: { fontSize: 19, fontWeight: '800', marginBottom: 2 },
  cta: { marginTop: 6, borderRadius: 16, paddingVertical: 16, alignItems: 'center' },
});
