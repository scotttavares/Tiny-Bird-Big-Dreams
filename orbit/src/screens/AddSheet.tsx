import React, { useState } from 'react';
import { View, Text, Pressable, StyleSheet, Alert } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import Sheet from '../ui/Sheet';
import Avatar from '../ui/Avatar';
import { Field, TextField, Seg } from '../ui/form';
import { useStore } from '../store';
import { THEMES } from '../theme';
import { ORBIT_NAME, initialsOf, GROUPS, matchExisting } from '../orbit';
import type { GroupName } from '../types';

const RINGS: number[] = [1, 2, 3, 4, 5, 6];

export default function AddSheet() {
  const theme = THEMES[useStore((s) => s.theme)];
  const open = useStore((s) => s.sheet === 'add');
  const close = useStore((s) => s.closeSheet);
  const add = useStore((s) => s.addContact);
  const contacts = useStore((s) => s.contacts);
  const showToast = useStore((s) => s.showToast);
  const openImport = useStore((s) => s.openImport);

  const [name, setName] = useState('');
  const [role, setRole] = useState('');
  const [phone, setPhone] = useState('');
  const [group, setGroup] = useState<GroupName>('Friends');
  const [ring, setRing] = useState<number>(2);

  const submit = () => {
    const n = name.trim();
    if (!n) return;
    const commit = () => {
      add({ name: n, role, ring, group, phone: phone.trim() || null });
      showToast(`Added ${n.split(' ')[0]} to your orbit ✨`);
      setName(''); setRole(''); setPhone(''); setGroup('Friends'); setRing(2);
      close();
    };
    // Warn before the same person lands in the orbit twice — but let them
    // override in case it really is a different person with the same name.
    const dup = matchExisting(Object.values(contacts), { name: n, phone: phone.trim() || null });
    if (dup) {
      Alert.alert(
        'Already in your orbit',
        `${dup.name} is already someone you're keeping close. Add them again anyway?`,
        [
          { text: 'Cancel', style: 'cancel' },
          { text: 'Add anyway', style: 'destructive', onPress: commit },
        ],
      );
      return;
    }
    commit();
  };

  return (
    <Sheet visible={open} onClose={close}>
      <Text style={[styles.h3, { color: theme.text }]}>Add to your orbit</Text>
      <Text style={{ color: theme.dim, fontSize: 13, marginBottom: 14 }}>Pick who matters — Orbit keeps the gravity gentle.</Text>
      {/* The importer used to be reachable only from the empty-orbit card, which
          disappears once you have someone — so after the first person there was
          no way back to Contacts. Keep it one tap away from here too. */}
      <Pressable onPress={openImport} style={[styles.importBtn, { backgroundColor: theme.accentSoft, borderColor: theme.accent }]}>
        <Ionicons name="people" size={17} color={theme.accent} />
        <Text style={{ flex: 1, color: theme.accent, fontWeight: '700', fontSize: 14 }}>Import from Contacts</Text>
        <Ionicons name="chevron-forward" size={15} color={theme.accent} />
      </Pressable>
      <Text style={{ color: theme.faint, fontSize: 12, marginBottom: 14, textAlign: 'center' }}>or add someone by hand below</Text>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 13, marginBottom: 16 }}>
        <Avatar grad={'g-' + (name.length % 5)} initials={name ? initialsOf(name) : '?'} size={52} cutout={theme.bg2} />
        <View>
          <Text style={{ fontWeight: '700', color: theme.text, fontSize: 15 }}>{name || 'New contact'}</Text>
          <Text style={{ color: theme.dim, fontSize: 12.5 }}>{ORBIT_NAME[ring]}</Text>
        </View>
      </View>
      <Field label="Name"><TextField value={name} onChangeText={setName} placeholder="e.g. Priya" /></Field>
      <Field label="Relationship (optional)"><TextField value={role} onChangeText={setRole} placeholder="e.g. Old friend" /></Field>
      <Field label="Phone (optional)"><TextField value={phone} onChangeText={setPhone} placeholder="For Send a Text / Quick Call" keyboardType="phone-pad" /></Field>
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
  importBtn: { flexDirection: 'row', alignItems: 'center', gap: 10, borderWidth: 1, borderRadius: 14, paddingVertical: 13, paddingHorizontal: 14, marginBottom: 10 },
});
