cd $(dirname $0)/..
set -e

remoteVersion=`npm show gl-transitions version`

rm -rf release/
cp -R scripts/release-skeleton release
cd release
npm version $remoteVersion --no-git-tag-version
npm version minor --no-git-tag-version
cd -

gl-transition-transform -d transitions -o release/gl-transitions.json
cd release
echo "window.GLTransitions=" | cat - gl-transitions.json > gl-transitions.js
echo "module.exports=" | cat - gl-transitions.json > index.js
mkdir transitions && cp ../transitions/*.glsl transitions/.
