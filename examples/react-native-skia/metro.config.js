// Expo's default config handles the pnpm workspace: it watches the repository and resolves
// the package (an injected copy, see pnpm-workspace.yaml) with the example's dependencies.
const { getDefaultConfig } = require("expo/metro-config");

module.exports = getDefaultConfig(__dirname);
