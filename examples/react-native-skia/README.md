# React Native Skia example

An Expo app using [`@gl-transitions/react-native-skia`](../../packages/react-native-skia) from this repository, with the `gl-transitions` package built from it.

- **Playground** (default screen): pick a transition and watch it play, animated by Reanimated.
- **On-device checks** (`gltransitions://e2e`): for every transition, progress 0 must show `from` and 1 must show `to`, drawn through `<Transition>` by the native Skia build; then an animated progress and an animated image still loading. CI runs them on an Android emulator (`.github/workflows/react-native-skia-e2e.yml`).

## Run it

```sh
# From the repository root: build gl-transitions (release/) and the package (dist/)
npm ci && npm run build && npm run build -w @gl-transitions/react-native-skia

cd examples/react-native-skia
npm ci
npx expo run:android   # or: npx expo run:ios
```

The example is not an npm workspace: it has its own dependencies (the root installs a stub of React Native Skia's native binaries), and `metro.config.js` resolves the linked package's imports from here. Rebuild the package after changing it.

To run the checks on a connected device or emulator, as CI does:

```sh
npx expo prebuild --platform android
(cd android && ./gradlew assembleRelease)
e2e/run-android.sh   # installs the APK, opens gltransitions://e2e, waits for the result
```
