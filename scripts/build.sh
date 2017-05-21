cd $(dirname $0)/..

rm -f transitions.json &&
gl-transition-transform -d transitions -o transitions.json &&
echo "global.GLTransitions=" | cat - transitions.json > ./gl-transitions.js &&
echo "module.exports=" | cat - transitions.json > ./index.js
