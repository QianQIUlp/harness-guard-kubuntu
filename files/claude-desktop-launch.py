#!/usr/bin/python3 -I
"""Trusted Desktop entry: sanitize inheritance, require enforce, then run the ELF."""
import os
import re
import runpy
import stat
import sys
from pathlib import Path

REAL = '/usr/lib/claude-desktop/claude-desktop.real'
PROFILE = 'claude-desktop-guard'
CLI_HELPER = '/usr/local/libexec/claude-code-guard'
AUTOSTART = Path('/home/qiu/.config/Claude/guard-autostart')
STARTUP_FILE = Path(REAL).name + '.desktop'


def startup_enabled(directory=AUTOSTART):
    try:
        lines = (directory / STARTUP_FILE).read_text().splitlines()
    except FileNotFoundError:
        return False
    return not any(re.fullmatch(r'Hidden\s*=\s*true|X-GNOME-Autostart-enabled\s*=\s*false',
                               line.strip(), re.IGNORECASE) for line in lines)


def enforcing(label):
    return label.endswith(' (enforce)') and PROFILE in label[:-10].split('//&')


def environment(source):
    env = runpy.run_path(CLI_HELPER)['clean_environment'](source)
    display = source.get('WAYLAND_DISPLAY', 'wayland-0')
    if not re.fullmatch(r'wayland-[0-9]+', display):
        raise RuntimeError('Unexpected Wayland display')
    env.update({
        'XDG_CONFIG_HOME': '/home/qiu/.config',
        'XDG_CACHE_HOME': '/home/qiu/.cache/claude-desktop-guard',
        'TMPDIR': '/tmp/claude-desktop-guard-1000',
        'XDG_RUNTIME_DIR': '/run/user/1000', 'WAYLAND_DISPLAY': display,
        'XDG_SESSION_TYPE': 'wayland', 'XDG_CURRENT_DESKTOP': 'KDE',
        'KDE_SESSION_VERSION': '6',
        'DBUS_SESSION_BUS_ADDRESS': 'unix:path=/run/user/1000/bus',
        'GSETTINGS_BACKEND': 'memory',
        'GSETTINGS_SCHEMA_DIR': '/etc/claude-desktop-guard/gtk-schemas',
        'GTK_USE_PORTAL': '1',
        'PULSE_SERVER': 'unix:/run/user/1000/pulse/native',
        'PULSE_COOKIE': '/home/qiu/.cache/claude-desktop-guard/pulse-cookie',
    })
    for key in ('XDG_ACTIVATION_TOKEN', 'DESKTOP_STARTUP_ID'):
        value = source.get(key, '')
        if value and len(value) <= 4096 and '\0' not in value:
            env[key] = value
    return env


def self_check():
    import tempfile
    env = environment({'AWS_SECRET_ACCESS_KEY': 'synthetic',
                       'SSH_AUTH_SOCK': '/synthetic', 'LD_PRELOAD': '/synthetic',
                       'WAYLAND_DISPLAY': 'wayland-0'})
    assert not any(k in env for k in ('AWS_SECRET_ACCESS_KEY', 'SSH_AUTH_SOCK', 'LD_PRELOAD'))
    assert env['XDG_CONFIG_HOME'] == '/home/qiu/.config'
    assert env['GSETTINGS_SCHEMA_DIR'] == '/etc/claude-desktop-guard/gtk-schemas'
    assert enforcing('claude-desktop-guard (enforce)')
    assert not enforcing('claude-desktop-guard (complain)')
    assert not enforcing('claude-desktop-guard-other (enforce)')
    try:
        environment({'WAYLAND_DISPLAY': '/synthetic/private-socket'})
    except RuntimeError:
        pass
    else:
        raise AssertionError('Invalid display accepted')
    with tempfile.TemporaryDirectory() as tmp:
        directory = Path(tmp)
        assert not startup_enabled(directory)
        entry = directory / STARTUP_FILE
        entry.write_text('[Desktop Entry]\nExec=/untrusted/ignored\n')
        assert startup_enabled(directory)
        for disabled in ('Hidden = true', 'X-GNOME-Autostart-enabled=false'):
            entry.write_text(disabled + '\n')
            assert not startup_enabled(directory)
    print('PASS: Desktop entry environment and enforcing-label checks; no app/account run')


def main():
    if sys.argv[1:] == ['--guard-self-check']:
        self_check()
        return
    if os.getuid() != 1000 or os.geteuid() != 1000:
        raise RuntimeError('Run as qiu, never as root')
    if sys.argv[1:2] == ['--guard-enter']:
        if not enforcing(Path('/proc/self/attr/current').read_text().strip()):
            raise RuntimeError('Expected enforcing Desktop guard; refusing launch')
        args = sys.argv[2:]
        if '--startup' in args and not startup_enabled():
            return
        AUTOSTART.mkdir(mode=0o700, exist_ok=True)
        # Native autostart writes are data in a private view. The host's fixed
        # root-owned entry invokes this launcher and ignores that data's Exec.
        runpy.run_path(CLI_HELPER)['private_view'](
            AUTOSTART, '/home/qiu/.config/autostart',
            [REAL, *args, '--ozone-platform=wayland', '--disable-dev-shm-usage',
             '--password-store=kwallet6'])
    for entry in os.listdir('/proc/self/fd'):
        if int(entry) > 2:
            try:
                os.close(int(entry))
            except OSError:
                pass
    # GUI launchers may inherit log files. Do not pass private open files to the app.
    for fd in (0, 1, 2):
        info = os.fstat(fd)
        if stat.S_ISREG(info.st_mode):
            path = Path(os.readlink(f'/proc/self/fd/{fd}')).resolve()
            if not path.is_relative_to('/home/qiu/src'):
                null = os.open('/dev/null', os.O_RDONLY if fd == 0 else os.O_WRONLY)
                os.dup2(null, fd)
                os.close(null)
    env = runpy.run_path(CLI_HELPER)['github_environment'](environment(os.environ))
    for name in ('TMPDIR', 'XDG_CACHE_HOME'):
        directory = Path(env[name])
        if directory.resolve() != directory:
            raise RuntimeError('Guard directory must not resolve through a symlink')
        directory.mkdir(mode=0o700, parents=True, exist_ok=True)
        if directory.stat().st_uid != 1000:
            raise RuntimeError('Unexpected guard-directory owner')
        directory.chmod(0o700)
    os.execve('/usr/bin/setpriv', ['setpriv', '--no-new-privs', '--',
              '/usr/bin/aa-exec', '-p', PROFILE, '--',
              '/usr/bin/python3', '-I', os.path.realpath(__file__),
              '--guard-enter', *sys.argv[1:]], env)


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError) as error:
        print(f'Claude Desktop guard: {error}', file=sys.stderr)
        sys.exit(1)
