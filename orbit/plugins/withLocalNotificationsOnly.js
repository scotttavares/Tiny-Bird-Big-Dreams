// Orbit uses expo-notifications for LOCAL scheduled notifications only (the
// weekly gravity report). Because the package is installed, Expo's
// prebuild-config auto-applies expo-notifications' iOS plugin, which adds an
// `aps-environment` (remote push) entitlement. That would force the Push
// Notifications capability onto the App ID + provisioning profile at archive
// time — which we don't use and which would break App Store signing.
//
// This plugin strips that entitlement back out. Keep it LAST in app.json's
// plugins array so it runs after the auto-applied notifications mod.
const { withEntitlementsPlist } = require('expo/config-plugins');

module.exports = function withLocalNotificationsOnly(config) {
  return withEntitlementsPlist(config, (cfg) => {
    delete cfg.modResults['aps-environment'];
    return cfg;
  });
};
