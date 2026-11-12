import Core
import Testing

@Test func readsSleepDisabledFlag() {
  #expect(sleepDisabled(pmsetOutput: "System-wide power settings:\n SleepDisabled\t\t1\n"))
  #expect(!sleepDisabled(pmsetOutput: "System-wide power settings:\n SleepDisabled\t\t0\n"))
  #expect(!sleepDisabled(pmsetOutput: " sleep                1\n displaysleep         10\n"))
}

@Test func readsBatteryState() {
  let onPower = "Now drawing from 'AC Power'\n -InternalBattery-0 (id=1)\t38%; charging; 2:32\n"
  let onBattery = "Now drawing from 'Battery Power'\n -InternalBattery-0 (id=1)\t20%; discharging\n"
  #expect(battery(pmsetOutput: onPower) == Battery(onBattery: false, percent: 38))
  #expect(battery(pmsetOutput: onBattery) == Battery(onBattery: true, percent: 20))
  #expect(battery(pmsetOutput: "Now drawing from 'AC Power'\n") == nil)
}

@Test func cutsOffOnlyOnLowBattery() {
  #expect(Battery(onBattery: true, percent: 20).isLow)
  #expect(!Battery(onBattery: true, percent: 21).isLow)
  #expect(!Battery(onBattery: false, percent: 5).isLow)
}

@Test func sudoersRuleNamesOnlyTheTwoCommands() {
  #expect(
    sudoersRule(user: "ada")
      == "ada ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1"
  )
}
