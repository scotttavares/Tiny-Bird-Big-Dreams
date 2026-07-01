// Weekly "gravity report" — a single, gentle local notification that surfaces
// who's drifting to the edge of your orbit. No server, no push tokens: it's a
// repeating local notification scheduled on-device. Content is recomputed and
// rescheduled whenever the app opens so it stays fresh.
import * as Notifications from 'expo-notifications';
import { Platform } from 'react-native';
import type { Contact } from './types';

const WEEKLY_ID = 'orbit-weekly-gravity-report';
const ANDROID_CHANNEL = 'orbit-gentle';

// Foreground presentation: a quiet banner, no sound, no badge — on-brand
// (Orbit deliberately avoids red dots and noise).
Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true, // deprecated alias still required by the 0.29 types
    shouldPlaySound: false,
    shouldSetBadge: false,
    shouldShowBanner: true,
    shouldShowList: true,
  }),
});

function firstNames(contacts: Contact[]): string[] {
  return contacts.map((c) => c.name.trim().split(/\s+/)[0]);
}

function joinNames(names: string[]): string {
  if (names.length === 1) return names[0];
  if (names.length === 2) return `${names[0]} and ${names[1]}`;
  return `${names.slice(0, -1).join(', ')}, and ${names[names.length - 1]}`;
}

/** Build the report copy from current contacts, or a warm all-clear message. */
export function buildGravityReport(contacts: Contact[]): { title: string; body: string } {
  const drifters = contacts.filter((c) => c.drift && !c.snoozed).sort((a, b) => b.ring - a.ring);
  if (drifters.length === 0) {
    return {
      title: 'Your orbit is warm 🌤',
      body: "Everyone's close this week — nothing's drifting. Nice work keeping the people who matter near.",
    };
  }
  const names = joinNames(firstNames(drifters.slice(0, 3)));
  const n = drifters.length;
  if (n === 1) {
    return {
      title: 'A gentle pull 🌙',
      body: `${names} has drifted to the edge of your orbit. A quick hello would bring them back.`,
    };
  }
  return {
    title: 'Your weekly gravity 🌌',
    body: `${n} people are drifting outward — ${names} could use a hello. No rush, no guilt.`,
  };
}

async function ensurePermissions(): Promise<boolean> {
  if (Platform.OS === 'android') {
    await Notifications.setNotificationChannelAsync(ANDROID_CHANNEL, {
      name: 'Gentle nudges',
      importance: Notifications.AndroidImportance.DEFAULT,
      sound: null,
      enableVibrate: false,
    });
  }
  const current = await Notifications.getPermissionsAsync();
  if (current.granted || current.ios?.status === Notifications.IosAuthorizationStatus.PROVISIONAL) return true;
  if (!current.canAskAgain) return false;
  const req = await Notifications.requestPermissionsAsync();
  return req.granted || req.ios?.status === Notifications.IosAuthorizationStatus.PROVISIONAL;
}

/** True if the weekly report is currently scheduled. */
export async function isWeeklyScheduled(): Promise<boolean> {
  const all = await Notifications.getAllScheduledNotificationsAsync();
  return all.some((n) => n.identifier === WEEKLY_ID);
}

export async function cancelWeeklyReport(): Promise<void> {
  try {
    await Notifications.cancelScheduledNotificationAsync(WEEKLY_ID);
  } catch {
    // nothing scheduled — fine
  }
}

/**
 * Schedule (or reschedule) the weekly report for Sunday ~10am, at most once a
 * week. Returns false if the user declined notification permission.
 */
export async function scheduleWeeklyReport(contacts: Contact[]): Promise<boolean> {
  const ok = await ensurePermissions();
  if (!ok) return false;
  await cancelWeeklyReport();
  const { title, body } = buildGravityReport(contacts);
  await Notifications.scheduleNotificationAsync({
    identifier: WEEKLY_ID,
    content: {
      title,
      body,
      sound: false,
      ...(Platform.OS === 'android' ? { channelId: ANDROID_CHANNEL } : null),
    },
    trigger: {
      type: Notifications.SchedulableTriggerInputTypes.WEEKLY,
      weekday: 1, // 1 = Sunday
      hour: 10,
      minute: 0,
    },
  });
  return true;
}

/** Refresh the report copy if (and only if) it's already enabled. */
export async function refreshWeeklyReportIfEnabled(contacts: Contact[]): Promise<void> {
  if (await isWeeklyScheduled()) await scheduleWeeklyReport(contacts);
}
