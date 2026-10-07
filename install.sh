#!/bin/sh
# Install, update or remove harness-guard from this checkout.
#   ./install.sh             build the package from this checkout and install it
#   ./install.sh uninstall   remove it; every guarded agent is released first
#   ./install.sh purge       also remove /etc/harness-guard and /var/lib/harness-guard
# Run as yourself from a normal terminal (sudo is denied inside the guard). Nothing in
# this checkout runs as root: you build the package, and apt (through sudo) installs it.
# Quit the guarded agents first; the package refuses otherwise.
set -eu
cd "$(dirname "$0")"
[ "$(id -u)" != 0 ] || { echo "Run as yourself, without sudo; apt asks for it." >&2; exit 1; }

case "${1:-install}" in
install)
    out=$(mktemp -d)
    trap 'rm -rf "$out"' EXIT
    deb=$(tools/build-deb.sh "$out")
    chmod 755 "$out"  # apt's download user reads it
    sudo apt install --reinstall "$deb"
    echo "Installed. Check with: tools/check.sh"
    ;;
uninstall)
    sudo apt remove harness-guard
    ;;
purge)
    sudo apt purge harness-guard
    ;;
*)
    echo "Usage: $0 [install|uninstall|purge]" >&2
    exit 2
    ;;
esac
