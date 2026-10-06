#!/usr/bin/python3 -I
"""Trusted entry: clean external inheritance, preserve an existing Desktop guard."""
import os
import re
import stat
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlsplit

VERSIONS = Path('/home/qiu/.local/share/claude/versions')
NATIVE_ENTRY = Path('/home/qiu/.local/state/claude/guard-bin/claude')
NODE = '/home/qiu/.nvm/versions/node/v22.23.2'


def clean_environment(source):
    result = {key: source[key] for key in (
        'TERM', 'COLORTERM', 'LANG', 'LC_ALL', 'LC_CTYPE', 'NO_COLOR',
        'GH_TOKEN', 'GITHUB_TOKEN', 'GH_ENTERPRISE_TOKEN', 'GITHUB_ENTERPRISE_TOKEN',
        'GH_HOST',
    ) if key in source}
    # Keep existing unauthenticated local proxy settings, never proxy passwords.
    for key in ('http_proxy', 'https_proxy', 'all_proxy',
                'HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY'):
        if key not in source:
            continue
        try:
            proxy = urlsplit(source[key])
            if (proxy.scheme in ('http', 'https', 'socks5', 'socks5h')
                    and proxy.hostname in ('localhost', '127.0.0.1', '::1')
                    and proxy.username is None and proxy.password is None):
                result[key] = source[key]
        except ValueError:
            pass
    result.update({
        'HOME': '/home/qiu', 'USER': 'qiu', 'LOGNAME': 'qiu',
        'PATH': '/usr/local/libexec/claude-guard-bin:' + NODE + '/bin:/home/qiu/.cargo/bin:/home/qiu/.local/bin:/usr/bin:/bin',
        'BROWSER': '/usr/local/libexec/claude-guard-bin/xdg-open',
        'XDG_RUNTIME_DIR': '/run/user/1000',
        'DBUS_SESSION_BUS_ADDRESS': 'unix:path=/run/user/1000/bus',
        'TMPDIR': '/tmp/claude-1000',
        'GIT_CONFIG_GLOBAL': '/etc/claude-code-guard/gitconfig',
        'GIT_CONFIG_NOSYSTEM': '1', 'GIT_TERMINAL_PROMPT': '0',
        'GIT_SSH_COMMAND': '/usr/bin/ssh -F /dev/null -o IdentityAgent=none -o IdentitiesOnly=yes -o BatchMode=yes',
        'NPM_CONFIG_USERCONFIG': '/dev/null',
        'NPM_CONFIG_GLOBALCONFIG': '/etc/claude-code-guard/npmrc',
        'NPM_CONFIG_CACHE': '/home/qiu/.cache/claude-code-guard/npm',
        'XDG_CACHE_HOME': '/home/qiu/.cache/claude-code-guard',
        'PIP_CACHE_DIR': '/home/qiu/.cache/claude-code-guard/pip',
        'COREPACK_HOME': '/home/qiu/.cache/node/corepack',
        'PNPM_HOME': '/home/qiu/.cache/claude-code-guard/pnpm',
        'CARGO_HOME': '/home/qiu/.cache/claude-code-guard/cargo',
        'RUSTUP_HOME': '/home/qiu/.rustup',
        'GH_CONFIG_DIR': '/home/qiu/.config/gh',
        'HISTFILE': '/home/qiu/.cache/claude-code-guard/bash_history',
        'PYTHONNOUSERSITE': '1',
    })
    return result


def github_environment(env):
    # Native gh reads only its existing GitHub credential before confinement.
    if not (env.get('GH_TOKEN') or env.get('GITHUB_TOKEN')):
        try:
            result = subprocess.run(['/usr/bin/gh', 'auth', 'token', '--hostname', 'github.com'],
                                    env=env, capture_output=True, text=True, timeout=3)
            if result.returncode == 0 and result.stdout.strip():
                env['GH_TOKEN'] = result.stdout.strip()
        except (OSError, subprocess.TimeoutExpired):
            pass  # An unavailable optional GitHub login must not prevent startup.
    return env


def latest_version(directory, requested=None):
    candidates = []
    for path in directory.iterdir():
        if re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', path.name):
            if not path.is_symlink() and path.is_file() and os.access(path, os.X_OK):
                candidates.append((tuple(map(int, path.name.split('.'))), path))
    if requested is not None:
        candidates = [item for item in candidates if item[1].name == requested]
    if not candidates:
        raise RuntimeError('No regular executable Claude version found')
    return max(candidates)[1]


def enforced_label(label, profile='claude-code-guard'):
    return (label.endswith(' (enforce)')
            and profile in label[:-10].split('//&'))


def selected_version(directory, entry):
    target = entry.resolve()
    if not entry.is_symlink() or target.parent != directory:
        raise RuntimeError('Native launcher must point to an installed Claude version')
    return latest_version(directory, target.name)


def run_claude(args):
    NATIVE_ENTRY.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    if not NATIVE_ENTRY.exists() and not NATIVE_ENTRY.is_symlink():
        NATIVE_ENTRY.symlink_to(latest_version(VERSIONS))
    executable = str(selected_version(VERSIONS, NATIVE_ENTRY))
    # The official updater owns its link in this view; the host entry stays trusted.
    private_view(NATIVE_ENTRY.parent, '/home/qiu/.local/bin', [executable, *args])


def private_view(source, destination, command):
    # Use the installed tools; stock bwrap strips capabilities from its children,
    # which would block the application's own later development sandboxes.
    os.execve('/usr/bin/setpriv', ['setpriv', '--no-new-privs', '--',
              '/usr/bin/unshare', '--user', '--map-current-user', '--keep-caps',
              '--mount', '--fork', '--', '/bin/sh', '-c',
              '/usr/bin/busybox mount -n -o bind "$1" "$2" && shift 2 && '
              'exec /usr/bin/setpriv --inh-caps=-all --ambient-caps=-all -- "$@"',
              'claude-guard-view', str(source), str(destination), *command], dict(os.environ))


def self_check():
    import tempfile
    env = clean_environment({'AWS_SECRET_ACCESS_KEY': 'synthetic',
                             'SSH_AUTH_SOCK': '/synthetic',
                             'ANTHROPIC_API_KEY': 'synthetic',
                             'LD_PRELOAD': '/synthetic', 'TERM': 'xterm',
                             'GH_TOKEN': 'synthetic-github',
                             'HTTP_PROXY': 'http://127.0.0.1:7890',
                             'HTTPS_PROXY': 'http://secret@localhost:7890'})
    assert not any(k in env for k in ('AWS_SECRET_ACCESS_KEY', 'SSH_AUTH_SOCK',
                                     'ANTHROPIC_API_KEY', 'LD_PRELOAD', 'HTTPS_PROXY'))
    assert env['HTTP_PROXY'] == 'http://127.0.0.1:7890'
    assert env['GH_TOKEN'] == 'synthetic-github'
    assert '/home/qiu/.cargo/bin' in env['PATH'].split(':')
    assert enforced_label('claude-code-guard (enforce)')
    assert enforced_label('claude-code-guard//&unconfined (enforce)')
    assert not enforced_label('claude-code-guard (complain)')
    assert not enforced_label('unconfined')
    assert not enforced_label('claude-code-guard-other (enforce)')
    assert enforced_label('claude-desktop-guard (enforce)', 'claude-desktop-guard')
    with tempfile.TemporaryDirectory(prefix='claude-launch-check-') as tmp:
        root = Path(tmp)
        for name in ('2.1.9', '2.1.289', '2.1.1000.invalid'):
            path = root / name
            path.touch()
            path.chmod(0o700)
        (root / '99.0.0').symlink_to(root / '2.1.9')
        assert latest_version(root).name == '2.1.289'
        assert latest_version(root, '2.1.9').name == '2.1.9'
        entry = root / 'claude'
        entry.symlink_to(root / '2.1.9')
        assert selected_version(root, entry).name == '2.1.9'
        entry.unlink()
        entry.symlink_to('/usr/bin/python3')
        try:
            selected_version(root, entry)
        except RuntimeError:
            pass
        else:
            raise AssertionError('Native launcher escaped versions directory')
        for invalid in ('99.0.0', '../2.1.9', 'missing'):
            try:
                latest_version(root, invalid)
            except RuntimeError:
                pass
            else:
                raise AssertionError('Invalid or symlinked version accepted')
    print('PASS: environment allowlist and version selection; no Claude run')


def main():
    if sys.argv[1:] == ['--guard-self-check']:
        self_check()
        return
    if os.getuid() != 1000 or os.geteuid() != 1000:
        raise RuntimeError('Run as qiu, never as root')
    label = Path('/proc/self/attr/current').read_text().strip()
    if sys.argv[1:2] == ['--guard-enter']:
        # This trusted second stage runs inside the profile before any Claude code.
        if not enforced_label(label):
            raise RuntimeError('Expected enforcing claude-code-guard label; refusing launch')
        run_claude(sys.argv[2:])
    if enforced_label(label, 'claude-desktop-guard') or enforced_label(label):
        # Desktop/CLI children already inherit confinement; retain their SDK IPC.
        run_claude(sys.argv[1:])
    # Unconfined descriptors have an AppArmor revalidation exemption.
    # Preserve user-supplied standard streams, close every extra descriptor.
    for entry in os.listdir('/proc/self/fd'):
        if int(entry) > 2:
            try:
                os.close(int(entry))
            except OSError:
                pass
    # Refuse inherited regular-file standard streams outside the authorized repo.
    for fd in (0, 1, 2):
        try:
            if stat.S_ISREG(os.fstat(fd).st_mode):
                target = Path(os.readlink(f'/proc/self/fd/{fd}')).resolve()
                if not target.is_relative_to('/home/qiu/src'):
                    raise RuntimeError('Standard stream points outside authorized repository')
        except OSError:
            raise RuntimeError('Cannot validate standard stream') from None
    env = github_environment(clean_environment(os.environ))
    # Missing/rejected profile makes aa-exec fail; there is no unconfined fallback.
    os.execve('/usr/bin/setpriv', ['setpriv', '--no-new-privs', '--',
              '/usr/bin/aa-exec', '-p', 'claude-code-guard', '--',
              '/usr/bin/python3', '-I', os.path.realpath(__file__),
              '--guard-enter', *sys.argv[1:]], env)


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError) as error:
        print(f'Claude guard: {error}', file=sys.stderr)
        sys.exit(1)
