#!/bin/bash
set -euo pipefail

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

BIN_DIR="dist/bin"
mkdir -p "$BIN_DIR"

fetch() {
    local prefix="$1"
    local out="$2"
    local ok=1
    for version in 11 10 9 8; do
        if curl -fsSL --retry 3 -o "$WORK_DIR/${prefix}.zip" "https://www.osxexperts.net/${prefix}${version}arm.zip"; then
            ok=0
            break
        fi
    done
    if [ "$ok" -ne 0 ]; then
        echo "::error::下载 ${prefix} 失败"
        exit 1
    fi

    mkdir -p "$WORK_DIR/${prefix}.d"
    ditto -x -k "$WORK_DIR/${prefix}.zip" "$WORK_DIR/${prefix}.d"

    local binary
    binary=$(find "$WORK_DIR/${prefix}.d" -type f -perm -111 | head -n 1)
    if [ -z "$binary" ]; then
        binary=$(find "$WORK_DIR/${prefix}.d" -type f | head -n 1)
    fi
    if [ -z "$binary" ]; then
        echo "::error::${prefix} 压缩包内未找到可执行文件"
        exit 1
    fi

    cp "$binary" "$BIN_DIR/$out"
    chmod +x "$BIN_DIR/$out"

    if ! file "$BIN_DIR/$out" | grep -q arm64; then
        echo "::error::$out 不是 arm64 架构"
        exit 1
    fi

    codesign --force --sign - "$BIN_DIR/$out"
    "$BIN_DIR/$out" -version | head -n 1
}

fetch ffmpeg ffmpeg
fetch ffprobe ffprobe

echo "内置组件就绪:"
ls -la "$BIN_DIR"
