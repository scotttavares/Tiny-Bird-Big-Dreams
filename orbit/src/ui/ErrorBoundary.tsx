import React from 'react';
import { View, Text, ScrollView, StyleSheet } from 'react-native';

interface Props { children: React.ReactNode }
interface State { error: Error | null }

/**
 * Catches JavaScript render errors and shows them on-screen instead of a blank
 * crash. Native crashes bypass this, but if the app dies from a JS error this
 * turns "it just crashes" into a screenshot-able message that pinpoints the bug.
 */
export default class ErrorBoundary extends React.Component<Props, State> {
  state: State = { error: null };

  static getDerivedStateFromError(error: Error): State {
    return { error };
  }

  componentDidCatch(error: Error, info: React.ErrorInfo) {
    console.error('Orbit crashed:', error, info?.componentStack);
  }

  render() {
    const { error } = this.state;
    if (!error) return this.props.children;
    return (
      <View style={styles.wrap}>
        <Text style={styles.title}>Orbit hit a snag</Text>
        <Text style={styles.hint}>Screenshot this and send it over — it pinpoints the bug.</Text>
        <ScrollView style={styles.box} contentContainerStyle={{ padding: 12 }}>
          <Text selectable style={styles.mono}>
            {error.name}: {error.message}
            {'\n\n'}
            {error.stack}
          </Text>
        </ScrollView>
      </View>
    );
  }
}

const styles = StyleSheet.create({
  wrap: { flex: 1, backgroundColor: '#0A0C16', paddingHorizontal: 24, justifyContent: 'center' },
  title: { color: '#EDEFF7', fontSize: 20, fontWeight: '800', marginBottom: 8 },
  hint: { color: '#E8A24A', fontSize: 13, marginBottom: 16 },
  box: { maxHeight: 340, backgroundColor: '#141826', borderRadius: 14, borderWidth: 1, borderColor: 'rgba(255,255,255,0.11)' },
  mono: { color: '#b9bed0', fontSize: 11.5, fontFamily: 'Courier', lineHeight: 16 },
});
