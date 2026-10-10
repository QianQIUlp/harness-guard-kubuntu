#!/bin/sh
# Build harness-guard_VERSION_all.deb from this checkout: tools/build-deb.sh [OUTDIR]
# Runs as you; fakeroot makes every file root-owned inside the package. The version is
# VERSION plus the commit (and a timestamp when the checkout has uncommitted changes),
# or $HARNESS_GUARD_VERSION for a release.
set -eu
umask 022
cd "$(dirname "$0")/.."
out=$(realpath "${1:-.}")

version=${HARNESS_GUARD_VERSION:-}
if [ -z "$version" ]; then
    version="$(cat VERSION)+git$(git log -1 --format=%cd --date=format:%Y%m%d%H%M%S).$(git rev-parse --short=8 HEAD)"
    [ -z "$(git status --porcelain)" ] || version="$version.local$(date +%Y%m%d%H%M%S)"
fi

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
root="$stage/root"

# The profiles and agent specs in /etc are package files, not conffiles: the owner's
# choices live in policy.toml and owner.toml (detected by postinst), which are kept.
install -m 644 -D -t "$root/etc/apparmor.d" apparmor/harness-guard-launcher apparmor/claude-code-guard \
    apparmor/claude-desktop-guard apparmor/agy-guard apparmor/antigravity-guard
install -m 644 -D -t "$root/etc/apparmor.d/abstractions" apparmor/abstractions/harness-guard \
    apparmor/abstractions/harness-guard-claude apparmor/abstractions/harness-guard-antigravity \
    apparmor/abstractions/harness-guard-electron
install -m 644 -D -t "$root/etc/harness-guard/agents" agents/*.toml
install -m 644 -D etc/gitconfig "$root/etc/harness-guard/gitconfig"
install -m 644 -D -t "$root/usr/share/harness-guard" etc/policy.toml etc/gtk.gschema.override

install -m 755 -D bin/harness-guard "$root/usr/libexec/harness-guard/launcher"
install -m 755 -D bin/harness-guard-handoff "$root/usr/libexec/harness-guard/handoff"
install -m 755 -D tools/check.sh "$root/usr/libexec/harness-guard/check"
install -m 755 -D -t "$root/usr/libexec/harness-guard/bin" bin/xdg-open bin/bwrap
install -m 755 -D -t "$root/usr/sbin" bin/harness-guard-apply bin/harness-guard-setup
install -m 644 -D -t "$root/usr/lib/systemd/user" etc/systemd/harness-guard-handoff.socket \
    etc/systemd/harness-guard-handoff@.service

install -m 755 -D -t "$root/usr/lib/harness-guard" console/harness-guard-console
install -m 644 -t "$root/usr/lib/harness-guard" console/*.qml console/*.svg console/qmldir
install -m 644 -D console/harness-guard.svg "$root/usr/share/icons/hicolor/scalable/apps/harness-guard-console.svg"
install -d "$root/usr/bin"
ln -s ../lib/harness-guard/harness-guard-console "$root/usr/bin/harness-guard-console"
install -m 644 -D -t "$root/usr/share/applications" console/harness-guard-console.desktop
install -m 644 -D -t "$root/usr/share/polkit-1/actions" console/org.harness-guard.policy

doc="$root/usr/share/doc/harness-guard"
install -m 644 -D README.md "$doc/README.md"
install -m 644 -D THIRD_PARTY.md "$doc/THIRD_PARTY.md"
cat > "$doc/copyright" <<EOF
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: harness-guard

Files: etc/apparmor.d/claude-desktop-guard etc/apparmor.d/abstractions/harness-guard-electron
Comment: Portions adapted from roddhjav/apparmor.d f9ee26eb2d44db2a0ae0fd546cdd845f1bb86c2a
Copyright: 2024-2026 Alexandre Pujol <alexandre@pujol.io>
License: GPL-2.0-only
 On Debian systems, the full text is in /usr/share/common-licenses/GPL-2.
EOF

install -m 755 -D -t "$root/DEBIAN" packaging/preinst packaging/postinst packaging/prerm packaging/postrm
cat > "$root/DEBIAN/control" <<EOF
Package: harness-guard
Version: $version
Architecture: all
Maintainer: $(git log -1 --format='%an <%ae>')
Section: admin
Priority: optional
Installed-Size: $(du -sk --exclude=DEBIAN "$root" | cut -f1)
Depends: python3 (>= 3.11), python3-gi, gir1.2-glib-2.0, python3-pyqt6, python3-pyqt6.qtqml,
 python3-pyqt6.qtquick, qml6-module-qtquick, qml6-module-qtquick-controls,
 qml6-module-qtquick-dialogs, qml6-module-qtquick-layouts, qml6-module-qtquick-shapes,
 apparmor, pkexec, acl, e2fsprogs, kmod, libglib2.0-bin, gsettings-desktop-schemas, systemd,
 bash, bsdutils
Recommends: konsole
Description: AppArmor guards for coding agents, with a console
 Runs Claude Code, Claude Desktop, the Antigravity app and the Antigravity CLI inside
 kernel-enforced AppArmor guards: private data stays unreadable, the guard can't be
 switched off from inside, and the agents keep working. The console shows each
 agent's state, what it was refused, and what it may reach, and applies changes
 through pkexec.
 .
 Installing guards every agent found; each guard keeps a receipt of what it changed,
 and removing the package releases every agent, putting back exactly that.
EOF
(cd "$root" && find . -path ./DEBIAN -prune -o -type f -printf '%P\0' | sort -z | xargs -0 md5sum) \
    > "$root/DEBIAN/md5sums"
chmod 644 "$root/DEBIAN/md5sums"

deb="$out/harness-guard_${version}_all.deb"
fakeroot dpkg-deb --root-owner-group -Zxz --build "$root" "$deb" >/dev/null
echo "$deb"
