import React, { useEffect, useState } from 'react';
import { View, Text, Pressable, Linking, StyleSheet } from 'react-native';
import { Ionicons, FontAwesome5 } from '@expo/vector-icons';
import Sheet from '../ui/Sheet';
import Avatar from '../ui/Avatar';
import { useStore } from '../store';
import { THEMES } from '../theme';
import { cleanNumber, availableMessengers, type ReadyMessenger } from '../messengers';

// Bottom-sheet chooser for "Send a Text": lets the user pick which messenger to
// reach someone through — Messages, WhatsApp, Telegram, Signal, Viber — showing
// only the apps they actually have installed. Reaching out pulls the person back
// toward the center of the orbit.
export default function ReachSheet() {
  const theme = THEMES[useStore((s) => s.theme)];
  const open = useStore((s) => s.sheet === 'reach');
  const close = useStore((s) => s.closeSheet);
  const id = useStore((s) => s.reachId);
  const c = useStore((s) => (id ? s.contacts[id] : undefined));
  const pull = useStore((s) => s.pull);
  const showToast = useStore((s) => s.showToast);
  const [opts, setOpts] = useState<ReadyMessenger[] | null>(null);

  useEffect(() => {
    let alive = true;
    if (!open || !c) {
      setOpts(null);
      return;
    }
    const num = cleanNumber(c.phone);
    if (!num) {
      setOpts(null);
      return;
    }
    availableMessengers(num).then((list) => {
      if (!alive) return;
      if (list.length <= 1) {
        // Only Messages is available — skip the chooser and go straight there.
        pull(c.id);
        Linking.openURL(list[0]?.url ?? `sms:${num.raw}`).catch(() => showToast("Couldn't open Messages"));
        close();
      } else {
        setOpts(list);
      }
    });
    return () => {
      alive = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, id]);

  const go = (m: ReadyMessenger) => {
    if (!c) return;
    pull(c.id);
    close();
    Linking.openURL(m.url).catch(() => showToast(`Couldn't open ${m.label}`));
  };

  const visible = open && !!c && !!opts && opts.length > 1;
  if (!c) return null;

  return (
    <Sheet visible={visible} onClose={close}>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 13, marginBottom: 4 }}>
        <Avatar grad={c.grad} initials={c.initials} photo={c.photo} size={44} cutout={theme.bg2} fav={c.fav} />
        <View style={{ flex: 1 }}>
          <Text style={{ fontWeight: '700', fontSize: 16, color: theme.text }}>Text {c.name.split(' ')[0]}</Text>
          <Text style={{ color: theme.dim, fontSize: 12.5 }}>Choose how to reach them</Text>
        </View>
      </View>
      <View style={{ height: 10 }} />
      {(opts ?? []).map((m, i) => (
        <Pressable
          key={m.key}
          onPress={() => go(m)}
          style={[styles.row, { backgroundColor: theme.card, borderColor: theme.border }, i ? { marginTop: 10 } : null]}
        >
          <View style={[styles.tile, { backgroundColor: m.tint }]}>
            {m.iconSet === 'fa5' ? (
              <FontAwesome5 name={m.icon as any} brand size={19} color="#fff" />
            ) : (
              <Ionicons name={m.icon as any} size={20} color="#fff" />
            )}
          </View>
          <Text style={{ flex: 1, fontWeight: '700', fontSize: 15, color: theme.text }}>{m.label}</Text>
          <Ionicons name="chevron-forward" size={18} color={theme.faint} />
        </Pressable>
      ))}
    </Sheet>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center', gap: 13, borderWidth: 1, borderRadius: 16, padding: 12 },
  tile: { width: 40, height: 40, borderRadius: 11, alignItems: 'center', justifyContent: 'center' },
});
