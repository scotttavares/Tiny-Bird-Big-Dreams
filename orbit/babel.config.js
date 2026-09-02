module.exports = function (api) {
  api.cache(true);
  // babel-preset-expo (SDK 52+) AUTOMATICALLY adds react-native-reanimated/plugin
  // when the package is installed. Do NOT add it manually — a second copy
  // double-transforms every worklet and hard-crashes the app at launch. That
  // double-application was the launch crash.
  return {
    presets: ['babel-preset-expo'],
  };
};
