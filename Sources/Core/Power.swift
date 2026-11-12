public let pmsetPath = "/usr/bin/pmset"
public let cutoffPercent = 20

public struct Battery: Equatable, Sendable {
  public var onBattery: Bool
  public var percent: Int

  public init(onBattery: Bool, percent: Int) {
    self.onBattery = onBattery
    self.percent = percent
  }

  public var isLow: Bool { onBattery && percent <= cutoffPercent }
}

/// Reads the `SleepDisabled` line of `pmset -g`.
public func sleepDisabled(pmsetOutput: String) -> Bool {
  pmsetOutput.split(separator: "\n").contains { line in
    line.split(whereSeparator: \.isWhitespace) == ["SleepDisabled", "1"]
  }
}

/// Reads `pmset -g batt`. Returns nil when the Mac has no battery.
public func battery(pmsetOutput: String) -> Battery? {
  guard let end = pmsetOutput.firstIndex(of: "%") else { return nil }
  let digits = pmsetOutput[..<end].reversed().prefix(while: \.isNumber).reversed()
  guard let percent = Int(String(digits)) else { return nil }
  return Battery(onBattery: pmsetOutput.contains("'Battery Power'"), percent: percent)
}

/// The sudoers line that lets `user` flip the sleep switch, and nothing else, without a password.
public func sudoersRule(user: String) -> String {
  "\(user) ALL=(root) NOPASSWD: \(pmsetPath) -a disablesleep 0, \(pmsetPath) -a disablesleep 1"
}
