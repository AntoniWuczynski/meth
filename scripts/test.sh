#!/bin/sh
# Runs the tests. The framework flags are only needed without Xcode (Command Line Tools only).
set -eu
cd "$(dirname "$0")/.."
f=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
l=/Library/Developer/CommandLineTools/Library/Developer/usr/lib
swift test --force-resolved-versions -Xswiftc -F"$f" -Xlinker -F"$f" -Xlinker -rpath -Xlinker "$f" -Xlinker -rpath -Xlinker "$l"
