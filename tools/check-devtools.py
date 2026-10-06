import errno
import json
import os
import pty
import runpy
import signal
import socket
import subprocess
import sys
import tempfile
import time
import urllib.request
from pathlib import Path


def check(root, private):
    label = Path('/proc/self/attr/current').read_text().strip()
    assert label in ('claude-code-guard (enforce)', 'claude-desktop-guard (enforce)')
    env = runpy.run_path('/usr/local/libexec/claude-code-guard')['clean_environment'](os.environ)
    env['COREPACK_ENABLE_NETWORK'] = '0'  # Only this check is offline.
    env['CARGO_TARGET_DIR'] = str(root/label.split()[0]/'target')

    def run(argv):
        result = subprocess.run(argv, cwd=root, env=env, text=True, capture_output=True, timeout=25)
        assert result.returncode == 0, (argv, result.stdout[-1200:], result.stderr[-1200:])
        return result.stdout + result.stderr

    versions = {name: run([name, '--version']).splitlines()[0]
                for name in ('java', 'javac', 'rustc', 'cargo', 'pnpm')}
    for mode in ('r', 'w'):
        try:
            with open(private, mode): pass
        except PermissionError: pass
        else: raise AssertionError('Private file became accessible: ' + mode)
    with socket.socket(socket.AF_UNIX) as client:
        try: client.connect('/run/docker.sock')
        except PermissionError: pass
        else: raise AssertionError('Host Docker became accessible')
    fd = os.open('/home/qiu/.config/gh/hosts.yml', os.O_RDONLY)
    os.close(fd)  # Verify access without reading or printing credentials.
    assert run(['gh', 'auth', 'token', '--hostname', 'github.com']).strip()
    assert '/usr/bin/gh auth git-credential' in run(['git', 'config', '--get-urlmatch', 'credential.helper', 'https://github.com'])
    (root/'Hello.java').write_text('import java.nio.file.*; class Hello { public static void main(String[] a) throws Exception { System.out.print(Files.readString(Path.of("/proc/self/attr/current"))); try { Files.readString(Path.of(a[0])); throw new AssertionError(); } catch (AccessDeniedException expected) {} }}')
    run(['javac', 'Hello.java'])
    assert label in run(['java', '-cp', '.', 'Hello', str(private)])
    (root/'src').mkdir(exist_ok=True)
    (root/'Cargo.toml').write_text('[package]\nname="guard-dev-check"\nversion="0.1.0"\nedition="2021"\n')
    (root/'src/main.rs').write_text('fn main() { print!("{}", std::fs::read_to_string("/proc/self/attr/current").unwrap()); assert_eq!(std::fs::read(std::env::args().nth(1).unwrap()).unwrap_err().kind(), std::io::ErrorKind::PermissionDenied); }')
    run(['cargo', 'build', '--offline'])
    assert label in run([str(Path(env['CARGO_TARGET_DIR'])/'debug/guard-dev-check'), str(private)])
    # Use a real interactive PTY and the user's normal Bash startup files.
    pid, master = pty.fork()
    if pid == 0:
        os.chdir(root)
        os.execve('/bin/bash', ['bash', '-ic', 'cat /proc/self/attr/current; pnpm --version && printf "\\nGUARD_PTY_READY\\n"; exit'], env)
    output = b''
    try:
        while True:
            try:
                data = os.read(master, 65536)
                if not data: break
                output += data
            except OSError as exc:
                if exc.errno == errno.EIO: break
                raise
    finally:
        os.close(master)
    _, status = os.waitpid(pid, 0)
    assert os.waitstatus_to_exitcode(status) == 0 and label.encode() in output and b'GUARD_PTY_READY' in output, output[-1200:]
    # Start pnpm/Vite in disposable source files; no user project is modified.
    (root/'index.html').write_text('<html><body>guard-preview-ready</body></html>')
    vite = '/home/qiu/src/motion-atlas-workspace/node_modules/vite/bin/vite.js'
    (root/'package.json').write_text(json.dumps({'scripts': {'dev': 'node ' + vite}}))
    with socket.socket() as port_socket:
        port_socket.bind(('127.0.0.1', 0))
        port = port_socket.getsockname()[1]
    server = subprocess.Popen(['pnpm', 'run', 'dev', '--port', str(port), '--host', '127.0.0.1'], cwd=root, env=env, start_new_session=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    try:
        for _ in range(50):
            assert server.poll() is None, server.communicate()[0][-1200:]
            try:
                with urllib.request.urlopen('http://127.0.0.1:' + str(port), timeout=1) as response:
                    assert b'guard-preview-ready' in response.read()
                    break
            except OSError: time.sleep(0.1)
        else: raise AssertionError('Vite did not serve the preview')
    finally:
        os.killpg(server.pid, signal.SIGTERM)
        server.communicate(timeout=5)
    print(json.dumps({'profile': label, 'versions': versions, 'passed': ['Java compile/run', 'Cargo offline build/run', 'PTY/Bash/pnpm', 'pnpm/Vite HTTP preview', 'GitHub existing token available', 'private file read/write denied', 'host Docker denied']}, ensure_ascii=False), flush=True)


if sys.argv[1:2] == ['--inside']:
    check(Path(sys.argv[2]), Path(sys.argv[3]))
else:
    source = Path(__file__).read_text()
    helper = runpy.run_path('/usr/local/libexec/claude-code-guard')
    env = helper['github_environment'](helper['clean_environment'](os.environ))
    with tempfile.TemporaryDirectory(prefix='guard-private-', dir=Path(__file__).parent) as private_root, tempfile.TemporaryDirectory(prefix='.guard-dev-', dir='/home/qiu/src') as root:
        private = Path(private_root)/'synthetic.txt'
        private.write_text('synthetic-private-fixture')
        for profile in ('claude-code-guard', 'claude-desktop-guard'):
            result = subprocess.run(['/usr/bin/setpriv', '--no-new-privs', '--', '/usr/bin/aa-exec', '-p', profile, '--', '/usr/bin/python3', '-I', '-c', source, '--inside', root, str(private)], env=env, text=True, capture_output=True, timeout=90)
            print(result.stdout, end='')
            assert result.returncode == 0, result.stderr[-2400:]
