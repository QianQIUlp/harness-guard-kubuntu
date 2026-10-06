#!/usr/bin/python3 -I
"""Restore this task's original CLI entry; keep login, cache and repository data.

Run as root with --apply only when intentionally removing the guard.
Without --apply, validate the backup and report the proposed changes.
"""
import argparse
import hashlib
import json
import os
import subprocess
from pathlib import Path

BACKUP = Path('/var/backups/claude-guard/20261005-223650')
ENTRY = Path('/home/qiu/.local/bin/claude')
PROFILE = Path('/etc/apparmor.d/claude-code-guard')
LAUNCHER = Path('/usr/local/libexec/claude-code-guard')
CONFIG = Path('/etc/claude-code-guard')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    if os.geteuid() != 0:
        raise SystemExit('Run with sudo; backup is deliberately root-only.')
    if Path('/etc/apparmor.d/claude-desktop-guard').exists():
        raise SystemExit('Rollback Desktop first: its trusted entry uses the CLI environment helper.')
    manifest = json.loads((BACKUP / 'manifest.json').read_text())
    original = os.readlink(BACKUP / 'cli-entry.original')
    if manifest['original_link'] != original or manifest['desktop_changed']:
        raise SystemExit('Unexpected backup manifest; stop rather than guess.')
    # Native cleanup can remove the original version; preserve the active install.
    native = Path('/home/qiu/.local/state/claude/guard-bin/claude')
    current = native.resolve()
    if (native.is_symlink() and current.parent == Path('/home/qiu/.local/share/claude/versions')
            and current.is_file() and os.access(current, os.X_OK)):
        original = str(current)
    if not Path(original).is_file():
        raise SystemExit('No installed native version to restore.')
    if ENTRY.is_symlink():
        expected_entry = os.readlink(ENTRY) == str(LAUNCHER)
    else:
        expected_entry = (ENTRY.is_file() and hashlib.sha256(ENTRY.read_bytes()).hexdigest()
                          == manifest.get('entry_sha256'))
    if not expected_entry:
        raise SystemExit('CLI entry changed since installation; stop rather than overwrite.')
    active = []
    for process in Path('/proc').iterdir():
        if process.name.isdecimal():
            try:
                if 'claude-code-guard' in (process / 'attr/current').read_text():
                    active.append(int(process.name))
            except OSError:
                pass
    if active:
        raise SystemExit('Close guarded processes before rollback; PIDs: ' + str(active))
    print('Restore CLI entry to:', original)
    print('Unload and remove only:', PROFILE, LAUNCHER, CONFIG)
    print('Preserve Claude data, caches, repositories, Desktop and all other policies.')
    if not args.apply:
        return
    temporary = ENTRY.with_name('.claude-rollback-new')
    if temporary.exists() or temporary.is_symlink():
        raise SystemExit('Rollback temporary path already exists; stop.')
    temporary.symlink_to(original)
    if not ENTRY.is_symlink():
        subprocess.run(['chattr', '-i', str(ENTRY)], check=True)
    os.replace(temporary, ENTRY)
    loaded = Path('/sys/kernel/security/apparmor/profiles').read_text().splitlines()
    if 'claude-code-guard (enforce)' in loaded:
        subprocess.run(['apparmor_parser', '-R', '-K', str(PROFILE)], check=True)
    PROFILE.unlink()
    LAUNCHER.unlink()
    for name in ('gitconfig', 'npmrc'):
        (CONFIG / name).unlink()
    CONFIG.rmdir()
    helpers = Path('/usr/local/libexec/claude-guard-bin')
    for name in ('xdg-open', 'bwrap'):
        (helpers / name).unlink(missing_ok=True)
    helpers.rmdir()
    Path('/etc/apparmor.d/abstractions/claude-guard-sandbox').unlink(missing_ok=True)
    Path('/etc/apparmor.d/abstractions/claude-guard-devtools').unlink(missing_ok=True)
    print('CLI rollback completed. Backup retained:', BACKUP)


if __name__ == '__main__':
    main()
