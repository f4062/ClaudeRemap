#!/bin/bash
# ClaudeRemap インストーラ（ダブルクリックで実行）
#   1. 同じフォルダの ClaudeRemap.app を ~/Applications にコピー
#   2. 対象アプリの設定ファイルを置く
#   3. ログイン時に自動起動するよう登録
#   4. 起動し、アクセシビリティ許可のダイアログを出す
cd "$(dirname "$0")"
APP_NAME=ClaudeRemap
SRC_APP="./$APP_NAME.app"
DEST="$HOME/Applications/$APP_NAME.app"
CONF_DIR="$HOME/.config/claude-remap"

echo "=============================="
echo " $APP_NAME インストール"
echo "=============================="
if [ ! -d "$SRC_APP" ]; then
  echo "エラー: このファイルと同じフォルダに $APP_NAME.app がありません。zip を展開したフォルダごと置いてください。"
  read -n1 -s -r -p "何かキーを押すと閉じます。"; exit 1
fi

echo "[1/4] アプリを ~/Applications にコピー"
xattr -dr com.apple.quarantine "$SRC_APP" 2>/dev/null || true
mkdir -p "$HOME/Applications"
pkill -f "$APP_NAME.app/Contents/MacOS/$APP_NAME" 2>/dev/null || true
sleep 1
rm -rf "$DEST"
cp -R "$SRC_APP" "$DEST"
# 以前の版の許可項目が残っていると未許可扱いになるので消しておく（初回は何も起きない）
tccutil reset Accessibility com.local.claude-remap >/dev/null 2>&1 || true

echo "[2/4] 対象アプリの設定（LINE WORKS / ChatGPT / Claude / Microsoft Teams）"
mkdir -p "$CONF_DIR"
if [ -f "$CONF_DIR/apps.json" ]; then
  echo "    既に設定があるのでそのままにします: $CONF_DIR/apps.json"
else
  cat > "$CONF_DIR/apps.json" <<'JSON'
{
  "com.naver.lineworks": "chat",
  "com.openai.codex": "chat",
  "com.anthropic.claudefordesktop": "chat",
  "com.microsoft.teams2": "chat"
}
JSON
fi

echo "[3/4] ログイン時の自動起動を登録"
if osascript -e "tell application \"System Events\" to if not (exists login item \"$APP_NAME\") then make login item at end with properties {path:\"$DEST\", hidden:true}" >/dev/null 2>&1; then
  echo "    登録しました。"
else
  echo "    自動登録できませんでした。システム設定 → 一般 → ログイン項目 で $APP_NAME.app を追加してください。"
fi

echo "[4/4] 起動"
open "$DEST"
echo
echo "=============================="
echo " あと一歩です"
echo "=============================="
echo "画面に「$APP_NAME がアクセシビリティ機能を使用して…」というダイアログが出ます。"
echo "「システム設定を開く」を押し、一覧の $APP_NAME をオンにしてください（パスワードか Touch ID を求められます）。"
echo "オンにすると、そのまま使えるようになります（再起動は不要です）。"
echo
echo "確認: LINE WORKS のメッセージ欄で Enter を押して改行になれば完了です。送信は Cmd+Enter です。"
echo
read -n1 -s -r -p "この画面は閉じて構いません。何かキーを押すと閉じます。"
echo
osascript -e 'tell application "Terminal" to close (every window whose name contains "インストール.command")' >/dev/null 2>&1 || true
