#!/bin/sh
# One-off survey for writing the Antigravity app guard (round 3). Run as qiu from
# Konsole with the Antigravity app closed. It copies the app's own code (app.asar, which
# holds no user data) and the strings of its language_server to /tmp/claude-1000, then
# starts the app and records what it does: processes and flag names, environment
# variable names, D-Bus method names, listening ports and the paths it writes. No file
# contents, tokens or secret values are saved.
dir=/tmp/claude-1000/antigravity-3
out=$dir/survey.txt
app=/opt/antigravity
mask() { sed -E 's/[A-Za-z0-9_.+=-]{32,}/<long>/g'; }
if pgrep -f "^$app/" >/dev/null; then
    echo "Quit Antigravity first (File > Quit), then run this again." >&2
    exit 1
fi
mkdir -p "$dir"
if [ ! -s "$dir/language_server.strings" ]; then
echo "Copying the app's code..."
python3 - "$app/resources/app.asar" "$dir/app" <<'EOF'
import json, os, struct, sys
src, dst = sys.argv[1], sys.argv[2]
with open(src, 'rb') as f:
    size = struct.unpack('<I', f.read(8)[4:])[0]
    header = f.read(size)
    tree = json.loads(header[8:8 + struct.unpack('<I', header[4:8])[0]])
    base = 8 + size
    def walk(node, path):
        for name, entry in node.get('files', {}).items():
            p = os.path.join(path, name)
            if 'files' in entry:
                walk(entry, p)
            elif 'offset' in entry and not entry.get('unpacked'):
                os.makedirs(path, exist_ok=True)
                f.seek(base + int(entry['offset']))
                with open(p, 'wb') as o:
                    o.write(f.read(entry['size']))
    walk(tree, dst)
EOF
strings -n 6 "$app/resources/bin/language_server" > "$dir/language_server.strings"
fi

{
echo "== install"
cat "$app/resources/app-update.yml"
find "$app" -maxdepth 1 -printf '%u %m %p\n'
find "$app/resources" -printf '%u %m %s %p\n' | grep -v "^[^ ]* [^ ]* [^ ]* $app/resources/app.asar.unpacked/.*/.*/.*/" | head -n 60
ls -la /usr/local/bin/antigravity "$HOME/.config/Antigravity/bin" 2>&1
sysctl kernel.apparmor_restrict_unprivileged_userns kernel.unprivileged_userns_clone 2>&1
echo "-- state folders (names only)"
for d in "$HOME/.config/Antigravity" "$HOME/.cache/antigravity" "$HOME/.gemini" "$HOME/.local/share/antigravity" "$HOME/.antigravity"; do
    [ -e "$d" ] && find "$d" -maxdepth 2 -printf '%y %p\n' | grep -v "^. $HOME/.gemini/config/skills/" | head -n 60
done
find "$HOME/.gemini/antigravity" -maxdepth 1 -printf '%y %m %p\n'
} 2>&1 | mask > "$out"

touch "$dir/marker"
python3 - "$app" "$dir" <<'EOF' 2>&1 | mask >> "$out"
import json, os, re, subprocess, sys, threading, time
app, dir = sys.argv[1], sys.argv[2]
mon = subprocess.Popen(['busctl', '--user', '--json=short', 'monitor'],
                       stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
seen, exes = {}, {}

def exe(name):
    if name not in exes:
        try:
            pid = subprocess.run(['busctl', '--user', 'call', 'org.freedesktop.DBus', '/org/freedesktop/DBus',
                                  'org.freedesktop.DBus', 'GetConnectionUnixProcessID', 's', name],
                                 capture_output=True, text=True).stdout.split()[-1]
            exes[name] = os.readlink(f'/proc/{pid}/exe')
        except Exception:
            exes[name] = '?'
    return exes[name]

def generic(path):
    return re.sub(r'/(_?[0-9a-f_]{6,}|[0-9]+|_[0-9_]+)(?=/|$)', '/<n>', path or '')

def read():
    for line in mon.stdout:  # secret values in payloads are never printed or stored
        try:
            m = json.loads(line)
        except ValueError:
            continue
        if m.get('type') != 'method_call':
            continue
        src, dst = exe(m.get('sender', '')), exe(m.get('destination', ''))
        if not (src.startswith(app) or dst.startswith(app)):
            continue
        extra = ''
        data = m.get('payload', {}).get('data', [])
        if m.get('member') == 'SearchItems' and data and isinstance(data[0], dict):
            extra = ' ' + str({k: data[0][k] for k in ('service', 'application', 'xdg:schema') if k in data[0]}) + f' keys={sorted(data[0])}'
        elif m.get('interface') == 'org.kde.KWallet' and not m.get('member', '').startswith('write'):
            extra = ' ' + str([d for d in data if isinstance(d, str)])
        name = m.get('destination', '')
        key = (src, '->', dst, '' if name.startswith(':') else name,
               m.get('interface'), m.get('member'), generic(m.get('path')) + extra)
        seen[key] = seen.get(key, 0) + 1

threading.Thread(target=read, daemon=True).start()
time.sleep(1)
subprocess.Popen(['setsid', f'{app}/antigravity'], stdin=subprocess.DEVNULL,
                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
with open('/dev/tty', 'w') as tty:  # stdin is this script, stdout goes to the file
    tty.write('''
Antigravity is starting. In it:
  1. Open (or create) a project under ~/src.
  2. Ask its agent to run `ls` in a terminal, then to open https://example.com in its browser.
  3. Wait until it has done both, leave the app open, and press Enter here.
''')
with open('/dev/tty') as tty:
    tty.readline()

def tree():
    procs = {}
    for p in os.listdir('/proc'):
        try:
            stat = open(f'/proc/{p}/stat').read()
            procs[int(p)] = int(stat.rsplit(')', 1)[1].split()[1])
        except Exception:
            pass
    roots = {p for p in procs if os.path.realpath(f'/proc/{p}/exe').startswith(app)}
    found, grew = set(roots), True
    while grew:
        new = {p for p, pp in procs.items() if pp in found} - found
        found |= new
        grew = bool(new)
    return procs, found

procs, found = tree()
print('== processes started by the app: exe, parent exe, label, flags (values only for some)')
keep = ('type', 'user-data-dir', 'ozone-platform', 'password-store', 'remote-debugging-port', 'app_data_dir',
        'enable-features', 'disable-features', 'utility-sub-type', 'gemini_dir', 'extension_server_port')
rows, envs = {}, {}
for p in sorted(found):
    try:
        e = os.path.realpath(f'/proc/{p}/exe')
        pe = os.path.realpath(f'/proc/{procs[p]}/exe')
        label = open(f'/proc/{p}/attr/current').read().strip()
        args = open(f'/proc/{p}/cmdline').read().split('\0')[1:]
        names = [kv.split('=', 1)[0] for kv in open(f'/proc/{p}/environ').read().split('\0') if kv]
    except Exception:
        continue
    flags = []
    for a in args:
        m = re.match(r'--?([A-Za-z0-9_-]+)(=(.*))?', a)
        if m:
            flags.append(m.group(1) + (f'={m.group(3)}' if m.group(3) and m.group(1) in keep else ''))
        elif a.startswith('/'):
            flags.append('<path>' + a)
    rows.setdefault((e, pe, label, ' '.join(flags)), 0)
    rows[(e, pe, label, ' '.join(flags))] += 1
    envs.setdefault(e, set()).update(names)
for (e, pe, label, flags), n in sorted(rows.items()):
    print(n, e, '<-', pe, f'[{label}]', flags)
print('-- environment variable names by program (beyond the Konsole session)')
base = set(os.environ)
for e, names in sorted(envs.items()):
    print(e, sorted(names - base))
print('-- Chrome browsers running now: parent exe, flags')
for p in sorted(procs):
    try:
        if os.path.realpath(f'/proc/{p}/exe').startswith('/opt/google/chrome/'):
            args = open(f'/proc/{p}/cmdline').read().split('\0')
            if not any(a.startswith('--type=') for a in args):
                print(os.path.realpath(f'/proc/{procs[p]}/exe'), [re.sub(r'=(?!/).*', '=', a) for a in args[1:] if a.startswith('-')])
    except Exception:
        pass
print('-- listening sockets of the app')
for cmd in (['ss', '-ltnpH'], ['ss', '-lxpH']):
    for line in subprocess.run(cmd, capture_output=True, text=True).stdout.splitlines():
        if any(f'pid={p},' in line for p in found):
            print(' ', re.sub(r'\s+', ' ', line))

mon.terminate()
time.sleep(0.5)
print('== D-Bus method calls to or from the app (program -> program, name, interface, member, path)')
for key, count in sorted(list(seen.items()), key=str):
    print(count, *key)
EOF

{
echo "== paths written since the app started, grouped (count, folder)"
find "$HOME" /tmp /run/user/1000 -xdev -newer "$dir/marker" \( -type f -o -type s \) 2>/dev/null \
    | grep -vE "^($dir|/tmp/claude-1000/|$HOME/\.cache/claude|$HOME/\.claude|$HOME/\.config/Claude/)" \
    | sed -E "s#^($HOME/[^/]+/[^/]+/[^/]+|/tmp/[^/]+|/run/user/1000/[^/]+).*#\1#" | sort | uniq -c | sort -rn | head -n 50
echo "-- key names in app settings now"
for f in "$HOME/.config/Antigravity/Local State" "$HOME/.config/Antigravity/app_storage.json"; do
    python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(sys.argv[1], {k: sorted(v) if isinstance(v, dict) else type(v).__name__ for k, v in d.items()})' "$f" 2>&1
done
} 2>&1 | mask >> "$out"
echo "Saved to $dir (survey.txt, app/, language_server.strings). You can leave Antigravity open."
