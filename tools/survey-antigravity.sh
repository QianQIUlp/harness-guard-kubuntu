#!/bin/sh
# One-off, read-only survey for writing the Antigravity and agy guards (round 2):
# where they keep their login, how they update, and how the app is installed.
# Run as qiu from Konsole (not from Antigravity's own terminal), with the Antigravity
# app open. Prints names, paths, owners and D-Bus method names only: no file
# contents, tokens or secret values. It runs `agy models` twice (once with the keyring
# unreachable); if agy is not logged in that way, it may open a login page: close it.
out=/tmp/claude-1000/antigravity-survey-2.txt
agy=$HOME/.local/bin/agy
mask() { sed -E 's/[A-Za-z0-9_.+=-]{32,}/<long>/g'; }
{
echo "== install"
readlink -f /usr/local/bin/antigravity
dpkg -S /opt/antigravity/antigravity /usr/share/applications/antigravity.desktop 2>&1
ls -la /opt/antigravity/resources /opt/antigravity/bin 2>&1
find /opt/antigravity/resources -maxdepth 2 \( -name '*.yml' -o -name '*.json' -o -name '*.asar' \) \
    -printf '%u %s %p\n'
for f in $(find /opt/antigravity/resources -maxdepth 3 \( -name product.json -o -name package.json \)); do
    python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(sys.argv[1], {k: d.get(k) for k in ("name","version","main","updateUrl","quality","dataFolderName","urlProtocol") if k in d})' "$f"
done
grep -hE '^(Name|Exec|MimeType)=' /usr/share/applications/antigravity*.desktop
echo "-- update and secret-storage code in the app"
grep -rhoE 'electron-updater|autoUpdater\.[a-zA-Z]+|safeStorage\.[a-zA-Z]+|keytar|password-store' \
    /opt/antigravity/resources 2>/dev/null | sort | uniq -c

echo "== app processes (flags only)"
for p in $(pgrep -f '^/opt/antigravity/'); do
    tr '\0' '\n' < "/proc/$p/cmdline" | grep -oE '^--(type|password-store|user-data-dir|ozone-platform)(=[^ ]*)?'
done | sort | uniq -c
echo "-- Chrome processes: parent and profile dir"
for p in $(pgrep -x chrome); do
    echo "$(readlink "/proc/$(ps -o ppid= -p "$p" | tr -d ' ')/exe") $(tr '\0' '\n' < "/proc/$p/cmdline" | grep -oE '^--user-data-dir=.*')"
done | sort | uniq -c
echo "-- agy-node launcher"
cat "$HOME/.config/Antigravity/bin/agy-node"
echo "-- key names in app and CLI settings"
for f in "$HOME/.config/Antigravity/Local State" "$HOME/.config/Antigravity/app_storage.json" \
         "$HOME/.gemini/config/config.json"; do
    python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(sys.argv[1], {k: sorted(v) if isinstance(v, dict) else type(v).__name__ for k, v in d.items()})' "$f" 2>&1
done
find "$HOME/.cache/antigravity" -maxdepth 2 -printf '%y %u %10s %p\n' | head -n 40

echo "== agy: credential storage and updates named in the binary"
strings -n 6 "$agy" | grep -oiE 'org\.freedesktop\.[Ss]ecret[A-Za-z.]*|org\.kde\.kwallet[A-Za-z0-9.]*|github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]*(keyring|keychain|secret|wallet|dbus)[A-Za-z0-9_./-]*|oauth_creds[A-Za-z0-9_.]*|[a-z_]*credentials?\.json|[a-z_]*token[a-z_]*\.json|(no|fallback|file)[a-z ]{0,12}keyring[A-Za-z _-]{0,40}|plaintext[A-Za-z _-]{0,30}' \
    | sort | uniq -c | sort -rn | head -n 60
"$agy" help update 2>&1 | head -n 20
"$agy" help install 2>&1 | head -n 20
echo "-- keyring messages in agy's logs"
grep -ohiE '(keyring|secret service|credential|keychain)[^"]{0,80}' "$HOME"/.gemini/antigravity-cli/log/*.log \
    | mask | sort | uniq -c | sort -rn | head -n 20

echo "== D-Bus keyring calls while agy starts (method names and paths only)"
touch /tmp/claude-1000/survey-marker
python3 - "$agy" <<'EOF'
import json, os, subprocess, sys, threading, time
agy = sys.argv[1]
names = ['org.freedesktop.secrets', 'org.kde.kwalletd6', 'org.kde.kwalletd5', 'org.kde.secretservicecompat']
mon = subprocess.Popen(['busctl', '--user', '--json=short', 'monitor', *names],
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
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

def read():
    for line in mon.stdout:  # secret values in replies are never printed or stored
        try:
            m = json.loads(line)
        except ValueError:
            continue
        if m.get('type') == 'error':
            key = ('error', m.get('error_name'))
        elif m.get('type') == 'method_call' and m.get('destination') in names:
            extra = ''
            if m.get('member') == 'SearchItems':
                data = m.get('payload', {}).get('data', [{}])[0]
                attrs = dict(data) if isinstance(data, dict) else {}
                extra = f" keys={sorted(attrs)} " + str({k: attrs[k] for k in ('service', 'application', 'xdg:schema') if k in attrs})
            key = (exe(m.get('sender', '')), m.get('destination'), m.get('interface'), m.get('member'), m.get('path') + extra)
        else:
            continue
        seen[key] = seen.get(key, 0) + 1

threading.Thread(target=read, daemon=True).start()
time.sleep(1)
env = dict(os.environ, AGY_CLI_DISABLE_AUTO_UPDATE='1')
r = subprocess.run(['timeout', '20', agy, 'models'], stdin=subprocess.DEVNULL, capture_output=True, text=True, env=env)
print(f'agy models: exit {r.returncode}, {len(r.stdout.splitlines())} lines of output')
time.sleep(2)
mon.terminate()
time.sleep(0.5)
if mon.stderr and (err := mon.stderr.read().strip()):
    print('busctl:', err[:200])
for key, count in sorted(seen.items(), key=str):
    print(count, *key)

print('-- same, with the keyring unreachable')
env['DBUS_SESSION_BUS_ADDRESS'] = 'unix:path=/nonexistent'
r = subprocess.run(['timeout', '20', agy, 'models'], stdin=subprocess.DEVNULL, capture_output=True, text=True, env=env)
print(f'agy models: exit {r.returncode}, {len(r.stdout.splitlines())} lines of output')
for line in r.stderr.splitlines()[:8]:
    print('  stderr:', line[:160])
EOF
echo "-- files agy changed during the test"
find "$HOME/.gemini" "$HOME/.config/Antigravity" "$HOME/.cache/antigravity" -newer /tmp/claude-1000/survey-marker \
    -type f -printf '%s %p\n' 2>/dev/null | head -n 30
} 2>&1 | sed -E 's/[A-Za-z0-9_.+=-]{48,}/<long>/g' | tee "$out"
echo "Saved to $out"
