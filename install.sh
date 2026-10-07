#!/bin/sh
# Install, update or remove the agent guards.
#   sudo ./install.sh             install, or apply repository changes
#   sudo ./install.sh uninstall   remove the guards; agent data and logins are kept
# Quit the guarded agents first, and run from a normal terminal (sudo is denied inside
# the guard). Your path choices live in /etc/harness-guard/policy.toml, which this
# script creates once and never overwrites; change them with harness-guard-apply.
set -eu
cd "$(dirname "$0")"

LIBEXEC=/usr/local/libexec
DESKTOP=/usr/lib/claude-desktop/claude-desktop
CLI_ENTRY=/home/qiu/.local/bin/claude
VERSIONS=/home/qiu/.local/share/claude/versions
PROFILES="claude-code-guard claude-desktop-guard"

[ "$(id -u)" = 0 ] || { echo "Run with sudo." >&2; exit 1; }
for profile in $PROFILES; do
    if grep -qs -e "^$profile " -e "^$profile//" /proc/[0-9]*/attr/current; then
        echo "Quit the agents running under $profile first." >&2
        exit 1
    fi
done

# Root-owned file the user (and therefore no agent) can replace: put PATH MODE CONTENT
put() {
    chattr -i "$1" 2>/dev/null || true
    rm -f "$1"
    printf '%s\n' "$3" > "$1"
    chmod "$2" "$1"
}

case "${1:-install}" in
install)
    # Check every profile before touching the system (harness-guard-apply checks the policy).
    for profile in harness-guard-launcher $PROFILES; do
        apparmor_parser -Q -K -I "$PWD/apparmor" -I /etc/apparmor.d "apparmor/$profile"
    done

    install -m 644 -D -t /etc/apparmor.d/abstractions apparmor/abstractions/harness-guard \
        apparmor/abstractions/harness-guard-claude
    for profile in harness-guard-launcher $PROFILES; do
        install -m 644 "apparmor/$profile" /etc/apparmor.d/
    done
    install -m 755 bin/harness-guard "$LIBEXEC/harness-guard"
    install -m 755 -D -t "$LIBEXEC/harness-guard-bin" bin/xdg-open bin/bwrap
    install -m 755 bin/harness-guard-apply /usr/local/sbin/harness-guard-apply
    install -m 644 -D -t /etc/harness-guard/agents agents/*.toml
    install -m 644 etc/gitconfig /etc/harness-guard/gitconfig
    [ -e /etc/harness-guard/policy.toml ] || install -m 644 etc/policy.toml /etc/harness-guard/policy.toml

    # GTK defaults with minimize/maximize/close buttons, built from the system schema.
    schemas=$(mktemp -d)
    cp /usr/share/glib-2.0/schemas/org.gnome.desktop.wm.preferences.gschema.xml \
       /usr/share/glib-2.0/schemas/org.gnome.desktop.enums.xml etc/gtk.gschema.override "$schemas"
    install -d /etc/harness-guard/gtk-schemas
    glib-compile-schemas --strict --targetdir=/etc/harness-guard/gtk-schemas "$schemas"
    rm -r "$schemas"

    # Compiles the policy into /etc/apparmor.d/harness-guard/ and loads the agent profiles.
    /usr/local/sbin/harness-guard-apply
    apparmor_parser -r -W /etc/apparmor.d/harness-guard-launcher

    put "$CLI_ENTRY" 755 '#!/bin/sh
exec /usr/local/libexec/harness-guard claude-code "$@"'
    chattr +i "$CLI_ENTRY"

    [ "$(dpkg-divert --truename "$DESKTOP")" != "$DESKTOP" ] ||
        dpkg-divert --local --rename --add "$DESKTOP"
    put "$DESKTOP" 755 '#!/bin/sh
exec /usr/local/libexec/harness-guard claude-desktop "$@"'

    # Cowork VM device access for qiu.
    echo vhost_vsock > /etc/modules-load.d/claude-cowork.conf
    echo 'SUBSYSTEM=="misc", KERNEL=="vhost-vsock", RUN+="/usr/bin/setfacl -m u:1000:rw /dev/vhost-vsock"' \
        > /etc/udev/rules.d/70-claude-vhost-vsock.rules
    modprobe vhost_vsock
    setfacl -m u:1000:rw /dev/vhost-vsock

    # Leftovers of the claude-guard layout.
    if [ -e /etc/apparmor.d/claude-guard-launcher ]; then
        apparmor_parser -R /etc/apparmor.d/claude-guard-launcher 2>/dev/null || true
    fi
    rm -f /etc/apparmor.d/claude-guard-launcher /etc/apparmor.d/abstractions/claude-guard \
          "$LIBEXEC/claude-guard"
    rm -rf "$LIBEXEC/claude-guard-bin" /etc/claude-guard
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

    for profile in harness-guard-launcher $PROFILES; do
        apparmor_parser -R "/etc/apparmor.d/$profile" || true
        rm -f "/etc/apparmor.d/$profile"
    done
    rm -f /etc/apparmor.d/abstractions/harness-guard /etc/apparmor.d/abstractions/harness-guard-claude \
          "$LIBEXEC/harness-guard" /usr/local/sbin/harness-guard-apply \
          /etc/modules-load.d/claude-cowork.conf /etc/udev/rules.d/70-claude-vhost-vsock.rules
    rm -rf /etc/apparmor.d/harness-guard "$LIBEXEC/harness-guard-bin" /etc/harness-guard/agents \
           /etc/harness-guard/gitconfig /etc/harness-guard/gtk-schemas
    setfacl -x u:1000 /dev/vhost-vsock 2>/dev/null || true
    echo "Removed. Your policy stays in /etc/harness-guard/policy.toml. Claude Code now points at $version."
    ;;

*)
    echo "Usage: sudo $0 [install|uninstall]" >&2
    exit 2
    ;;
esac
