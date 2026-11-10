# ClaudeRemap

macOS で、チャットアプリの **Enter を改行、Cmd+Enter を送信** に入れ替える常駐アプリです。
Claude / ChatGPT / LINE WORKS / Microsoft Teams などの「Enter＝送信」アプリを、Slack 風の操作感にします。

- 対象アプリは設定ファイルで選べます（再ビルド不要）
- 日本語入力（IME）の変換確定の Enter はそのまま通します
- メニューバーには出ません（バックグラウンド常駐）

## 仕組み

アクセシビリティ権限で macOS のキー入力を監視し（CGEventTap）、最前面アプリが対象のときだけ Enter キーの修飾キーを書き換えます。

| モード | Enter | Cmd+Enter | 使うアプリ |
|---|---|---|---|
| `chat` | Shift+Enter（改行） | Enter（送信） | Claude, ChatGPT, LINE WORKS, Teams など「Enter 送信・Shift+Enter 改行」のチャットアプリ |

ターミナル系アプリ（Paradev など）は対象外です（「既知の制限」を参照）。

## 必要なもの

- macOS（Apple Silicon / Intel どちらも可。自分の Mac でビルドするのでその Mac 用のバイナリになります）
- Xcode Command Line Tools（無ければ `xcode-select --install`）

## インストール

```bash
git clone <このリポジトリ>
cd ClaudeRemap
./build.sh --install
```

1. `~/Applications/ClaudeRemap.app` が作られ、起動します。
2. 初回は「ClaudeRemap がアクセシビリティ機能を使用して…」のダイアログが出るので、「システム設定を開く」→ 一覧の `ClaudeRemap` をオンにします。アプリは許可されるまで待機し、許可後そのまま動き始めます（起動し直し不要）。
3. ログイン時に自動起動したい場合は、システム設定 → 一般 → ログイン項目 に `ClaudeRemap.app` を追加します。

自分でビルドするので Gatekeeper（「開発元を確認できません」）には引っかかりません。

## 対象アプリを選ぶ

設定ファイル `~/.config/claude-remap/apps.json` を置くと、**そのファイルの内容だけ**が対象になります（組み込みの既定とは合成しません）。
無ければ組み込みの既定（下の4つ）が使われます。

```bash
mkdir -p ~/.config/claude-remap
cp apps.example.json ~/.config/claude-remap/apps.json
```

```json
{
  "com.anthropic.claudefordesktop": "chat",
  "com.openai.codex": "chat",
  "com.naver.lineworks": "chat",
  "com.microsoft.teams2": "chat"
}
```

| bundle identifier | アプリ |
|---|---|
| `com.anthropic.claudefordesktop` | Claude |
| `com.openai.codex` | ChatGPT |
| `com.naver.lineworks` | LINE WORKS |
| `com.microsoft.teams2` | Microsoft Teams |

### 例: LINE WORKS だけでいい

```json
{ "com.naver.lineworks": "chat" }
```

### 例: Claude と ChatGPT だけでいい

```json
{
  "com.anthropic.claudefordesktop": "chat",
  "com.openai.codex": "chat"
}
```

変更後はアプリを再起動してください（`pkill ClaudeRemap; open ~/Applications/ClaudeRemap.app`）。再ビルドもアクセシビリティの付け直しも不要です。

### 別のアプリを足したい

bundle identifier は次で調べられます。

```bash
defaults read "/Applications/アプリ名.app/Contents/Info.plist" CFBundleIdentifier
```

「Enter で送信・Shift+Enter で改行」のアプリを `chat` で足します。
ブラウザは URL バーや検索欄まで改行になるので対象に入れないでください。

## ログを見る

ターミナルから直接起動すると、読み込んだ設定と対象アプリが表示されます。

```bash
pkill ClaudeRemap; ~/Applications/ClaudeRemap.app/Contents/MacOS/ClaudeRemap
```

アクセシビリティ許可が無いと「EventTap の作成に失敗しました」と出て終了します。
（ターミナルアプリ自体にアクセシビリティ許可が無い場合も同じ表示になります。その場合はログイン項目か `open` から起動して使ってください。）

## 非エンジニアに渡す（ビルド済みアプリ＋手順書）

```bash
./dist.sh
```

`dist/ClaudeRemap-配布用-YYYYMMDD.zip` ができます。中身は次のとおりで、受け取った人は zip を展開して `インストール.command` をダブルクリックするだけです。

| ファイル | 内容 |
|---|---|
| `ClaudeRemap.app` | universal ビルド（Apple Silicon / Intel 両対応、macOS 12 以降） |
| `インストール.command` | `~/Applications` へコピー、対象アプリの設定（LINE WORKS / ChatGPT / Claude / Teams）、ログイン項目の登録、起動まで自動で行う |
| `手順書.pdf` / `手順書.html` | 受け取った人向けの手順（Gatekeeper の「このまま開く」、アクセシビリティ許可、動作確認、FAQ） |

- 署名していないので、受け取った側は初回に Gatekeeper の「このまま開く」操作が1回必要です（手順書に記載）。Apple Developer Program に加入していれば Developer ID で署名＋公証してこの手順をなくせます。
- 対象アプリを変えたい場合は `installer/インストール.command` 内の JSON を編集してから `./dist.sh` を実行します。

## 再ビルドしたとき

adhoc 署名のため、ビルドごとに別のアプリとして扱われ、**アクセシビリティ許可を付け直す**必要があります。
`./build.sh --install` は古い許可項目を自動で消してから起動するので、出てきたダイアログで「システム設定を開く」→ `ClaudeRemap` をオンにするだけです。アプリは許可されるまで数秒ごとに自分を起動し直して判定し、許可後そのまま動き始めます。

もし「スイッチはオンなのに効かない」状態になったら、古い項目が残っています。次で消してからアプリを起動し直してください。

```bash
tccutil reset Accessibility com.local.claude-remap
open ~/Applications/ClaudeRemap.app
```

## アンインストール

1. システム設定 → ログイン項目 から `ClaudeRemap` を外す
2. `pkill ClaudeRemap`
3. `~/Applications/ClaudeRemap.app` と `~/.config/claude-remap/` を削除
4. システム設定 → アクセシビリティ の一覧から `ClaudeRemap` を「−」で外す

## 既知の制限

- `chat` モードの変換確定は、IME が「Shift+Enter でも確定する」ことに頼っています。Apple 標準 IME と Claude / ChatGPT / LINE WORKS / Teams の組み合わせでは問題ありませんが、別の IME やアプリでは変換確定時に改行が入ることがあります。その場合はそのアプリを対象から外してください。
- ターミナル系アプリ（Paradev など）は対象にしないでください。ClaudeRemap には Enter が入力欄・メニュー・シェルのどこで押されたか分からないので、IME 確定・メニュー決定・シェルの Enter まで改行になります。
- ターミナル上の Claude Code も対象外です（以前の `terminal` モードは廃止しました）。Claude Code の既定（Enter＝送信、Shift+Enter＝改行）のまま使ってください。`~/.claude/keybindings.json` で Enter＝改行にする方法もありますが、次の理由で勧めません。
  - この設定は Claude Code 全体に効き、ターミナルごとに分けられません。
  - Paradev は Shift+Enter と Cmd+Enter をどちらも同じ信号（`ESC CR`）にして送るので、「Shift+Enter＝改行・Cmd+Enter＝送信」を両立できません。
  - Enter を改行にすると、スラッシュコマンドの候補を選んで Enter を押しても実行されなくなります。
  - Claude Code の質問（AskUserQuestion）の自由記述欄は「Enter＝送信」で固定されていて、変えられません。
- テンキーの Enter（keycode 76）は対象外です。

## ファイル構成

| ファイル | 内容 |
|---|---|
| `claude_enter_remap.swift` | 本体（単一ファイル） |
| `Info.plist` | アプリバンドルの設定（`LSUIElement` でメニューバー非表示） |
| `build.sh` | ビルドと組み立て。`--install` で `~/Applications` へ入れ替え |
| `apps.example.json` | 対象アプリ設定の例（既定と同じ内容） |
| `dist.sh` | 非エンジニア向け配布 zip の作成（universal ビルド＋インストーラ＋手順書 PDF） |
| `installer/インストール.command` | 配布 zip に入れるダブルクリック用インストーラ |
| `docs/手順書.html` | 配布 zip に入れる手順書の原稿（dist.sh が PDF 化） |
