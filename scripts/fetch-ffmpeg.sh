#!/bin/bash
set -euo pipefail

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

BIN_DIR="dist/bin"
mkdir -p "$BIN_DIR"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"

download() {
    local prefix="$1"
    local version attempt
    for version in 10 9 8; do
        for attempt in 1 2 3 4 5; do
            echo "下载 ${prefix} v${version}（第 ${attempt} 次尝试）"
            if curl -fsSL --max-time 600 -A "$UA" -o "$WORK_DIR/${prefix}.zip" "https://www.osxexperts.net/${prefix}${version}arm.zip"; then
                if unzip -tq "$WORK_DIR/${prefix}.zip" > /dev/null 2>&1; then
                    echo "${prefix} 下载成功"
                    return 0
                fi
                echo "压缩包校验失败，准备重试"
            fi
            sleep $((attempt * 5))
        done
    done
    echo "::error::下载 ${prefix} 失败"
    return 1
}

install_binary() {
    local prefix="$1" out="$2" binary
    rm -rf "$WORK_DIR/${prefix}.d"
    mkdir -p "$WORK_DIR/${prefix}.d"
    ditto -x -k "$WORK_DIR/${prefix}.zip" "$WORK_DIR/${prefix}.d"

    binary=$(find "$WORK_DIR/${prefix}.d" -type f -perm -111 | head -n 1 || true)
    if [ -z "$binary" ]; then
        binary=$(find "$WORK_DIR/${prefix}.d" -type f | head -n 1 || true)
    fi
    if [ -z "$binary" ]; then
        echo "::error::${prefix} 压缩包内未找到可执行文件"
        return 1
    fi

    cp "$binary" "$BIN_DIR/$out"
    chmod +x "$BIN_DIR/$out"

    if ! file "$BIN_DIR/$out" | grep -q arm64; then
        echo "::error::$out 不是 arm64 架构"
        return 1
    fi

    codesign --force --sign - "$BIN_DIR/$out"
    "$BIN_DIR/$out" -version | head -n 1
}

download ffmpeg
install_binary ffmpeg ffmpeg
sleep 5
download ffprobe
install_binary ffprobe ffprobe

echo "内置组件就绪:"
ls -la "$BIN_DIR"
