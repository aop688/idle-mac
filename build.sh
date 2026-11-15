#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP=build/Idle.app
rm -rf build
mkdir -p "$APP/Contents/MacOS"

# 仅编译 Apple Silicon (arm64)
swiftc -O -target arm64-apple-macos11.0 Sources/main.swift -o "$APP/Contents/MacOS/Idle"
strip -x "$APP/Contents/MacOS/Idle"
cp Info.plist "$APP/Contents/Info.plist"

# ad-hoc 签名（无开发者账号也能在 Apple Silicon 上运行）
codesign --force --sign - "$APP"

ditto -c -k --keepParent "$APP" build/Idle.zip
echo "Done: build/Idle.zip"
