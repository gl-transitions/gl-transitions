cd $(dirname $0)/../..
set -e

remoteVersion=`npm show gl-transitions version`

rm -rf release/
cp -R scripts/npm-package/skeleton release
cd release
npm version $remoteVersion --no-git-tag-version
npm version minor --no-git-tag-version
cd -

node scripts/catalog/build-catalog.mjs -d transitions -o release/gl-transitions.json
cd release
echo "window.GLTransitions=" | cat - gl-transitions.json > gl-transitions.js
echo "module.exports=" | cat - gl-transitions.json > index.js
mkdir transitions && cp ../transitions/*.glsl transitions/.
cp ../LICENSE .
cd -

# Shader targets; see scripts/README.md. Set REFERENCE_RENDERS to a folder of GLSL reference
# renders (npm run render:references) to compare the SkSL and WGSL renders with them.
reports="$(mktemp -d)"
# The optional --refs argument, kept as one word even if the path has spaces.
set --
if [ -n "$REFERENCE_RENDERS" ]; then set -- --refs "$REFERENCE_RENDERS"; fi

# SkSL (Skia) versions of the transitions that compile
node scripts/targets/build-sksl.mjs --out release/sksl "$@" --report "$reports/sksl.json"

# GLSL ES 3.00 versions, validated with glslang (downloaded on first use)
node scripts/targets/build-glsl3.mjs --out release/glsl3 --report "$reports/glsl3.json"

# WGSL and MSL through SPIR-V (glslang + naga, built with cargo on first use)
node scripts/targets/build-wgsl-msl.mjs --wgsl release/wgsl --msl release/msl --layouts release/layouts.json "$@" --report "$reports/wgsl-msl.json"

node scripts/targets/build-compatibility.mjs --out release/compatibility.json --summary "$reports/summary.md" "$reports/sksl.json" "$reports/glsl3.json" "$reports/wgsl-msl.json"
if [ -n "$GITHUB_STEP_SUMMARY" ]; then cat "$reports/summary.md" >> "$GITHUB_STEP_SUMMARY"; fi
rm -rf "$reports"

# llms.txt, llms-full.txt and the Agent Skill; see scripts/README.md
node scripts/agents/build-agent-docs.mjs --out release
