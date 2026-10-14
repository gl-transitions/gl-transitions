// The example is outside the npm workspaces: it uses the local package and the locally built
// gl-transitions release, with its own dependencies (the root installs a stub of React
// Native Skia's native binaries, and a second React would break hooks).
const path = require("node:path");
const { getDefaultConfig } = require("expo/metro-config");

const root = path.resolve(__dirname, "../..");
const escape = (p) => p.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const config = getDefaultConfig(__dirname);
config.watchFolders = [path.join(root, "packages/react-native-skia"), path.join(root, "release")];
// Files outside the example resolve their dependencies from the example's node_modules.
config.resolver.nodeModulesPaths = [path.join(__dirname, "node_modules")];
config.resolver.blockList = [
  ...[].concat(config.resolver.blockList ?? []),
  new RegExp(`^${escape(path.join(root, "node_modules"))}/.*`),
  new RegExp(`^${escape(path.join(root, "packages/react-native-skia/node_modules"))}/.*`),
];
module.exports = config;
