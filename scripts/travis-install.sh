cd $(dirname $0)
set -e

wget http://johnvansickle.com/ffmpeg/builds/ffmpeg-git-64bit-static.tar.xz
tar xf ffmpeg-git-64bit-static.tar.xz
mkdir -p $HOME/bin
cp ffmpeg-git-*-static/{ffmpeg,ffprobe,ffserver} $HOME/bin
cp ffmpeg-git-*-static/{ffmpeg,ffprobe} $(pwd)
export PATH=$(pwd)/bin:$PATH

npm i
