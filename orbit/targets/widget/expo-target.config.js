/** @type {import('@bacons/apple-targets/app.plugin').ConfigFunction} */
module.exports = (config) => ({
  type: 'widget',
  name: 'OrbitWidget',
  // → com.tinybirdbigdreams.orbit.widget
  bundleIdentifier: '.widget',
  // Explicitly grant the same App Group as the app so the widget can read the
  // shared snapshot written by src/widget.ts. Mirrors app.json when present.
  entitlements: {
    'com.apple.security.application-groups':
      config.ios?.entitlements?.['com.apple.security.application-groups'] ?? [
        'group.com.tinybirdbigdreams.orbit',
      ],
  },
});
