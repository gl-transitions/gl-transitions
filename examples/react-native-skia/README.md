# React Native Skia example

An Expo app using [`@gl-transitions/react-native-skia`](../../packages/react-native-skia) from this repository, with the `gl-transitions` package built from it.

- **Playground** (default screen): pick a transition and watch it play, animated by Reanimated.
- **On-device checks** (`gltransitions://e2e`): for every transition, progress 0 must show `from` and 1 must show `to`, drawn through `<Transition>` by the native Skia build; then an animated progress and an animated image still loading. CI runs them on an Android emulator (`.github/workflows/react-native-skia-e2e.yml`).

## Run it

```sh
# From the repository root: build gl-transitions (release/) and the package (dist/)
pnpm install && pnpm run build && pnpm --filter @gl-transitions/react-native-skia run build

cd examples/react-native-skia
pnpm exec expo run:android   # or: pnpm exec expo run:ios
```

The example is in the pnpm workspace with its own versions of React Native Skia (the one Expo pins, with its native binaries) and React. It gets an injected copy of the package, whose imports resolve to these versions; building the package refreshes the copy (`syncInjectedDepsAfterScripts` in `pnpm-workspace.yaml`).

To run the checks on a connected device or emulator, as CI does:

```sh
pnpm exec expo prebuild --platform android
(cd android && ./gradlew assembleRelease)
e2e/run-android.sh   # installs the APK, opens gltransitions://e2e, waits for the result
```
