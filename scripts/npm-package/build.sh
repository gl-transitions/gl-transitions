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

# SkSL (Skia) versions of the transitions that compile; see scripts/README.md
node scripts/targets/build-sksl.mjs --out release/sksl

# GLSL ES 3.00 versions, validated with glslang (downloaded on first use); see scripts/README.md
node scripts/targets/build-glsl3.mjs --out release/glsl3

# WGSL and MSL through SPIR-V (glslang + naga, built with cargo on first use); see scripts/README.md
node scripts/targets/build-wgsl-msl.mjs --wgsl release/wgsl --msl release/msl --layouts release/layouts.json

# llms.txt, llms-full.txt and the Agent Skill; see scripts/README.md
node scripts/agents/build-agent-docs.mjs --out release
