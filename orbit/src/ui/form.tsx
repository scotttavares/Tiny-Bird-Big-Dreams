import React from 'react';
import { View, Text, TextInput, Pressable, StyleSheet } from 'react-native';
import { THEMES } from '../theme';
import { useStore } from '../store';

export function Field({ label, children }: { label: string; children: React.ReactNode }) {
  const theme = THEMES[useStore((s) => s.theme)];
  return (
    <View style={{ marginBottom: 14 }}>
      <Text style={[styles.label, { color: theme.faint }]}>{label}</Text>
      {children}
    </View>
  );
}

export function TextField(props: React.ComponentProps<typeof TextInput>) {
  const theme = THEMES[useStore((s) => s.theme)];
  return (
    <TextInput
      placeholderTextColor={theme.faint}
      {...props}
      style={[styles.input, { backgroundColor: theme.card, borderColor: theme.border2, color: theme.text }, props.style]}
    />
  );
}

export function Seg<T extends string | number>({ options, value, onChange, labelOf }: {
  options: readonly T[]; value: T; onChange: (v: T) => void; labelOf?: (v: T) => string;
}) {
  const theme = THEMES[useStore((s) => s.theme)];
  return (
    <View style={{ flexDirection: 'row', gap: 8 }}>
      {options.map((o) => {
        const on = o === value;
        return (
          <Pressable key={String(o)} onPress={() => onChange(o)}
            style={[styles.seg, { backgroundColor: on ? theme.accentSoft : theme.card, borderColor: on ? theme.accent : theme.border2 }]}>
            <Text style={{ color: on ? theme.accent : theme.dim, fontWeight: '600', fontSize: 13 }}>{labelOf ? labelOf(o) : String(o)}</Text>
          </Pressable>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  label: { fontSize: 12, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 0.8, marginBottom: 7, marginLeft: 2 },
  input: { borderWidth: 1, borderRadius: 13, paddingVertical: 13, paddingHorizontal: 14, fontSize: 14.5 },
  seg: { flex: 1, borderWidth: 1, borderRadius: 13, paddingVertical: 12, alignItems: 'center' },
});
