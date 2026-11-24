#!/bin/sh
# Builds dist/Meth.app from the Swift package. No Xcode needed.
set -eu
cd "$(dirname "$0")/.."

swift build -c release --force-resolved-versions
app=dist/Meth.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/Meth "$app/Contents/MacOS/Meth"
cp assets/Meth.icns "$app/Contents/Resources/Meth.icns"
cat > "$app/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>Meth</string>
  <key>CFBundleIdentifier</key><string>local.meth</string>
  <key>CFBundleIconFile</key><string>Meth.icns</string>
  <key>CFBundleName</key><string>Meth</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
EOF
codesign --force --sign - "$app"
echo "Built $app"
