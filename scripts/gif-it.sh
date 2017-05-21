userpwd=$PWD
cd $(dirname $0)/..
set -e

tname=$userpwd/$1
imgurkey=$IMGUR_KEY

tmpimgs="/tmp/gl-transition-imgs"
palette="/tmp/gl-transition-palette.png"
gif="/tmp/gl-transition.gif"

filters="scale=256:-1:flags=lanczos"

rm -rf $tmpimgs $palette $gif

gl-transition-render -t $tname --from scripts/in.jpg --to scripts/out.jpg -w 512 -h 400 -f 50 -o $tmpimgs

ffmpeg -v fatal -framerate 20 -i $tmpimgs/%d.png -vf "$filters,palettegen" -y $palette
ffmpeg -v fatal -framerate 20 -i $tmpimgs/%d.png -i $palette -lavfi "$filters [x]; [x][1:v] paletteuse" -y $gif

curl -sS -H "Authorization: Client-ID $imgurkey" -H 'Expect: ' -F "image=@$gif" https://api.imgur.com/3/image |
json data.link
