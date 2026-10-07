#!/bin/sh
# Install, update or remove the Claude AppArmor guard.
#   sudo ./install.sh             install, or apply repository changes
#   sudo ./install.sh uninstall   remove the guard; Claude data and logins are kept
# Quit Claude Code and Claude Desktop first, and run from a normal terminal
# (sudo is denied inside the guard).
set -eu
cd "$(dirname "$0")"

LIBEXEC=/usr/local/libexec
DESKTOP=/usr/lib/claude-desktop/claude-desktop
CLI_ENTRY=/home/qiu/.local/bin/claude
OLD_AUTOSTART=/home/qiu/.config/autostart/claude-desktop.real.desktop
VERSIONS=/home/qiu/.local/share/claude/versions

[ "$(id -u)" = 0 ] || { echo "Run with sudo." >&2; exit 1; }
if grep -qs -e '^claude-code-guard' -e '^claude-desktop-guard' /proc/[0-9]*/attr/current; then
    echo "Quit Claude Code and Claude Desktop first." >&2
    exit 1
fi

# Root-owned file the user (and therefore Claude) cannot replace: put PATH MODE CONTENT
put() {
    chattr -i "$1" 2>/dev/null || true
    rm -f "$1"
    printf '%s\n' "$3" > "$1"
    chmod "$2" "$1"
}

case "${1:-install}" in
install)
    for profile in claude-guard-launcher claude-code-guard claude-desktop-guard; do
        apparmor_parser -Q -K -I "$PWD/apparmor" -I /etc/apparmor.d "apparmor/$profile"
    done

    install -m 644 -D apparmor/abstractions/claude-guard /etc/apparmor.d/abstractions/claude-guard
    install -m 644 apparmor/claude-guard-launcher apparmor/claude-code-guard apparmor/claude-desktop-guard /etc/apparmor.d/
    install -m 755 bin/claude-guard "$LIBEXEC/claude-guard"
    install -m 755 -D -t "$LIBEXEC/claude-guard-bin" bin/xdg-open bin/bwrap
    install -m 644 -D etc/gitconfig /etc/claude-guard/gitconfig

    # GTK defaults with minimize/maximize/close buttons, built from the system schema.
    schemas=$(mktemp -d)
    cp /usr/share/glib-2.0/schemas/org.gnome.desktop.wm.preferences.gschema.xml \
       /usr/share/glib-2.0/schemas/org.gnome.desktop.enums.xml etc/gtk.gschema.override "$schemas"
    install -d /etc/claude-guard/gtk-schemas
    glib-compile-schemas --strict --targetdir=/etc/claude-guard/gtk-schemas "$schemas"
    rm -r "$schemas"

    apparmor_parser -r -W /etc/apparmor.d/claude-code-guard /etc/apparmor.d/claude-desktop-guard \
        /etc/apparmor.d/claude-guard-launcher

    put "$CLI_ENTRY" 755 '#!/bin/sh
exec /usr/local/libexec/claude-guard "$@"'
    chattr +i "$CLI_ENTRY"

    [ "$(dpkg-divert --truename "$DESKTOP")" != "$DESKTOP" ] ||
        dpkg-divert --local --rename --add "$DESKTOP"
    put "$DESKTOP" 755 '#!/bin/sh
exec /usr/local/libexec/claude-guard --desktop "$@"'

    # Cowork VM device access for qiu.
    echo vhost_vsock > /etc/modules-load.d/claude-cowork.conf
    echo 'SUBSYSTEM=="misc", KERNEL=="vhost-vsock", RUN+="/usr/bin/setfacl -m u:1000:rw /dev/vhost-vsock"' \
        > /etc/udev/rules.d/70-claude-vhost-vsock.rules
    modprobe vhost_vsock
    setfacl -m u:1000:rw /dev/vhost-vsock

    # Leftovers of the previous layout.
    rm -f /etc/apparmor.d/abstractions/claude-guard-sandbox /etc/apparmor.d/abstractions/claude-guard-devtools \
          "$LIBEXEC/claude-code-guard"
    rm -rf /etc/claude-code-guard /etc/claude-desktop-guard
    chattr -i "$OLD_AUTOSTART" 2>/dev/null || true
    rm -f "$OLD_AUTOSTART"
    echo "Installed. Check with: tools/check.sh (as qiu, from a normal terminal)"
    ;;

uninstall)
    version=$(readlink /home/qiu/.local/state/claude/guard-bin/claude || true)
    [ -n "$version" ] || version="$VERSIONS/$(ls -v "$VERSIONS" | tail -n 1)"
    chattr -i "$CLI_ENTRY" 2>/dev/null || true
    rm -f "$CLI_ENTRY"
    ln -s "$version" "$CLI_ENTRY"
    chown -h qiu:qiu "$CLI_ENTRY"

    rm -f "$DESKTOP"
    dpkg-divert --local --rename --remove "$DESKTOP"

    apparmor_parser -R /etc/apparmor.d/claude-guard-launcher /etc/apparmor.d/claude-desktop-guard \
        /etc/apparmor.d/claude-code-guard
    rm -f /etc/apparmor.d/claude-guard-launcher /etc/apparmor.d/claude-code-guard /etc/apparmor.d/claude-desktop-guard \
          /etc/apparmor.d/abstractions/claude-guard "$LIBEXEC/claude-guard" \
          /etc/modules-load.d/claude-cowork.conf /etc/udev/rules.d/70-claude-vhost-vsock.rules
    rm -rf "$LIBEXEC/claude-guard-bin" /etc/claude-guard
    setfacl -x u:1000 /dev/vhost-vsock 2>/dev/null || true
    echo "Removed. Claude Code now points at $version."
    ;;

*)
    echo "Usage: sudo $0 [install|uninstall]" >&2
    exit 2
    ;;
esac
