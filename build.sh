#!/bin/bash
set -e

APP="YtWav"
BUNDLE_ID="com.ytwav.YtWav"

CONFIG="debug"
if [[ "$1" == "--release" || "$1" == "-r" ]]; then
    CONFIG="release"
fi

echo "Building $APP ($CONFIG)..."
swift build -c $CONFIG

echo "Creating app bundle..."
rm -rf "$APP.app"
mkdir -p "$APP.app/Contents/MacOS"
cp ".build/$CONFIG/$APP" "$APP.app/Contents/MacOS/"

cat > "$APP.app/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP</string>
    <key>CFBundleExecutable</key>
    <string>$APP</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

echo "Signing..."
codesign --force --sign - "$APP.app/Contents/MacOS/$APP"

echo ""
echo "Built $APP.app ($CONFIG). Run: open $APP.app"
