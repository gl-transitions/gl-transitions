cd $(dirname $0)/../..
set -e

# Builds the gl-transitions package (packages/gl-transitions) into its dist/, the folder that is
# published (publishConfig.directory) and that the workspace links to.
DIST=packages/gl-transitions/dist
rm -rf $DIST
mkdir -p $DIST/sksl
cp packages/gl-transitions/README.md packages/gl-transitions/index.d.ts $DIST/
cp packages/gl-transitions/sksl/index.d.ts $DIST/sksl/
# The published manifest: without the build script and the publish directory.
node -e '
  const pkg = require("./packages/gl-transitions/package.json");
  delete pkg.scripts;
  delete pkg.publishConfig;
  require("fs").writeFileSync(process.argv[1], JSON.stringify(pkg, null, 2) + "\n");
' $DIST/package.json
# Each publish is the next minor version of the published one.
remoteVersion=`npm show gl-transitions version`
cd $DIST
npm version $remoteVersion --no-git-tag-version --allow-same-version > /dev/null
npm version minor --no-git-tag-version
cd -

node scripts/catalog/build-catalog.mjs -d transitions -o $DIST/gl-transitions.json
cd $DIST
echo "window.GLTransitions=" | cat - gl-transitions.json > gl-transitions.js
echo "module.exports=" | cat - gl-transitions.json > index.js
mkdir transitions && cp ../../../transitions/*.glsl transitions/.
cp ../../../LICENSE .
cd -

# Shader targets; see scripts/README.md. Set REFERENCE_RENDERS to a folder of GLSL reference
# renders (pnpm run render:references) to compare the SkSL and WGSL renders with them.
reports="$(mktemp -d)"
# The optional --refs argument, kept as one word even if the path has spaces.
set --
if [ -n "$REFERENCE_RENDERS" ]; then set -- --refs "$REFERENCE_RENDERS"; fi

# SkSL (Skia) versions of the transitions that compile
node scripts/targets/build-sksl.mjs --out $DIST/sksl "$@" --report "$reports/sksl.json"

# GLSL ES 3.00 versions, validated with glslang (downloaded on first use)
node scripts/targets/build-glsl3.mjs --out $DIST/glsl3 --report "$reports/glsl3.json"

# WGSL and MSL through SPIR-V (glslang + naga, built with cargo on first use)
node scripts/targets/build-wgsl-msl.mjs --wgsl $DIST/wgsl --msl $DIST/msl --layouts $DIST/layouts.json "$@" --report "$reports/wgsl-msl.json"

node scripts/targets/build-compatibility.mjs --out $DIST/compatibility.json --summary "$reports/summary.md" "$reports/sksl.json" "$reports/glsl3.json" "$reports/wgsl-msl.json"
if [ -n "$GITHUB_STEP_SUMMARY" ]; then cat "$reports/summary.md" >> "$GITHUB_STEP_SUMMARY"; fi
rm -rf "$reports"

# llms.txt, llms-full.txt and the Agent Skill; see scripts/README.md
node scripts/agents/build-agent-docs.mjs --out $DIST
