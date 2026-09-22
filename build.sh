#!/bin/bash
# Compila Caffè, assembla il bundle .app, firma ad-hoc e installa in ~/Applications.
# Uso: ./build.sh [--yes]   (--yes = sostituisce il vecchio Caffè senza chiedere)
set -euo pipefail
cd "$(dirname "$0")"

DEST_DIR="$HOME/Applications"
APP_NAME="Caffè"
OLD_APP="$DEST_DIR/$APP_NAME.app"
STAGED_APP=".build/$APP_NAME.app"

echo "▸ Compilo (Release)…"
swift build -c release

echo "▸ Assemblo il bundle…"
rm -rf "$STAGED_APP"
mkdir -p "$STAGED_APP/Contents/MacOS" "$STAGED_APP/Contents/Resources"
cp .build/release/Caffe "$STAGED_APP/Contents/MacOS/Caffe"
cp Info.plist "$STAGED_APP/Contents/Info.plist"

echo "▸ Genero l'icona del bundle (tazzina, nessuna scritta)…"
ICONSET="$STAGED_APP/Contents/Resources/AppIcon.iconset"
mkdir -p "$ICONSET"
for SIZE in 16 32 128 256 512; do
    swift make_icon.swift "$ICONSET/icon_${SIZE}x${SIZE}.png" "$SIZE"
    swift make_icon.swift "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" "$((SIZE * 2))"
done
iconutil -c icns "$ICONSET" -o "$STAGED_APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

echo "▸ Firmo (ad-hoc)…"
xattr -cr "$STAGED_APP" 2>/dev/null || true # detriti (FinderInfo ecc.) bloccano codesign
codesign --force --sign - "$STAGED_APP"

if [ -d "$OLD_APP" ]; then
    if pgrep -x Caffe >/dev/null; then
        echo "▸ Chiudo l'eventuale Caffè 2.0 in esecuzione…"
        pkill -x Caffe || true
        sleep 1
    fi
    if [ "${1:-}" = "--yes" ]; then
        ANSWER="s"
    else
        read -r -p "Sostituisco il vecchio Caffè in ~/Applications spostandolo nel Cestino? [s/N] " ANSWER
    fi
    if [ "$ANSWER" = "s" ] || [ "$ANSWER" = "S" ]; then
        osascript -e 'tell application "Finder" to delete POSIX file "'"$OLD_APP"'"' >/dev/null
    else
        echo "✋ Installazione annullata: il vecchio Caffè resta al suo posto."
        exit 1
    fi
fi

echo "▸ Installo in ~/Applications…"
rm -rf "$OLD_APP"
cp -R "$STAGED_APP" "$OLD_APP"
xattr -dr com.apple.quarantine "$OLD_APP" 2>/dev/null || true
echo "✅ Fatto: $OLD_APP"
echo "   Avvia con: open \"$OLD_APP\""
