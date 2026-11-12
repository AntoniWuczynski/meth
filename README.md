# Meth

A menu-bar switch that stops this Mac sleeping, lid open or shut, so long-running work carries on while the screen is locked.

## Build and run

```sh
./scripts/build-app.sh   # writes dist/Meth.app
open dist/Meth.app
./scripts/test.sh        # tests for the pmset parsing
```

It needs the Swift toolchain in `.swift-version`. Xcode is not required.

## Using it

Click the bolt in the menu bar and pick Off, On, or a number of hours. The screen still dims and locks as usual. Quit turns it off first.

On battery at 20% or below it turns itself off and the Mac sleeps normally.

## The one-time administrator step

The first time you turn it on, macOS asks for an administrator's name and password. That installs `/private/etc/sudoers.d/meth`, which lets your account run these two commands without a password, and nothing else.

```
/usr/bin/pmset -a disablesleep 1
/usr/bin/pmset -a disablesleep 0
```

To undo it, an administrator runs `sudo rm /private/etc/sudoers.d/meth`.

## If it gets stuck on

The app reads the real setting each time you open the menu, so a crash shows up as On and you can switch it off there. From a terminal, `sudo -n /usr/bin/pmset -a disablesleep 0` does the same.
