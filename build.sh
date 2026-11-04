#!/bin/bash
# ClaudeRemap をビルドして ClaudeRemap.app を組み立てる
#   ./build.sh            → ./build/ClaudeRemap.app を作る
#   ./build.sh --install  → さらに ~/Applications/ClaudeRemap.app へ入れ替えて起動する
# 必要なもの: Xcode Command Line Tools（xcode-select --install）
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME=ClaudeRemap
BUILD=build
APP="$BUILD/$APP_NAME.app"

echo "[1/3] コンパイル"
mkdir -p "$BUILD"
swiftc -O -o "$BUILD/$APP_NAME" claude_enter_remap.swift

echo "[2/3] アプリバンドルを組み立て"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/Info.plist"
cp "$BUILD/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
codesign --force --sign - "$APP" >/dev/null 2>&1
codesign -v "$APP"
echo "    → $APP"

if [[ "${1:-}" == "--install" ]]; then
  DEST="$HOME/Applications/$APP_NAME.app"
  echo "[3/3] $DEST へ入れ替え"
  mkdir -p "$HOME/Applications"
  pkill -f "$APP_NAME.app/Contents/MacOS/$APP_NAME" 2>/dev/null || true
  sleep 1
  rm -rf "$DEST"
  cp -R "$APP" "$DEST"
  # 古いビルドの許可項目が残っていると新しいビルドが永久に未許可扱いになる（重複して溜まる）ので先に消す
  tccutil reset Accessibility com.local.claude-remap >/dev/null 2>&1 || true
  open "$DEST"
  sleep 3
  if pgrep -f "$DEST/Contents/MacOS/$APP_NAME" >/dev/null; then
    echo "    起動しました。アクセシビリティの許可ダイアログが出たら「システム設定を開く」→ $APP_NAME をオンにしてください。"
    echo "    （アプリは許可されるまで待機し、許可後そのまま動き始めます。再起動は不要です）"
    echo "    ※ 再ビルドのたびに許可が必要です（adhoc 署名のため。古い項目は自動で消してあります）"
  else
    echo "    起動していません。open \"$DEST\" で起動してください。"
  fi
else
  echo "[3/3] インストールは省略（--install を付けると ~/Applications へ入れ替えます）"
fi
