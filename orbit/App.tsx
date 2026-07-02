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

export default function App() {
  const themeName = useStore((s) => s.theme);
  const theme = THEMES[themeName];
  const screen = useStore((s) => s.screen);
  const driftTick = useStore((s) => s.driftTick);

  // live drift: while you're on the orbit screen, people slowly drift outward over time
  useEffect(() => {
    const t = setInterval(() => {
      if (useStore.getState().screen === 'orbit') driftTick();
    }, 8000);
    return () => clearInterval(t);
  }, [driftTick]);

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
            <Toast />
          </SafeAreaView>
        </ErrorBoundary>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}

const styles = StyleSheet.create({ root: { flex: 1 } });
