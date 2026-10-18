#!/bin/sh
# Builds dolphin-network-metadata and hooks it into Dolphin for the current user.
set -e

NAME=dolphin-network-metadata
SRC_DIR=$(cd "$(dirname "$0")" && pwd)
LIB_DIR="$HOME/.local/lib/$NAME"
LIB="$LIB_DIR/$NAME.so"
BIN_DIR="$HOME/.local/bin"
WRAPPER="$BIN_DIR/dolphin"
DROPIN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/plasma-dolphin.service.d"
MARKER="# $NAME wrapper"

# The real Dolphin: first "dolphin" in PATH that isn't our wrapper
REAL_DOLPHIN=
IFS=:
for dir in $PATH; do
    [ "$dir" = "$BIN_DIR" ] && continue
    if [ -x "$dir/dolphin" ]; then
        REAL_DOLPHIN="$dir/dolphin"
        break
    fi
done
unset IFS
if [ -z "$REAL_DOLPHIN" ]; then
    echo "Dolphin not found in PATH." >&2
    exit 1
fi

if [ -e "$WRAPPER" ] && ! grep -qF "$MARKER" "$WRAPPER"; then
    echo "$WRAPPER already exists and wasn't created by $NAME; not touching it." >&2
    exit 1
fi

BIN_DIR_CREATED=
[ -d "$BIN_DIR" ] || BIN_DIR_CREATED=1
mkdir -p "$LIB_DIR" "$BIN_DIR"
${CC:-cc} -shared -fPIC -O2 -Wall -Wextra -o "$LIB" "$SRC_DIR/$NAME.c" -ldl

# Launches from the application menu, other programs and the terminal (Exec=dolphin goes through PATH)
cat > "$WRAPPER" <<EOS
#!/bin/sh
$MARKER
export LD_PRELOAD="$LIB\${LD_PRELOAD:+:\$LD_PRELOAD}"
exec $REAL_DOLPHIN "\$@"
EOS
chmod 755 "$WRAPPER"

# Background start via D-Bus (org.freedesktop.FileManager1 -> plasma-dolphin.service)
if command -v systemctl >/dev/null && systemctl --user cat plasma-dolphin.service >/dev/null 2>&1; then
    mkdir -p "$DROPIN_DIR"
    cat > "$DROPIN_DIR/$NAME.conf" <<EOS
[Service]
Environment=LD_PRELOAD=$LIB
EOS
    systemctl --user daemon-reload
fi

echo "Installed."
if [ "$(command -v dolphin)" = "$WRAPPER" ]; then
    echo "Close all Dolphin windows and start it again."
elif [ -n "$BIN_DIR_CREATED" ]; then
    echo "$BIN_DIR didn't exist before, so your session doesn't have it in PATH yet."
    echo "Log out and back in to start using it."
else
    echo "Warning: $BIN_DIR is not ahead of $(dirname "$REAL_DOLPHIN") in PATH," >&2
    echo "so launching \"dolphin\" won't pick up the wrapper. Add this line to your ~/.profile" >&2
    echo "(or your shell's login file), then log out and back in:" >&2
    echo >&2
    echo '    PATH="$HOME/.local/bin:$PATH"' >&2
fi
