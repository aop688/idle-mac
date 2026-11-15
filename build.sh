#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP=build/Idle.app
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# 仅编译 Apple Silicon (arm64)
swiftc -O -target arm64-apple-macos11.0 Sources/main.swift -o "$APP/Contents/MacOS/Idle"
strip -x "$APP/Contents/MacOS/Idle"
cp Info.plist "$APP/Contents/Info.plist"

# 用系统 SF Symbol 生成 App 图标；失败时不影响主体构建
if swiftc -O tools/make_icon.swift -o build/make_icon \
   && build/make_icon build/Idle.iconset \
   && iconutil -c icns build/Idle.iconset -o "$APP/Contents/Resources/Idle.icns"; then
  echo "App icon generated"
else
  echo "WARNING: icon generation failed, continuing without app icon"
fi

# ad-hoc 签名（无开发者账号也能在 Apple Silicon 上运行）
codesign --force --sign - "$APP"

ditto -c -k --keepParent "$APP" build/Idle.zip
echo "Done: build/Idle.zip"
