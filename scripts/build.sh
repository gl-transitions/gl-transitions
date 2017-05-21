cd $(dirname $0)/..
set -e

if [ "$TRAVIS_PULL_REQUEST" != "false" ]; then
  git diff --name-only HEAD...master | grep "transitions/.*\.glsl$" | node scripts/generate-review.js
fi

remoteVersion=`npm show gl-transitions version`

rm -rf release/
cp -R scripts/release-skeleton release
cd release
npm version $remoteVersion --no-git-tag-version
npm version minor --no-git-tag-version
cd -

gl-transition-transform -d transitions -o release/transitions.json
cd release
echo "window.GLTransitions=" | cat - transitions.json > gl-transitions.js
echo "module.exports=" | cat - transitions.json > index.js
