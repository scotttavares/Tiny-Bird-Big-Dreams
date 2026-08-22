import React, { useEffect, useMemo, useState } from 'react';
import { View, Text, Pressable, TextInput, FlatList, Image, ActivityIndicator, Linking, StyleSheet } from 'react-native';
import Animated, { FadeIn, FadeOut } from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import * as Contacts from 'expo-contacts';
import { Ionicons } from '@expo/vector-icons';
import { useStore } from '../store';
import { THEMES } from '../theme';
import { initialsOf, phoneKey, nameKey } from '../orbit';

type Row = { id: string; name: string; photo: string | null; phone: string | null };
type Phase = 'loading' | 'denied' | 'ready';

// Full-screen picker: request Contacts permission, list the address book, and
// let you multi-select people to drop into your orbit. Contacts stay on-device.
export default function ContactsImport() {
  const theme = THEMES[useStore((s) => s.theme)];
  // This screen is an absoluteFill overlay: absolute positioning ignores the
  // parent SafeAreaView's padding, so apply the insets ourselves or the
  // Cancel / title / Add header lands under the status bar & Dynamic Island.
  const insets = useSafeAreaInsets();
  const open = useStore((s) => s.sheet === 'import');
  const close = useStore((s) => s.closeSheet);
  const importContacts = useStore((s) => s.importContacts);
  const contacts = useStore((s) => s.contacts);
  const showToast = useStore((s) => s.showToast);

  const [phase, setPhase] = useState<Phase>('loading');
  const [rows, setRows] = useState<Row[]>([]);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [query, setQuery] = useState('');
  // iOS 18+ lets people grant access to only a hand-picked subset of contacts.
  // Without surfacing that, the list silently shows just those few and looks broken.
  const [limited, setLimited] = useState(false);
  const [reload, setReload] = useState(0);

  useEffect(() => {
    if (!open) return;
    let alive = true;
    setPhase('loading');
    setSelected(new Set());
    setQuery('');
    (async () => {
      try {
        const perm = await Contacts.requestPermissionsAsync();
        if (!alive) return;
        if (!perm.granted) {
          setPhase('denied');
          return;
        }
        setLimited(perm.accessPrivileges === 'limited');
        const { data } = await Contacts.getContactsAsync({
          fields: [Contacts.Fields.Name, Contacts.Fields.Image, Contacts.Fields.PhoneNumbers],
          sort: Contacts.SortTypes.FirstName,
        });
        if (!alive) return;
        const seen = new Set<string>();
        const list: Row[] = [];
        for (const c of data) {
          const name = (c.name ?? '').trim();
          if (!name) continue;
          const key = name.toLowerCase();
          if (seen.has(key)) continue; // collapse duplicate names
          seen.add(key);
          list.push({ id: c.id ?? key, name, photo: c.image?.uri ?? null, phone: c.phoneNumbers?.[0]?.number ?? null });
        }
        setRows(list);
        setPhase('ready');
      } catch {
        if (alive) setPhase('denied');
      }
    })();
    return () => {
      alive = false;
    };
  }, [open, reload]);

  // Let people widen a "limited" grant without leaving the screen. iOS 18's
  // picker is preferred when the installed expo-contacts exposes it; otherwise
  // fall back to the Settings deep link.
  const grantMore = async () => {
    const picker = (Contacts as unknown as { presentAccessPickerAsync?: () => Promise<unknown> }).presentAccessPickerAsync;
    if (typeof picker === 'function') {
      try {
        await picker();
        setReload((n) => n + 1); // re-read the address book with the new selection
        return;
      } catch {
        /* fall through to Settings */
      }
    }
    Linking.openSettings();
  };

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return q ? rows.filter((r) => r.name.toLowerCase().includes(q)) : rows;
  }, [rows, query]);

  // People already in the orbit — matched by phone or name — so we can flag them
  // as "In orbit" and stop them being added a second time.
  const existing = useMemo(() => {
    const phones = new Set<string>();
    const names = new Set<string>();
    for (const c of Object.values(contacts)) {
      const p = phoneKey(c.phone);
      if (p) phones.add(p);
      names.add(nameKey(c.name));
    }
    return { phones, names };
  }, [contacts]);
  const isAdded = (r: Row) => {
    const p = phoneKey(r.phone);
    return (!!p && existing.phones.has(p)) || existing.names.has(nameKey(r.name));
  };
  // Everyone the app can see is already in the orbit. Without a way out this
  // reads as "the importer is broken" — it's the dead end most people hit when
  // iOS only shared a couple of contacts.
  const nothingToAdd = phase === 'ready' && !query && rows.length > 0 && rows.every(isAdded);

  if (!open) return null;

  const toggle = (id: string) =>
    setSelected((prev) => {
      const n = new Set(prev);
      if (n.has(id)) n.delete(id);
      else n.add(id);
      return n;
    });

  const doImport = () => {
    const picked = rows.filter((r) => selected.has(r.id));
    if (!picked.length) return;
    const { added, skipped } = importContacts(picked.map((r) => ({ name: r.name, photo: r.photo, phone: r.phone })));
    if (added === 0) {
      showToast('Already in your orbit');
    } else if (skipped > 0) {
      showToast(`Added ${added} · ${skipped} already in your orbit`);
    } else {
      showToast(`Added ${added} ${added === 1 ? 'person' : 'people'} to your orbit ✨`);
    }
    close();
  };

  return (
    <Animated.View
      entering={FadeIn.duration(200)}
      exiting={FadeOut.duration(180)}
      style={[StyleSheet.absoluteFill, { backgroundColor: theme.bg, paddingTop: insets.top, paddingBottom: insets.bottom }]}
    >
      <View style={styles.head}>
        <Pressable onPress={close} hitSlop={10}>
          <Text style={{ color: theme.dim, fontSize: 15, fontWeight: '600' }}>Cancel</Text>
        </Pressable>
        <Text style={{ color: theme.text, fontSize: 16, fontWeight: '800' }}>Import Contacts</Text>
        <Pressable onPress={doImport} hitSlop={10} disabled={selected.size === 0}>
          <Text style={{ color: selected.size ? theme.accent : theme.faint, fontSize: 15, fontWeight: '700' }}>
            Add{selected.size ? ` ${selected.size}` : ''}
          </Text>
        </Pressable>
      </View>

      {phase === 'loading' ? (
        <View style={styles.center}>
          <ActivityIndicator color={theme.accent} />
        </View>
      ) : phase === 'denied' ? (
        <View style={styles.center}>
          <Ionicons name="lock-closed-outline" size={34} color={theme.dim} />
          <Text style={{ color: theme.text, fontWeight: '700', fontSize: 15, marginTop: 12 }}>Contacts access is off</Text>
          <Text style={{ color: theme.dim, fontSize: 13, textAlign: 'center', marginTop: 6, lineHeight: 19, paddingHorizontal: 30 }}>
            To pull people from your address book, allow Contacts for Orbit in Settings.
          </Text>
          <Pressable onPress={() => Linking.openSettings()} style={[styles.settingsBtn, { backgroundColor: theme.accent2 }]}>
            <Text style={{ color: '#fff', fontWeight: '700', fontSize: 14 }}>Open Settings</Text>
          </Pressable>
        </View>
      ) : nothingToAdd ? (
          <View style={styles.center}>
            <Ionicons name="people-outline" size={34} color={theme.dim} />
            <Text style={{ color: theme.text, fontWeight: '700', fontSize: 15, marginTop: 12, textAlign: 'center' }}>
              Everyone you’ve shared is already here
            </Text>
            <Text style={{ color: theme.dim, fontSize: 13, textAlign: 'center', marginTop: 6, lineHeight: 19, paddingHorizontal: 24 }}>
              {limited
                ? 'Orbit can only see the contacts you picked. Share more to add them.'
                : 'All of your contacts are already in your orbit. You can still add someone by hand.'}
            </Text>
            <Pressable onPress={limited ? grantMore : close} style={[styles.settingsBtn, { backgroundColor: theme.accent2 }]}>
              <Text style={{ color: '#fff', fontWeight: '700', fontSize: 14 }}>
                {limited ? 'Choose more contacts' : 'Done'}
              </Text>
            </Pressable>
            {limited ? (
              <Pressable onPress={() => Linking.openSettings()} style={{ marginTop: 14 }} hitSlop={8}>
                <Text style={{ color: theme.faint, fontSize: 12.5, fontWeight: '600' }}>or allow full access in Settings</Text>
              </Pressable>
            ) : null}
          </View>
        ) : (
        <>
          {limited ? (
            <Pressable onPress={grantMore} style={[styles.limitedBar, { backgroundColor: theme.accentSoft, borderColor: theme.accent }]}>
              <Ionicons name="information-circle-outline" size={17} color={theme.accent} />
              <Text style={{ flex: 1, color: theme.text, fontSize: 12.5, lineHeight: 17 }}>
                You’ve shared only some contacts with Orbit.
              </Text>
              <Text style={{ color: theme.accent, fontSize: 12.5, fontWeight: '700' }}>Choose more</Text>
            </Pressable>
          ) : null}
          <View style={{ paddingHorizontal: 18, paddingBottom: 8 }}>
            <TextInput
              value={query}
              onChangeText={setQuery}
              placeholder="Search contacts"
              placeholderTextColor={theme.faint}
              autoCorrect={false}
              style={[styles.search, { backgroundColor: theme.card, borderColor: theme.border2, color: theme.text }]}
            />
          </View>
          <FlatList
            data={filtered}
            keyExtractor={(r) => r.id}
            keyboardShouldPersistTaps="handled"
            contentContainerStyle={{ paddingHorizontal: 18, paddingBottom: 28 }}
            renderItem={({ item }) => {
              const added = isAdded(item);
              const on = selected.has(item.id);
              return (
                <Pressable
                  onPress={() => toggle(item.id)}
                  disabled={added}
                  style={[styles.row, { borderBottomColor: theme.border }, added ? { opacity: 0.5 } : null]}
                >
                  {item.photo ? (
                    <Image source={{ uri: item.photo }} style={styles.pic} />
                  ) : (
                    <View style={[styles.pic, styles.picFallback, { backgroundColor: theme.card }]}>
                      <Text style={{ color: theme.dim, fontWeight: '700' }}>{initialsOf(item.name)}</Text>
                    </View>
                  )}
                  <Text style={{ flex: 1, color: theme.text, fontSize: 15 }} numberOfLines={1}>{item.name}</Text>
                  {added ? (
                    <View style={[styles.pill, { borderColor: theme.border2 }]}>
                      <Text style={{ color: theme.dim, fontSize: 11.5, fontWeight: '700' }}>In orbit</Text>
                    </View>
                  ) : (
                    <View style={[styles.check, { borderColor: on ? theme.accent : theme.border2, backgroundColor: on ? theme.accent : 'transparent' }]}>
                      {on ? <Ionicons name="checkmark" size={15} color="#fff" /> : null}
                    </View>
                  )}
                </Pressable>
              );
            }}
            ListEmptyComponent={<Text style={{ color: theme.dim, textAlign: 'center', marginTop: 30 }}>No contacts found.</Text>}
          />
        </>
      )}
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  head: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 18, paddingTop: 12, paddingBottom: 12 },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 20 },
  limitedBar: { flexDirection: 'row', alignItems: 'center', gap: 9, marginHorizontal: 18, marginBottom: 10, paddingVertical: 11, paddingHorizontal: 13, borderRadius: 12, borderWidth: 1 },
  settingsBtn: { marginTop: 18, borderRadius: 13, paddingVertical: 12, paddingHorizontal: 22 },
  search: { borderWidth: 1, borderRadius: 12, paddingVertical: 11, paddingHorizontal: 14, fontSize: 15 },
  row: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingVertical: 10, borderBottomWidth: 1 },
  pic: { width: 40, height: 40, borderRadius: 20 },
  picFallback: { alignItems: 'center', justifyContent: 'center' },
  check: { width: 24, height: 24, borderRadius: 12, borderWidth: 1.5, alignItems: 'center', justifyContent: 'center' },
  pill: { borderWidth: 1, borderRadius: 999, paddingVertical: 4, paddingHorizontal: 10 },
});
