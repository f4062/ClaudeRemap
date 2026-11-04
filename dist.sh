#!/bin/bash
# 非エンジニア向け配布物を作る
#   ./dist.sh → dist/ClaudeRemap-配布用-YYYYMMDD.zip
#   中身: ClaudeRemap.app（universal: Apple Silicon + Intel, macOS 12 以降）/ インストール.command / 手順書.pdf / 手順書.html
set -euo pipefail
cd "$(dirname "$0")"
APP_NAME=ClaudeRemap
STAMP=$(date +%Y%m%d)
OUT="dist/$APP_NAME-配布用"
APP="$OUT/$APP_NAME.app"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

echo "[1/4] universal ビルド（arm64 + x86_64, macOS 12+）"
mkdir -p build; rm -rf "$OUT"; mkdir -p "$OUT"
swiftc -O -target arm64-apple-macos12.0  -o build/$APP_NAME-arm64  claude_enter_remap.swift
swiftc -O -target x86_64-apple-macos12.0 -o build/$APP_NAME-x86_64 claude_enter_remap.swift
lipo -create build/$APP_NAME-arm64 build/$APP_NAME-x86_64 -output build/$APP_NAME-universal

echo "[2/4] アプリバンドルを組み立て"
mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/Info.plist"
cp build/$APP_NAME-universal "$APP/Contents/MacOS/$APP_NAME"
codesign --force --sign - "$APP" >/dev/null 2>&1
codesign -v "$APP"

echo "[3/4] インストーラと手順書"
cp installer/インストール.command "$OUT/"
chmod +x "$OUT/インストール.command"
cp docs/手順書.html "$OUT/"
if [ -x "$CHROME" ]; then
  "$CHROME" --headless --disable-gpu --no-pdf-header-footer --print-to-pdf="$PWD/$OUT/手順書.pdf" "file://$PWD/docs/手順書.html" >/dev/null 2>&1 && echo "    手順書.pdf を作成" || echo "    PDF 化に失敗（HTML のみ同梱）"
else
  echo "    Chrome が無いので PDF は作らず HTML のみ同梱"
fi

echo "[4/4] zip"
ZIP="dist/$APP_NAME-配布用-$STAMP.zip"
rm -f "$ZIP"
(cd dist && ditto -c -k --sequesterRsrc --keepParent "$APP_NAME-配布用" "$APP_NAME-配布用-$STAMP.zip")
echo "    → $ZIP"
ls -la "$OUT"
