import React, { useState } from 'react';
import { View, Text, Pressable, StyleSheet } from 'react-native';
import Sheet from '../ui/Sheet';
import Avatar from '../ui/Avatar';
import { TextField } from '../ui/form';
import { useStore } from '../store';
import { THEMES } from '../theme';

// Quick ways to describe how you reconnected. Picking one logs it and pulls the
// person back toward the center; the note field handles anything else.
const PRESETS: { emoji: string; label: string }[] = [
  { emoji: '☕', label: 'Met up' },
  { emoji: '📞', label: 'Talked on the phone' },
  { emoji: '👋', label: 'Ran into them' },
  { emoji: '💬', label: 'Chatted online' },
  { emoji: '🎉', label: 'Celebrated something' },
];

// Sheet shown when logging an external interaction — asks what it actually was
// before recording it, so the timeline reflects real moments.
export default function LogSheet() {
  const theme = THEMES[useStore((s) => s.theme)];
  const open = useStore((s) => s.sheet === 'log');
  const close = useStore((s) => s.closeSheet);
  const id = useStore((s) => s.logId);
  const c = useStore((s) => (id ? s.contacts[id] : undefined));
  const logInteraction = useStore((s) => s.logInteraction);
  const showToast = useStore((s) => s.showToast);
  const [custom, setCustom] = useState('');

  const log = (label: string) => {
    if (!c) return;
    logInteraction(c.id, label);
    setCustom('');
    close();
    showToast(`Logged with ${c.name.split(' ')[0]} — pulled closer ✨`);
  };

  if (!c) return null;

  return (
    <Sheet visible={open} onClose={close}>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 13, marginBottom: 6 }}>
        <Avatar grad={c.grad} initials={c.initials} photo={c.photo} size={44} cutout={theme.bg2} fav={c.fav} />
        <View style={{ flex: 1 }}>
          <Text style={{ fontWeight: '700', fontSize: 16, color: theme.text }}>How did you connect?</Text>
          <Text style={{ color: theme.dim, fontSize: 12.5 }}>With {c.name.split(' ')[0]}</Text>
        </View>
      </View>
      <View style={{ height: 8 }} />

      {PRESETS.map((p, i) => (
        <Pressable
          key={p.label}
          onPress={() => log(p.label)}
          style={[styles.row, { backgroundColor: theme.card, borderColor: theme.border }, i ? { marginTop: 9 } : null]}
        >
          <Text style={{ fontSize: 18, width: 30, textAlign: 'center' }}>{p.emoji}</Text>
          <Text style={{ flex: 1, fontWeight: '600', fontSize: 14.5, color: theme.text }}>{p.label}</Text>
        </Pressable>
      ))}

      <View style={{ height: 16 }} />
      <TextField
        value={custom}
        onChangeText={setCustom}
        placeholder="Or describe it…"
        returnKeyType="done"
        onSubmitEditing={() => custom.trim() && log(custom.trim())}
      />
      <Pressable
        onPress={() => custom.trim() && log(custom.trim())}
        style={[styles.logBtn, { backgroundColor: custom.trim() ? theme.accent2 : theme.card, borderColor: theme.border2 }]}
      >
        <Text style={{ color: custom.trim() ? '#fff' : theme.faint, fontWeight: '700', fontSize: 14.5 }}>Log it</Text>
      </Pressable>
    </Sheet>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center', gap: 11, borderWidth: 1, borderRadius: 15, paddingVertical: 13, paddingHorizontal: 13 },
  logBtn: { marginTop: 10, borderWidth: 1, borderRadius: 14, paddingVertical: 13, alignItems: 'center' },
});
