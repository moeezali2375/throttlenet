#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-1.0.0}"
APP_NAME="ThrottleNet"
BUILD_DIR="$PROJECT_DIR/build"
ZIP_NAME="${APP_NAME}-v${VERSION}-macOS.zip"
ZIP_PATH="$BUILD_DIR/$ZIP_NAME"
CASK_FILE="$PROJECT_DIR/Casks/throttlenet.rb"

echo "=========================================="
echo "🚀 Packaging $APP_NAME v$VERSION Release"
echo "=========================================="

# 1. Build app bundle
"$PROJECT_DIR/Scripts/build_app.sh"

# 2. Package zip
echo "📦 Creating distribution archive: $ZIP_NAME..."
cd "$BUILD_DIR"
rm -f "$ZIP_NAME"
# Preserve symlinks and file permissions
zip -r -y -q "$ZIP_NAME" "${APP_NAME}.app"

# 3. Calculate SHA256
SHA256=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')
echo "🔒 Release SHA256 Checksum: $SHA256"

# 4. Update Cask
cat <<EOF > "$CASK_FILE"
cask "throttlenet" do
  version "$VERSION"
  sha256 "$SHA256"

  url "https://github.com/moeezali2375/throttlenet/releases/download/v#{version}/ThrottleNet-v#{version}-macOS.zip"
  name "ThrottleNet"
  desc "Native macOS per-process network monitor and bandwidth limiter"
  homepage "https://github.com/moeezali2375/throttlenet"

  depends_on macos: ">= :ventura"

  app "ThrottleNet.app"

  zap trash: [
    "~/Library/Preferences/com.throttlenet.app.plist",
    "~/Library/Application Support/ThrottleNet",
  ]
end
EOF

echo "✨ Updated Cask at $CASK_FILE"
echo ""
echo "🎉 Release Package Ready:"
echo "   File: $ZIP_PATH"
echo "   Size: $(ls -lh "$ZIP_PATH" | awk '{print $5}')"
echo "   SHA256: $SHA256"
echo ""
echo "Next steps to publish release:"
echo "1. git tag -a v$VERSION -m \"Release v$VERSION\""
echo "2. git push origin v$VERSION"
echo "3. gh release create v$VERSION \"$ZIP_PATH\" --title \"ThrottleNet v$VERSION\" --notes \"Release v$VERSION\""
