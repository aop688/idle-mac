#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP=build/Idle.app
rm -rf build
mkdir -p "$APP/Contents/MacOS"

# 分别编译 arm64 / x86_64，再合并为通用二进制
for arch in arm64 x86_64; do
  swiftc -O -target "$arch-apple-macos11.0" Sources/main.swift -o "build/Idle-$arch"
done
lipo -create -output "$APP/Contents/MacOS/Idle" build/Idle-arm64 build/Idle-x86_64
strip -x "$APP/Contents/MacOS/Idle"
cp Info.plist "$APP/Contents/Info.plist"

# ad-hoc 签名（无开发者账号也能在 Apple Silicon 上运行）
codesign --force --sign - "$APP"

ditto -c -k --keepParent "$APP" build/Idle.zip
echo "Done: build/Idle.zip"
