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

enum SleepMode: Int, CaseIterable {
  case allowSleep
  case keepMacAwake
  case keepScreenAwake

  var title: String {
    switch self {
    case .allowSleep: "Allow sleep"
    case .keepMacAwake: "Keep Mac awake, screen can sleep"
    case .keepScreenAwake: "Keep Mac and screen awake"
    }
  }
}

final class Controller: NSObject, NSMenuDelegate {
  private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  private var mode = SleepMode.allowSleep
  private var duration = 0
  private var deadline: Date?
  private var note: String?
  private var timer: Timer?
  private var caffeinate: Process?

  override init() {
    super.init()
    let menu = NSMenu()
    menu.delegate = self
    item.menu = menu
    apply(systemSleepDisabled() ? .keepMacAwake : .allowSleep)
  }

  private func apply(_ mode: SleepMode, hours: Int = 0, note: String? = nil) {
    if mode != .keepScreenAwake {
      if let caffeinate, caffeinate.isRunning { caffeinate.terminate() }
      caffeinate = nil
    }
    self.mode = mode
    duration = hours
    deadline = hours > 0 ? Date(timeIntervalSinceNow: Double(hours) * 3600) : nil
    self.note = note
    timer?.invalidate()
    timer =
      mode != .allowSleep
      ? Timer.scheduledTimer(
        timeInterval: 30, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
      : nil
    item.button?.image = NSImage(
      systemSymbolName: mode != .allowSleep ? "bolt.fill" : "bolt.slash",
      accessibilityDescription: mode.title)
  }

  private func switchTo(_ mode: SleepMode, hours: Int = 0, note: String? = nil) -> Bool {
    var newCaffeinate: Process?
    if mode == .keepScreenAwake && caffeinate?.isRunning != true {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
      process.arguments = ["-d", "-w", String(ProcessInfo.processInfo.processIdentifier)]
      do {
        try process.run()
      } catch {
        self.note = "Could not keep the screen awake"
        return false
      }
      newCaffeinate = process
    }
    guard setSleepDisabled(mode != .allowSleep) else {
      if let newCaffeinate, newCaffeinate.isRunning { newCaffeinate.terminate() }
      self.note = "Needs an administrator"
      return false
    }
    if let newCaffeinate { caffeinate = newCaffeinate }
    apply(mode, hours: hours, note: note)
    return true
  }

  @objc private func tick() {
    if let deadline, deadline <= Date() {
      _ = switchTo(.allowSleep)
    } else if battery(pmsetOutput: run(pmsetPath, ["-g", "batt"]).output)?.isLow == true {
      _ = switchTo(.allowSleep, note: "Off: battery at \(cutoffPercent)% or below")
    }
  }

  @objc private func choose(_ sender: NSMenuItem) {
    guard let mode = SleepMode(rawValue: sender.tag) else { return }
    if switchTo(mode), mode != .allowSleep { tick() }
  }

  @objc private func chooseDuration(_ sender: NSMenuItem) {
    if switchTo(mode, hours: sender.tag) { tick() }
  }

  @objc private func quit() {
    if mode == .allowSleep || switchTo(.allowSleep) { NSApp.terminate(nil) }
  }

  func menuNeedsUpdate(_ menu: NSMenu) {
    let disabled = systemSleepDisabled()
    if disabled != (mode != .allowSleep) { apply(disabled ? .keepMacAwake : .allowSleep) }
    if mode == .keepScreenAwake && caffeinate?.isRunning != true { apply(.keepMacAwake) }

    let status =
      if mode == .allowSleep {
        note ?? "Sleep allowed"
      } else if let deadline {
        note ?? "Awake until \(deadline.formatted(date: .omitted, time: .shortened))"
      } else {
        note ?? mode.title
      }
    menu.removeAllItems()
    menu.addItem(withTitle: status, action: nil, keyEquivalent: "")
    menu.addItem(.separator())
    for mode in SleepMode.allCases {
      let choice = menu.addItem(withTitle: mode.title, action: #selector(choose), keyEquivalent: "")
      choice.target = self
      choice.tag = mode.rawValue
      choice.state = mode == self.mode ? .on : .off
    }
    let durations = NSMenu()
    durations.autoenablesItems = false
    for hours in [0, 1, 2, 4, 8] {
      let title = hours == 0 ? "Until turned off" : "\(hours) \(hours == 1 ? "hour" : "hours")"
      let choice = durations.addItem(
        withTitle: title, action: #selector(chooseDuration), keyEquivalent: "")
      choice.target = self
      choice.tag = hours
      choice.state = hours == duration ? .on : .off
      choice.isEnabled = mode != .allowSleep
    }
    let durationItem = menu.addItem(withTitle: "Turn off after", action: nil, keyEquivalent: "")
    durationItem.submenu = durations
    durationItem.isEnabled = mode != .allowSleep
    menu.addItem(.separator())
    menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q").target = self
  }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let controller = Controller()
app.run()
