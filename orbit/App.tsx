import 'react-native-gesture-handler';
import React, { useEffect } from 'react';
import { View, StyleSheet, AppState } from 'react-native';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import { useStore } from './src/store';
import { refreshWeeklyReportIfEnabled } from './src/notifications';
import { syncWidget } from './src/widget';
import { THEMES } from './src/theme';
import OrbitLogo from './src/ui/OrbitLogo';
import TabBar from './src/ui/TabBar';
import Toast from './src/ui/Toast';
import ErrorBoundary from './src/ui/ErrorBoundary';
import OrbitScreen from './src/screens/OrbitScreen';
import TodayScreen from './src/screens/TodayScreen';
import PeopleScreen from './src/screens/PeopleScreen';
import ContactScreen from './src/screens/ContactScreen';
import SettingsScreen from './src/screens/SettingsScreen';
import Onboarding from './src/screens/Onboarding';
import AddSheet from './src/screens/AddSheet';
import ActionSheet from './src/screens/ActionSheet';
import ContactsImport from './src/screens/ContactsImport';
import ReachSheet from './src/screens/ReachSheet';
import LogSheet from './src/screens/LogSheet';

export default function App() {
  const themeName = useStore((s) => s.theme);
  const theme = THEMES[themeName];
  const screen = useStore((s) => s.screen);
  const hydrated = useStore((s) => s.hydrated);

  // keep the home-screen widget's snapshot in sync whenever the orbit changes
  useEffect(() => {
    let prev = useStore.getState().contacts;
    syncWidget(Object.values(prev), Date.now());
    return useStore.subscribe((state) => {
      if (state.contacts !== prev) {
        prev = state.contacts;
        syncWidget(Object.values(prev), Date.now());
      }
    });
  }, []);

  // on launch and every time the app returns to the foreground, refresh the
  // weekly gravity report copy (if enabled) and the widget with the latest orbit
  useEffect(() => {
    const refresh = () => {
      useStore.getState().settleDrift();
      const list = Object.values(useStore.getState().contacts);
      void refreshWeeklyReportIfEnabled(list);
      syncWidget(list, Date.now());
    };
    refresh();
    const sub = AppState.addEventListener('change', (s) => {
      if (s === 'active') refresh();
    });
    return () => sub.remove();
  }, []);

  // Wait for persisted contacts to load from disk before rendering, so a
  // returning user never sees an empty orbit flash before their people appear.
  if (!hydrated) {
    return (
      <GestureHandlerRootView style={{ flex: 1 }}>
        <View style={[styles.root, styles.splash, { backgroundColor: theme.bg }]}>
          <OrbitLogo color={theme.accent} textColor={theme.text} fontSize={30} />
        </View>
      </GestureHandlerRootView>
    );
  }

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
        <ErrorBoundary>
          <SafeAreaView style={[styles.root, { backgroundColor: theme.bg }]} edges={['top', 'bottom']}>
            <StatusBar style={themeName === 'dark' ? 'light' : 'dark'} />
            <View style={{ flex: 1 }}>
              {screen === 'orbit' && <OrbitScreen />}
              {screen === 'today' && <TodayScreen />}
              {screen === 'people' && <PeopleScreen />}
              {screen === 'contact' && <ContactScreen />}
              {screen === 'settings' && <SettingsScreen />}
            </View>
            {screen !== 'contact' && <TabBar />}
            <Onboarding />
            <AddSheet />
            <ActionSheet />
            <ContactsImport />
            <ReachSheet />
            <LogSheet />
            <Toast />
          </SafeAreaView>
        </ErrorBoundary>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  splash: { alignItems: 'center', justifyContent: 'center' },
});
