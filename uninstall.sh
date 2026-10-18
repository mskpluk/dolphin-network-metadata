#!/bin/sh
# Removes everything install.sh created.
set -e

NAME=dolphin-network-metadata
WRAPPER="$HOME/.local/bin/dolphin"
DROPIN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/plasma-dolphin.service.d"

if [ -e "$WRAPPER" ] && grep -qF "# $NAME wrapper" "$WRAPPER"; then
    rm -f "$WRAPPER"
fi
rm -rf "$HOME/.local/lib/$NAME"
if [ -e "$DROPIN_DIR/$NAME.conf" ]; then
    rm -f "$DROPIN_DIR/$NAME.conf"
    rmdir "$DROPIN_DIR" 2>/dev/null || true
    systemctl --user daemon-reload 2>/dev/null || true
fi

echo "Uninstalled. Close all Dolphin windows and start it again."
