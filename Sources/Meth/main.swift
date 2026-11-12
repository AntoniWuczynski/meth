import AppKit
import Core

func run(_ tool: String, _ arguments: [String]) -> (status: Int32, output: String) {
  let process = Process()
  let pipe = Pipe()
  process.executableURL = URL(fileURLWithPath: tool)
  process.arguments = arguments
  process.standardOutput = pipe
  process.standardError = FileHandle.nullDevice
  do { try process.run() } catch { return (-1, "") }
  let data = pipe.fileHandleForReading.readDataToEndOfFile()
  process.waitUntilExit()
  return (process.terminationStatus, String(decoding: data, as: UTF8.self))
}

/// One-time grant: an administrator installs the sudoers rule for this user.
func installRule() -> Bool {
  let script = """
    f=$(/usr/bin/mktemp) && /usr/bin/printf '%s\\n' '\(sudoersRule(user: NSUserName()))' > "$f" \
    && /usr/sbin/visudo -cf "$f" \
    && /usr/bin/install -m 0440 -o root -g wheel "$f" /private/etc/sudoers.d/meth; \
    s=$?; /bin/rm -f "$f"; exit $s
    """
  let prompt = "Meth needs an administrator, once, to let it stop this Mac sleeping."
  return run(
    "/usr/bin/osascript",
    [
      "-e", "on run argv",
      "-e",
      "do shell script (item 1 of argv) with prompt \"\(prompt)\" with administrator privileges",
      "-e", "end run", script,
    ]
  ).status == 0
}

func setSleepDisabled(_ disabled: Bool) -> Bool {
  let arguments = ["-n", pmsetPath, "-a", "disablesleep", disabled ? "1" : "0"]
  if run("/usr/bin/sudo", arguments).status == 0 { return true }
  return installRule() && run("/usr/bin/sudo", arguments).status == 0
}

func systemSleepDisabled() -> Bool {
  sleepDisabled(pmsetOutput: run(pmsetPath, ["-g"]).output)
}

final class Controller: NSObject, NSMenuDelegate {
  private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  /// Menu tag of the active choice: -1 off, 0 on until turned off, n on for n hours.
  private var selection = -1
  private var deadline: Date?
  private var note: String?
  private var timer: Timer?

  override init() {
    super.init()
    let menu = NSMenu()
    menu.delegate = self
    item.menu = menu
    apply(systemSleepDisabled() ? 0 : -1)
  }

  private func apply(_ tag: Int, note: String? = nil) {
    selection = tag
    deadline = tag > 0 ? Date(timeIntervalSinceNow: Double(tag) * 3600) : nil
    self.note = note
    timer?.invalidate()
    timer =
      tag >= 0
      ? Timer.scheduledTimer(
        timeInterval: 30, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
      : nil
    item.button?.image = NSImage(
      systemSymbolName: tag >= 0 ? "bolt.fill" : "bolt.slash",
      accessibilityDescription: tag >= 0 ? "Staying awake" : "Sleep allowed")
  }

  private func switchTo(_ tag: Int, note: String? = nil) -> Bool {
    guard setSleepDisabled(tag >= 0) else {
      self.note = "Needs an administrator"
      return false
    }
    apply(tag, note: note)
    return true
  }

  @objc private func tick() {
    if let deadline, deadline <= Date() {
      _ = switchTo(-1)
    } else if battery(pmsetOutput: run(pmsetPath, ["-g", "batt"]).output)?.isLow == true {
      _ = switchTo(-1, note: "Off: battery at \(cutoffPercent)% or below")
    }
  }

  @objc private func choose(_ sender: NSMenuItem) {
    if switchTo(sender.tag), sender.tag >= 0 { tick() }
  }

  @objc private func quit() {
    if selection < 0 || switchTo(-1) { NSApp.terminate(nil) }
  }

  func menuNeedsUpdate(_ menu: NSMenu) {
    let disabled = systemSleepDisabled()
    if disabled != (selection >= 0) { apply(disabled ? 0 : -1) }

    let status =
      if selection < 0 {
        note ?? "Sleep allowed"
      } else if let deadline {
        "Awake until \(deadline.formatted(date: .omitted, time: .shortened))"
      } else {
        "Awake"
      }
    menu.removeAllItems()
    menu.addItem(withTitle: status, action: nil, keyEquivalent: "")
    menu.addItem(.separator())
    let choices = [
      ("Off", -1), ("On", 0), ("1 hour", 1), ("2 hours", 2), ("4 hours", 4), ("8 hours", 8),
    ]
    for (title, tag) in choices {
      let choice = menu.addItem(withTitle: title, action: #selector(choose), keyEquivalent: "")
      choice.target = self
      choice.tag = tag
      choice.state = tag == selection ? .on : .off
    }
    menu.addItem(.separator())
    menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q").target = self
  }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let controller = Controller()
app.run()
