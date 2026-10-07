#!/usr/bin/python3
"""Round trip of bin/harness-guard-setup in a fake root, without root: root-only tools
(chattr, dpkg-divert, systemctl, setfacl, modprobe, chown) are emulated. Checks that
guard, guard again and release leave every file exactly as it was, including after
changes made while guarded.  Usage: tools/test-setup.py [bin/harness-guard-setup]"""
import os, sys, shutil, tempfile, types, json, io, contextlib, hashlib, subprocess
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), '../bin/harness-guard-setup')
R = tempfile.mkdtemp()
H = f'{R}/home/qiu'
def mk(path, data=b'', mode=0o644):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'wb') as f: f.write(data)
    os.chmod(path, mode)
mk(f'{R}/etc/harness-guard/owner.toml', f'user = "qiu"\nuid = {os.getuid()}\ngid = {os.getgid()}\nhome = "{H}"\n'.encode())
for a, p in [('claude-code','claude-code-guard'),('claude-desktop','claude-desktop-guard'),('agy','agy-guard'),('antigravity','antigravity-guard')]:
    mk(f'{R}/etc/harness-guard/agents/{a}.toml', f'name = "{a}"\nprofile = "{p}"\n'.encode())
os.makedirs(f'{H}/.local/share/claude/versions'); mk(f'{H}/.local/share/claude/versions/2.1.291', b'ELF claude', 0o755)
mk(f'{H}/.local/share/claude/versions/2.1.300', b'ELF claude new', 0o755)
os.makedirs(f'{H}/.local/bin'); os.symlink(f'{H}/.local/share/claude/versions/2.1.291', f'{H}/.local/bin/claude')
mk(f'{H}/.local/bin/agy', b'ELF agy' * 1000, 0o755)
os.makedirs(f'{H}/.local/state/claude', mode=0o700)
mk(f'{H}/.local/share/applications/antigravity.desktop', f'Name=Antigravity\nName[zh]=反重力\nExec={R}/opt/antigravity/antigravity %U\n'.encode(), 0o600)
mk(f'{R}/opt/antigravity/antigravity', b'ELF app', 0o755)
os.makedirs(f'{R}/usr/local/bin'); os.symlink('/opt/antigravity/antigravity', f'{R}/usr/local/bin/antigravity')
mk(f'{R}/usr/lib/claude-desktop/claude-desktop', b'ELF desktop', 0o755)
os.makedirs(f'{R}/etc/modules-load.d'); os.makedirs(f'{R}/etc/udev/rules.d')
mk(f'{R}/dev/vhost-vsock', b'', 0o600)
os.utime(f'{H}/.local/share/applications/antigravity.desktop', ns=(10**18, 10**18))

src = open(SRC).read()
for s in ("'/etc/harness-guard'", "'/var/lib/harness-guard'", "'/usr/lib/claude-desktop/claude-desktop'",
          "'/opt/antigravity/antigravity'", "'/usr/local/bin/antigravity'", "'/dev/vhost-vsock'"):
    assert s in src, s
    src = src.replace(s, f"'{R}" + s[1:])
src = src.replace("f'/etc/modules-load.d", f"f'{R}/etc/modules-load.d").replace("'/etc/modules-load.d", f"'{R}/etc/modules-load.d")
src = src.replace("'/etc/udev/rules.d", f"'{R}/etc/udev/rules.d")
src = src.replace("if __name__ == '__main__':", "if False:")
m = types.ModuleType('setup'); m.__file__ = SRC
exec(compile(src, SRC, 'exec'), m.__dict__)

frozen, diversions, acl, modules, units = set(), {}, set(), set(), {'enabled': False}
log = []
class Res:
    def __init__(s, out='', rc=0): s.stdout, s.stderr, s.returncode = out, '', rc
def run(*c, check=True):
    log.append(c)
    tool = os.path.basename(c[0])
    if tool == 'lsattr': return Res(('----i---- ' if c[-1] in frozen else '--------- ') + c[-1])
    if tool == 'chattr':
        (frozen.add if c[1] == '+i' else frozen.discard)(c[-1]); return Res()
    if tool == 'dpkg-divert':
        if c[1] == '--truename': return Res(diversions.get(c[2], c[2]))
        if '--add' in c:
            p = c[-1]; to = c[c.index('--divert') + 1]; move(p, to); diversions[p] = to; return Res()
        if '--remove' in c:
            p = c[-1]; move(diversions.pop(p), p); return Res()
    if tool == 'systemctl':
        if 'is-enabled' in c: return Res('enabled' if units['enabled'] else 'disabled', 0 if units['enabled'] else 1)
        units['enabled'] = 'enable' in c; return Res()
    if tool == 'getfacl': return Res(f'user:{m.UID}:rw-' if c[-1] in acl else '')
    if tool == 'setfacl': (acl.add if c[1] == '-m' else acl.discard)(c[-1]); return Res()
    if tool == 'modprobe': (modules.discard if '-r' in c else modules.add)(c[-1]); return Res()
    if tool == 'dpkg-query': return Res('0.7.0')
    raise AssertionError(c)
m.run = run
m.user_systemctl = lambda *a: Res()
m.module_loaded = lambda n: n in modules
m.running = lambda p: False
real_chown = os.chown
m.os = types.SimpleNamespace(**{k: getattr(os, k) for k in dir(os) if not k.startswith('__')})
owners = {}
def chown(p, uid, gid, follow_symlinks=True): owners[p] = (uid, gid)
def lstat(p):
    st = os.lstat(p); u, g = owners.get(p, (st.st_uid, st.st_gid))
    return types.SimpleNamespace(**{**{k: getattr(st, k) for k in dir(st) if k.startswith('st_')}, 'st_uid': u, 'st_gid': g})
def move(a, b):
    os.replace(a, b)
    if a in owners: owners[b] = owners.pop(a)
    else: owners.pop(b, None)
def unlink(p): os.unlink(p); owners.pop(p, None)
m.os.chown, m.os.lstat, m.os.replace, m.os.rename, m.os.unlink = chown, lstat, move, move, unlink
m.os.path = os.path

def tree():
    out = {}
    for base, dirs, files in os.walk(R):
        if base.startswith(R + '/var'): continue
        if base == R: dirs[:] = [d for d in dirs if d != 'var']
        for n in dirs + files:
            p = os.path.join(base, n); st = os.lstat(p)
            if os.path.islink(p): out[p] = ('l', os.readlink(p), st.st_mtime_ns)
            elif os.path.isdir(p): out[p] = ('d', oct(st.st_mode))
            else: out[p] = ('f', hashlib.sha256(open(p,'rb').read()).hexdigest(), oct(st.st_mode), st.st_mtime_ns, p in frozen, (lstat(p).st_uid, lstat(p).st_gid))
    return out, set(frozen), dict(diversions), set(acl), set(modules), dict(units)

def cli(*args):
    sys.argv = ['harness-guard-setup', *args]
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        rc = m.main()
    return rc, buf.getvalue()

geteuid = os.geteuid
m.os.geteuid = lambda: 0
before = tree()
print(cli('status')[1])
rc, out = cli('guard', '--detected'); print(rc, out)
assert rc == 0
fw = lambda a: f'#!/bin/sh\nexec /usr/libexec/harness-guard/launcher {a} "$@"\n'.encode()
assert open(f'{H}/.local/bin/claude','rb').read() == fw('claude-code') and f'{H}/.local/bin/claude' in frozen
assert open(f'{H}/.local/bin/agy','rb').read() == fw('agy') and open(f'{H}/.local/state/agy/guard-bin/agy','rb').read() == b'ELF agy'*1000
assert open(f'{H}/.local/state/claude/guard-bin/agy','rb').read() == fw('agy')
assert open(f'{R}/usr/lib/claude-desktop/claude-desktop','rb').read() == fw('claude-desktop')
assert open(f'{R}/usr/lib/claude-desktop/claude-desktop.real','rb').read() == b'ELF desktop'
assert open(f'{R}/usr/local/bin/antigravity','rb').read() == fw('antigravity')
assert f'Exec={R}/usr/local/bin/antigravity %U\n'.encode() in open(f'{H}/.local/share/applications/antigravity.desktop','rb').read()
assert units['enabled'] and acl and modules
guarded = tree()
rc, out = cli('guard', '--detected'); assert rc == 0, out
assert tree() == guarded, 'second guard changed something'
print(cli('status')[1]); print(json.dumps(json.loads(cli('status', '--json')[1])['agents'][1], indent=1)[:900])
rc, out = cli('release', '--all'); print(rc, out); assert rc == 0
after = tree()
if after != before:
    a, b = before[0], after[0]
    for k in sorted(set(a) | set(b)):
        if a.get(k) != b.get(k): print('DIFF', k, a.get(k), b.get(k))
    print(before[1:], after[1:])
    raise SystemExit('NOT RESTORED')
print('round trip: identical')

# Release by name is remembered; --detected skips it; guard by name clears it.
cli('guard', 'agy'); cli('release', 'agy')
rc, out = cli('guard', '--detected'); assert 'agy' not in out, out
rc, out = cli('status'); assert 'released by you' in out, out
cli('release', '--all'); cli('guard', 'agy'); assert not os.path.exists(f'{R}/var/lib/harness-guard/released/agy')
cli('release', '--all')
assert tree() == before, 'second round not restored'

# Things that changed while guarded: Claude's original version removed, the menu entry
# rewritten by a reinstall, agy updated in its private view.
cli('guard', '--detected')
os.unlink(f'{H}/.local/share/claude/versions/2.1.291')
os.symlink(f'{H}/.local/share/claude/versions/2.1.300', f'{H}/.local/state/claude/guard-bin/claude')
mk(f'{H}/.local/share/applications/antigravity.desktop', f'Exec={R}/opt/antigravity/antigravity %U\nVersion=2\n'.encode(), 0o644)
mk(f'{H}/.local/state/agy/guard-bin/agy', b'ELF agy v2', 0o755)
rc, out = cli('release', '--all'); print(rc, out)
assert os.readlink(f'{H}/.local/bin/claude').endswith('2.1.300')
assert b'Version=2' in open(f'{H}/.local/share/applications/antigravity.desktop','rb').read()
assert open(f'{H}/.local/bin/agy','rb').read() == b'ELF agy v2'
assert not os.listdir(f'{R}/var/lib/harness-guard/receipts')

# Each agent's exec (agents/*.toml, through its private view) must exist after a guard:
# Desktop's launcher runs the diverted .real, so a diversion elsewhere breaks it.
import tomllib
AGENTS = os.path.join(os.path.dirname(SRC), '../agents')
def real(p): return H + p[1:] if p.startswith('~') else R + p
def execs():
    missing = []
    for name in sorted(os.listdir(AGENTS)):
        spec = tomllib.load(open(os.path.join(AGENTS, name), 'rb'))
        path = spec['exec']
        for src, dst in spec.get('binds', []):
            if path.startswith(dst + '/'): path = src + path[len(dst):]
        if not os.access(real(path), os.X_OK):
            latest = spec.get('latest')  # the launcher links the newest version on first run
            if not (latest and real(latest['link']) == real(path) and os.listdir(real(latest['versions']))):
                missing.append(f'{name}: {real(path)}')
    return missing

# Desktop already diverted elsewhere (the old install.sh left .distrib): refused, nothing changed.
desktop = f'{R}/usr/lib/claude-desktop/claude-desktop'
move(desktop, desktop + '.distrib'); diversions[desktop] = desktop + '.distrib'
with_distrib = tree()
try:
    cli('guard', 'claude-desktop'); raise AssertionError('guarded on top of a foreign diversion')
except m.SetupError as e:
    print('refused:', e); assert '.distrib, not' in str(e)
assert tree() == with_distrib, 'a refused guard changed something'
assert not os.path.exists(f'{R}/var/lib/harness-guard/receipts/claude-desktop.json')
rc, out = cli('guard', '--detected'); print(rc, out)
assert rc != 0, 'guard --detected skipped the foreign diversion silently'
assert not os.path.exists(f'{R}/var/lib/harness-guard/receipts/claude-desktop.json')
cli('release', '--all')
assert tree() == with_distrib, 'release after a refused guard'
move(diversions.pop(desktop), desktop)  # what postinst's cleanup_legacy does: --rename --remove

# Uninstall, install, uninstall, install (prerm releases all, postinst guards detected).
base = tree()
for n in (1, 2):
    rc, out = cli('guard', '--detected'); assert rc == 0, out
    assert not execs(), f'install {n}: missing exec {execs()}'
    assert diversions == {desktop: desktop + '.real'}, diversions
    rc, out = cli('release', '--all'); assert rc == 0, out
    assert tree() == base, f'uninstall {n} not restored'
print('install/uninstall rounds: identical, every exec present')

# A guard plants a symlink where root will write: refused, nothing written there.
cli('release', '--all')
shutil.rmtree(f'{H}/.local/state/claude/guard-bin', ignore_errors=True)
os.makedirs(f'{R}/elsewhere'); os.symlink(f'{R}/elsewhere', f'{H}/.local/state/claude/guard-bin')
try:
    cli('guard', 'agy'); raise AssertionError('followed a planted symlink')
except m.SetupError as e:
    print('refused:', e)
assert os.listdir(f'{R}/elsewhere') == []
print('ALL OK')
shutil.rmtree(R)
