cd $(dirname $0)/../release
set -e

GIT_TAG=v`npm show gl-transitions version`
git tag $GIT_TAG
git push https://$GITHUB_TOKEN@github.com/gl-transitions/gl-transitions $GIT_TAG
