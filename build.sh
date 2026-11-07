#!/bin/bash
# 构建 GPToggle.app。用法：./build.sh          只构建到 build/
#                         ./build.sh install  构建后安装到 ~/Applications 并启动
set -euo pipefail
cd "$(dirname "$0")"

APP="build/GPToggle.app"
SWIFTFLAGS=(-O -swift-version 5 -target arm64-apple-macos13.0)

rm -rf "$APP" build/AppIcon.iconset
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# 图标与预览图（与按钮共用 Artwork.swift）
swiftc "${SWIFTFLAGS[@]}" Sources/Artwork.swift Tools/render/main.swift -o build/render
build/render build
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

swiftc "${SWIFTFLAGS[@]}" Sources/*.swift -o "$APP/Contents/MacOS/GPToggle"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "✓ 已构建 $APP"

if [[ "${1:-}" == "install" ]]; then
  DEST="$HOME/Applications/GPToggle.app"
  # 先退出正在运行的旧版本
  pkill -x GPToggle 2>/dev/null || true
  for _ in {1..25}; do pgrep -x GPToggle >/dev/null || break; sleep 0.2; done
  mkdir -p "$HOME/Applications"
  rm -rf "$DEST"
  ditto "$APP" "$DEST"
  open "$DEST"
  echo "✓ 已安装并启动 $DEST"
fi
