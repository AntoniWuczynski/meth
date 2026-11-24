# Meth

A menu-bar switch that stops this Mac sleeping, lid open or shut, so long-running work carries on while the screen is locked.

## Build and run

```sh
./scripts/build-app.sh   # writes dist/Meth.app
open dist/Meth.app
./scripts/test.sh        # tests for the pmset parsing
```

It needs the Swift toolchain in `.swift-version`. Xcode is not required.

To start Meth each time you log in, move `Meth.app` to Applications and add it under **System Settings → General → Login Items & Extensions → Open at Login**.

Automated tests cover power-setting and battery parsing. The menu modes, screen-sleep behaviour, timers and battery cut-off still need a manual walkthrough.

## Using it

Click the bolt in the menu bar and pick one of three modes.

- **Allow sleep** lets the Mac and screen sleep normally, so Codex jobs can pause.
- **Keep Mac awake, screen can sleep** keeps Codex and other jobs running while the screen can sleep.
- **Keep Mac and screen awake** keeps jobs running and prevents the screen sleeping too.

The awake modes apply to the whole Mac. They do not change the screen-lock settings or keep a closed laptop's built-in screen visible.

In either awake mode, use **Turn off after** to choose 1, 2, 4 or 8 hours, or **Until turned off**. Picking a mode clears the timer. Quit allows sleep and releases the screen assertion first.

The screen option uses `caffeinate -d -w` with the app's process identifier, so its assertion also ends if the app exits unexpectedly.

On battery at 20% or below it turns itself off and the Mac sleeps normally.

## The one-time administrator step

The first time you turn it on, macOS asks for an administrator's name and password. That installs `/private/etc/sudoers.d/meth`, which lets your account run these two commands without a password, and nothing else.

```
/usr/bin/pmset -a disablesleep 1
/usr/bin/pmset -a disablesleep 0
```

To undo it, an administrator runs `sudo rm /private/etc/sudoers.d/meth`.

## If it gets stuck on

The app reads the real setting each time you open the menu, so after a crash it shows **Keep Mac awake, screen can sleep** and you can select **Allow sleep**. From a terminal, `sudo -n /usr/bin/pmset -a disablesleep 0` does the same.

## Licence

Released under the [MIT licence](LICENSE).
