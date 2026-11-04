import Cocoa
import CoreGraphics

let KEYCODE_ENTER: CGKeyCode = 36

// アプリごとの変換ルール
//   chat:     Enter → Shift+Enter（改行）, Cmd+Enter → Enter（送信）
//   terminal: Enter はそのまま（IME確定・メニュー決定・シェルを壊さない）, Cmd+Enter → Option+Enter
//             （Claude Code 側の ~/.claude/keybindings.json で enter=改行 / meta+enter=送信 にする）
enum RemapMode: String {
    case chat
    case terminal
}

// 組み込みの既定（設定ファイルが無いときに使う）。bundle identifier の完全一致で判定する
// （表示名は変わることがある。例: Superset → Paradev）
let DEFAULT_APPS: [String: RemapMode] = [
    "com.anthropic.claudefordesktop": .chat,  // Claude
    "com.openai.codex": .chat,                // ChatGPT
    "com.naver.lineworks": .chat,             // LINE WORKS
    "com.microsoft.teams2": .chat,            // Microsoft Teams
    "com.superset.desktop": .terminal         // Paradev（旧名 Superset）
]

// 設定ファイル: ~/.config/claude-remap/apps.json
//   { "<bundle id>": "chat" | "terminal", ... }
// あればこちらだけを使う（既定とは合成しない）。壊れていれば既定にフォールバックする
let HOME = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
let CONFIG_PATH = "\(HOME)/.config/claude-remap/apps.json"

func loadTargetApps() -> (apps: [String: RemapMode], source: String) {
    guard FileManager.default.fileExists(atPath: CONFIG_PATH) else {
        return (DEFAULT_APPS, "組み込みの既定（\(CONFIG_PATH) なし）")
    }
    do {
        let data = try Data(contentsOf: URL(fileURLWithPath: CONFIG_PATH))
        guard let raw = try JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return (DEFAULT_APPS, "既定にフォールバック（\(CONFIG_PATH) の形式が {\"bundle id\": \"chat\"|\"terminal\"} でない）")
        }
        var apps: [String: RemapMode] = [:]
        for (bundleID, modeName) in raw {
            guard let mode = RemapMode(rawValue: modeName) else {
                return (DEFAULT_APPS, "既定にフォールバック（\(CONFIG_PATH): \(bundleID) のモード \"\(modeName)\" が不正。chat か terminal）")
            }
            apps[bundleID] = mode
        }
        if apps.isEmpty {
            return (apps, "\(CONFIG_PATH)（空＝何も変換しない）")
        }
        return (apps, CONFIG_PATH)
    } catch {
        return (DEFAULT_APPS, "既定にフォールバック（\(CONFIG_PATH) を読めない: \(error.localizedDescription)）")
    }
}

let (TARGET_APPS, TARGET_SOURCE) = loadTargetApps()

var eventTap: CFMachPort? = nil

func frontmostBundleID() -> String {
    return NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
}

func activeRemapMode() -> RemapMode? {
    return TARGET_APPS[frontmostBundleID()]
}

func isIMEEvent(_ event: CGEvent) -> Bool {
    return event.getIntegerValueField(.eventSourceStateID) != 1
}

func eventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // システムに EventTap を止められたら（タイムアウト・ユーザ入力）自分で再有効化する
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        log("EventTap が無効化されました (type=\(type.rawValue))。再有効化します。")
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passRetained(event)
    }

    guard type == .keyDown else {
        return Unmanaged.passRetained(event)
    }

    let keycode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
    let flags = event.flags

    let isCmd = flags.contains(.maskCommand)
    let isShift = flags.contains(.maskShift)

    guard keycode == KEYCODE_ENTER else {
        return Unmanaged.passRetained(event)
    }

    guard let mode = activeRemapMode() else {
        return Unmanaged.passRetained(event)
    }

    // 日本語入力の変換確定など、IMEが生成したEnterはそのまま通す
    if isIMEEvent(event) {
        return Unmanaged.passRetained(event)
    }

    if mode == .terminal {
        // ターミナル型: Enter 単体は一切触らない。Cmd+Enter → Option+Enter（ESC CR）に変換する
        if isCmd {
            event.flags = flags.subtracting(.maskCommand).union(.maskAlternate)
        }
        return Unmanaged.passRetained(event)
    }

    // Shift + Enter はもともと改行なのでそのまま通す
    if isShift && !isCmd {
        return Unmanaged.passRetained(event)
    }

    if isCmd {
        // Command + Enter → Commandフラグを外してEnter単体にする
        // 多くのチャットアプリではEnter単体が送信なので、これで送信になる
        event.flags = flags.subtracting(.maskCommand)
        return Unmanaged.passRetained(event)
    } else {
        // Enter単体 → Shift + Enter に変換して改行にする
        event.flags = flags.union(.maskShift)
        return Unmanaged.passRetained(event)
    }
}

func log(_ msg: String) {
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
    print("\(fmt.string(from: Date())) [INFO] \(msg)")
    fflush(stdout)
}

log("Enter Remapper 起動中...")
log("対象の読み込み元: \(TARGET_SOURCE)")
for (bundleID, mode) in TARGET_APPS.sorted(by: { $0.key < $1.key }) {
    log("  \(bundleID): \(mode.rawValue)")
}
log("chat: Enter → 改行 / Command+Enter → 送信 / IME確定 → 素通り")
log("terminal: Enter → そのまま / Command+Enter → Option+Enter")

let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)

guard let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: eventMask,
    callback: eventCallback,
    userInfo: nil
) else {
    fputs("""
EventTap の作成に失敗しました。
システム設定 → プライバシーとセキュリティ → アクセシビリティ
で ClaudeRemap.app を許可してください。

""", stderr)
    exit(1)
}
eventTap = tap

let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

log("起動完了。")

signal(SIGINT) { _ in
    print("\nシャットダウン中...")
    exit(0)
}

signal(SIGTERM) { _ in
    exit(0)
}

CFRunLoopRun()
