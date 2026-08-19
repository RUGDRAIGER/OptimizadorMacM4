#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="$(tr -d '[:space:]' < VERSION)"
REPO_NAME="OptimizadorMacM4"
ARTIFACT_PREFIX="${REPO_NAME}-${VERSION}"
DERIVED_DATA="$ROOT/build/DerivedData"
DIST="$ROOT/dist"
STAGING="$DIST/staging"
APP_NAME="OptimizadorMacM4.app"

echo "==> Compilando ${REPO_NAME} v${VERSION} (Release, arm64)..."

rm -rf "$DIST"
mkdir -p "$STAGING"

xcodebuild \
  -project "$ROOT/OptimizadorMacM4.xcodeproj" \
  -scheme OptimizadorMacM4 \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  -arch arm64 \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=YES \
  build

APP_PATH="$DERIVED_DATA/Build/Products/Release/$APP_NAME"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Error: no se encontró $APP_PATH" >&2
  exit 1
fi

cp -R "$APP_PATH" "$STAGING/"
ln -sf /Applications "$STAGING/Applications"

echo "==> Creando DMG..."
DMG_PATH="$DIST/${ARTIFACT_PREFIX}.dmg"
hdiutil create \
  -volname "$REPO_NAME" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

echo "==> Creando PKG..."
PKG_ROOT="$DIST/pkg-root"
PKG_SCRIPTS="$DIST/pkg-scripts"
rm -rf "$PKG_ROOT" "$PKG_SCRIPTS"
mkdir -p "$PKG_ROOT/Applications" "$PKG_SCRIPTS"

cp -R "$APP_PATH" "$PKG_ROOT/Applications/"

cat > "$PKG_SCRIPTS/preinstall" <<'EOF'
#!/bin/bash
MIN_MAJOR=14
OS_VERSION="$(sw_vers -productVersion)"
MAJOR="${OS_VERSION%%.*}"
if [[ "$MAJOR" -lt "$MIN_MAJOR" ]]; then
  echo "OptimizadorMacM4 requiere macOS ${MIN_MAJOR}.0 o superior (detectado: ${OS_VERSION})." >&2
  exit 1
fi
exit 0
EOF
chmod +x "$PKG_SCRIPTS/preinstall"

PKG_PATH="$DIST/${ARTIFACT_PREFIX}.pkg"
pkgbuild \
  --root "$PKG_ROOT" \
  --scripts "$PKG_SCRIPTS" \
  --identifier "com.optimizador.macm4.pkg" \
  --version "$VERSION" \
  --install-location "/" \
  "$PKG_PATH" >/dev/null

echo ""
echo "Build completado:"
echo "  App:  $APP_PATH"
echo "  DMG:  $DMG_PATH"
echo "  PKG:  $PKG_PATH"
