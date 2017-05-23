cd $(dirname $0)/../release
set -e

GIT_TAG=v`node -p "require('./package.json').version"`
git tag $GIT_TAG
git push origin $GIT_TAG
