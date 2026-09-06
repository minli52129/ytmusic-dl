#!/bin/bash
set -euo pipefail

APP="build/Build/Products/Release/YTMusicDL.app"
if [ ! -d "$APP" ]; then
    echo "::error::未找到编译产物 $APP"
    exit 1
fi

mkdir -p "$APP/Contents/Resources/bin"
cp dist/yt-dlp dist/bin/ffmpeg dist/bin/ffprobe "$APP/Contents/Resources/bin/"
chmod 755 "$APP/Contents/Resources/bin/"*

for binary in yt-dlp ffmpeg ffprobe; do
    codesign --force --sign - "$APP/Contents/Resources/bin/$binary"
done

codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
echo "签名校验通过"

ditto -c -k --sequesterRsrc --keepParent "$APP" YTMusicDL-macos-arm64.zip
ls -lh YTMusicDL-macos-arm64.zip
