import 'react-native-gesture-handler';
import React, { useEffect } from 'react';
import { View, StyleSheet } from 'react-native';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import { useStore } from './src/store';
import { THEMES } from './src/theme';
import TabBar from './src/ui/TabBar';
import Toast from './src/ui/Toast';
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

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
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
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}

const styles = StyleSheet.create({ root: { flex: 1 } });
