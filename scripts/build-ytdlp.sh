#!/bin/bash
set -euo pipefail

VERSION="${1:-}"

if [ -n "$VERSION" ]; then
    PIP_SPEC="yt-dlp[default]==${VERSION}"
else
    PIP_SPEC="yt-dlp[default]"
fi

python -m pip install -U "$PIP_SPEC" pyinstaller

MAIN_FILE=$(python -c "import yt_dlp, os; print(os.path.join(os.path.dirname(yt_dlp.__file__), '__main__.py'))")

pyinstaller --onefile --clean --noconfirm --name yt-dlp --collect-submodules yt_dlp "$MAIN_FILE"

codesign --force --sign - dist/yt-dlp
chmod +x dist/yt-dlp

echo "yt-dlp 版本: $(./dist/yt-dlp --version)"
file dist/yt-dlp
