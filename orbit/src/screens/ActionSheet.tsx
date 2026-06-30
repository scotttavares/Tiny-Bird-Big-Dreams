import React from 'react';
import { View, Text, Pressable, StyleSheet } from 'react-native';
import Sheet from '../ui/Sheet';
import Avatar from '../ui/Avatar';
import { Field, TextField, Seg } from '../ui/form';
import { useStore } from '../store';
import { THEMES } from '../theme';
import { roleLine, GROUPS } from '../orbit';
import type { Speed } from '../types';

const RINGS: number[] = [1, 2, 3, 4, 5, 6];
const SPEEDS: Speed[] = ['Gentle', 'Steady', 'Brisk'];

export default function ActionSheet() {
  const theme = THEMES[useStore((s) => s.theme)];
  const open = useStore((s) => s.sheet === 'action');
  const close = useStore((s) => s.closeSheet);
  const id = useStore((s) => s.currentId);
  const c = useStore((s) => (id ? s.contacts[id] : undefined));
  const moveOrbit = useStore((s) => s.moveOrbit);
  const setSpeed = useStore((s) => s.setSpeed);
  const setGroup = useStore((s) => s.setGroup);
  const setNote = useStore((s) => s.setNote);
  const toggleFav = useStore((s) => s.toggleFav);
  const toggleAnchor = useStore((s) => s.toggleAnchor);
  const toggleSnooze = useStore((s) => s.toggleSnooze);
  const removeContact = useStore((s) => s.removeContact);
  const showToast = useStore((s) => s.showToast);

  if (!c) return null;
  const card = { backgroundColor: theme.card, borderColor: theme.border };

  const Toggle = ({ icon, title, sub, on, onPress, top }: { icon: string; title: string; sub: string; on?: boolean; onPress: () => void; top?: boolean }) => (
    <Pressable style={[styles.row, top ? { borderTopWidth: 1, borderTopColor: theme.border } : null]} onPress={onPress}>
      <Text style={{ fontSize: 17, width: 34, textAlign: 'center' }}>{icon}</Text>
      <View style={{ flex: 1 }}>
        <Text style={{ fontWeight: '600', fontSize: 14, color: theme.text }}>{title}</Text>
        <Text style={{ color: theme.dim, fontSize: 12, marginTop: 2 }}>{sub}</Text>
      </View>
      {on ? <Text style={{ color: theme.accent, fontWeight: '800' }}>✓</Text> : null}
    </Pressable>
  );

  return (
    <Sheet visible={open} onClose={close}>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 13, marginBottom: 14 }}>
        <Avatar grad={c.grad} initials={c.initials} photo={c.photo} size={46} cutout={theme.bg2} fav={c.fav} />
        <View style={{ flex: 1 }}>
          <Text style={{ fontWeight: '700', fontSize: 16, color: theme.text }}>{c.name}</Text>
          <Text style={{ color: theme.dim, fontSize: 12.5 }}>{roleLine(c)}</Text>
        </View>
      </View>

      <View style={[styles.cardList, card]}>
        <Toggle icon="⭐" title="Favorite" sub="Keep them front and center" on={c.fav} onPress={() => toggleFav(c.id)} />
        <Toggle icon="🧲" title="Keep close" sub="Anchor them so they never drift" on={c.anchored} onPress={() => toggleAnchor(c.id)} top />
        <Toggle icon="🔕" title="Snooze nudges" sub="Stop reminders about them" on={c.snoozed} onPress={() => toggleSnooze(c.id)} top />
      </View>

      <View style={{ height: 16 }} />
      <Field label="Move to orbit"><Seg options={RINGS} value={c.ring} onChange={(n) => { moveOrbit(c.id, n); showToast('Moved'); }} /></Field>
      <Field label="Drift speed — for this person"><Seg options={SPEEDS} value={c.speed ?? 'Steady'} onChange={(sp) => setSpeed(c.id, sp)} /></Field>
      <Field label="Constellation"><Seg options={GROUPS} value={c.group} onChange={(g) => setGroup(c.id, g)} /></Field>
      <Field label="Private note">
        <TextField value={c.note ?? ''} onChangeText={(t) => setNote(c.id, t)} placeholder="e.g. his dog Biscuit · kids start school in fall…" multiline style={{ minHeight: 64, textAlignVertical: 'top' }} />
      </Field>

      <Pressable style={[styles.cardList, card, styles.danger]} onPress={() => { const n = c.name.split(' ')[0]; removeContact(c.id); showToast(`${n} drifted away 🌙`); }}>
        <Text style={{ fontSize: 17, width: 34, textAlign: 'center' }}>🌙</Text>
        <View style={{ flex: 1 }}>
          <Text style={{ fontWeight: '600', fontSize: 14, color: theme.danger }}>Let them go</Text>
          <Text style={{ color: theme.dim, fontSize: 12, marginTop: 2 }}>Gently remove them from your orbit</Text>
        </View>
      </Pressable>
    </Sheet>
  );
}

const styles = StyleSheet.create({
  cardList: { borderRadius: 18, borderWidth: 1, overflow: 'hidden' },
  row: { flexDirection: 'row', alignItems: 'center', gap: 13, padding: 14 },
  danger: { marginTop: 12, flexDirection: 'row', alignItems: 'center', gap: 13, padding: 14 },
});
