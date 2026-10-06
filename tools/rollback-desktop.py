#!/usr/bin/python3 -I
"""Remove this task's Desktop diversion/profile; retain app data and the current package binary."""
import argparse
import hashlib
import json
import os
import subprocess
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    if os.geteuid() != 0:
        raise SystemExit('Run with sudo; the backup is deliberately root-only.')
    candidates = []
    for backup in Path('/var/backups/claude-guard').glob('desktop-*'):
        manifest = backup / 'manifest.json'
        if manifest.is_file():
            data = json.loads(manifest.read_text())
            if data.get('entry') == '/usr/lib/claude-desktop/claude-desktop':
                candidates.append((backup, data))
    if len(candidates) != 1:
        raise SystemExit('Expected exactly one Desktop backup; stop rather than guess.')
    backup, data = candidates[0]
    entry, real, profile = (Path(data[key]) for key in ('entry', 'real', 'profile'))
    schema = None
    if data.get('gtk_schema_dir'):
        assert data['gtk_schema_dir'] == '/etc/claude-desktop-guard/gtk-schemas'
        schema = Path(data['gtk_schema_dir']) / 'gschemas.compiled'
        if schema.is_symlink() or hashlib.sha256(schema.read_bytes()).hexdigest() != data['gtk_schema_sha256']:
            raise SystemExit('Desktop GTK defaults changed; stop rather than delete.')
    if entry.is_symlink() or hashlib.sha256(entry.read_bytes()).hexdigest() != data['wrapper_sha256']:
        raise SystemExit('Desktop launcher changed; stop rather than overwrite.')
    if not real.is_file() or real.is_symlink() or real.stat().st_uid != 0:
        raise SystemExit('Unexpected diverted package binary; stop.')
    true_name = subprocess.check_output(['dpkg-divert', '--truename', str(entry)], text=True).strip()
    package = subprocess.check_output(['dpkg-divert', '--listpackage', str(entry)], text=True).strip()
    if true_name != str(real) or package != 'LOCAL':
        raise SystemExit('Unexpected diversion ownership; stop.')
    active = []
    for process in Path('/proc').iterdir():
        if process.name.isdecimal():
            try:
                if 'claude-desktop-guard' in (process / 'attr/current').read_text():
                    active.append(int(process.name))
            except OSError:
                pass
    if active:
        raise SystemExit('Close guarded Desktop processes first; PIDs: ' + str(active))
    for filename, digest in data.get('added_files', {}).items():
        file = Path(filename)
        if file.is_symlink() or hashlib.sha256(file.read_bytes()).hexdigest() != digest:
            raise SystemExit('Added Desktop integration file changed; stop rather than delete: ' + filename)
    print('Restore the current native package binary to:', entry)
    print('Remove only our local diversion and guard:', profile)
    print('Retain login/data, original vendor profile, CLI and backup:', backup)
    if not args.apply:
        return
    entry.unlink()
    try:
        subprocess.run(['dpkg-divert', '--remove', '--local', '--rename', str(entry)], check=True)
    except BaseException:
        # Keep the fail-closed entry usable if dpkg refuses to remove the diversion.
        source = backup / 'trusted-launcher.py'
        assert hashlib.sha256(source.read_bytes()).hexdigest() == data['wrapper_sha256']
        entry.write_bytes(source.read_bytes())
        entry.chmod(0o755)
        raise
    labels = Path('/sys/kernel/security/apparmor/profiles').read_text().splitlines()
    if 'claude-desktop-guard (enforce)' in labels:
        subprocess.run(['apparmor_parser', '-R', '-K', str(profile)], check=True)
    profile.unlink()
    if data.get('autostart_immutable'):
        subprocess.run(['chattr','-i','/home/qiu/.config/autostart/claude-desktop.real.desktop'],check=True)
    for filename in data.get('added_files', {}):
        Path(filename).unlink()
    if data.get('cowork_device_acl_added'):
        subprocess.run(['setfacl', '-x', 'u:1000', '/dev/vhost-vsock'], check=True)
        subprocess.run(['udevadm', 'control', '--reload'], check=True)
        print('Cowork module persistence removed; an in-use kernel module is left until reboot.')
    if schema:
        schema.unlink()
        schema.parent.rmdir()
        schema.parent.parent.rmdir()
    print('Desktop rollback complete. Native binary retained from the current package version.')


if __name__ == '__main__':
    main()
