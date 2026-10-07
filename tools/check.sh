#!/bin/sh
# Smoke test for the agent guards. Run as qiu from a normal terminal, after install.sh.
probe='
    ok() { echo "  ok    $1"; }
    bad() { echo "  FAIL  $1"; failed=1; }
    failed=0
    echo "$1:"
    # aa-exec from an unconfined shell stacks on "unconfined" on this kernel; file
    # mediation is the same. The launcher itself must get a clean label (checked below).
    label=$(cat /proc/self/attr/current)
    case $label in "$1 (enforce)"|"$1//&unconfined (enforce)") ok "enforcing";; *) bad "label is $label";; esac
    file=$(mktemp -p ~/src .guard-check.XXXXXX) && rm "$file" && ok "~/src writable" || bad "~/src not writable"
    for path in ~/.ssh ~/.gnupg ~/.config/gh ~/.config/kwalletd ~/.mozilla ~/.bash_history; do
        if [ -d "$path" ]; then ls "$path"; else cat "$path"; fi >/dev/null 2>&1 \
            && bad "$path readable" || ok "$path denied"
    done
    for path in ~/.bashrc ~/.profile ~/.gitconfig; do
        (: >> "$path") 2>/dev/null && bad "$path writable" || ok "$path not writable"
    done
    probe=~/.config/autostart/.guard-check
    (: > "$probe") 2>/dev/null && { rm -f "$probe"; bad "autostart writable"; } || ok "autostart not writable"
    sudo -n true 2>/dev/null && bad "sudo runs" || ok "sudo denied"
    busctl --user call org.freedesktop.secrets /org/freedesktop/secrets org.freedesktop.DBus.Properties \
        Get ss org.freedesktop.Secret.Service Collections >/dev/null 2>&1 \
        && bad "Secret Service reachable" || ok "Secret Service denied"
    [ "$1" = agy-guard ] || { ls ~/.gemini/antigravity-cli >/dev/null 2>&1 \
        && bad "agy login readable" || ok "agy login denied"; }
    [ "$1" = antigravity-guard ] || { ls ~/.gemini/antigravity >/dev/null 2>&1 \
        && bad "Antigravity login readable" || ok "Antigravity login denied"; }
    for sock in /run/docker.sock /run/user/1000/systemd/private /run/user/1000/gnupg/S.gpg-agent; do
        python3 -c "import socket,sys; socket.socket(socket.AF_UNIX).connect(sys.argv[1])" "$sock" 2>/dev/null \
            && bad "$sock reachable" || ok "$sock denied"
    done
    case $1 in claude-*) ;; *)  # only Claude may start agy
        python3 -c "import socket,sys; socket.socket(socket.AF_UNIX).connect(sys.argv[1])" \
            /run/user/1000/harness-guard-handoff.sock 2>/dev/null \
            && bad "agy hand-off reachable" || ok "agy hand-off denied";;
    esac
    exit $failed'

status=0
for profile in claude-code-guard claude-desktop-guard agy-guard antigravity-guard; do
    setpriv --no-new-privs -- aa-exec -p "$profile" -- /bin/sh -c "$probe" sh "$profile" || status=1
done
# Unguarded programs that would run something Claude can write: browser native-messaging
# hosts, desktop entries, autostart and user units pointing into a guarded writable area.
echo "unguarded launchers:"
writable="$HOME/src/|$HOME/.claude|$HOME/.config/Claude/|$HOME/.cache/claude-guard/|/tmp/claude-1000/|$HOME/.local/share/claude/|$HOME/.local/state/claude/|$HOME/.gemini/|$HOME/.cache/agy-guard/|/tmp/agy-1000/|$HOME/.local/state/agy/|$HOME/.config/Antigravity/|$HOME/.cache/antigravity-guard/|/tmp/antigravity-1000/"
hits=$(grep -lsE "(\"path\"|Exec|ExecStart)[\": =]+\"?($writable)" \
    ~/.config/google-chrome/NativeMessagingHosts/*.json ~/.config/chromium/NativeMessagingHosts/*.json \
    ~/.config/microsoft-edge/NativeMessagingHosts/*.json ~/.mozilla/native-messaging-hosts/*.json \
    ~/.local/share/applications/*.desktop ~/.config/autostart/*.desktop ~/.config/systemd/user/*.service)
[ -z "$hits" ] && echo "  ok    none point into a guarded writable area" || { echo "$hits" | sed 's/^/  FAIL  runs guard-writable code: /'; status=1; }

echo "denials this boot (most frequent):"
journalctl -k -b -q -g 'apparmor="DENIED".*profile="(claude-|agy-|antigravity-)' 2>/dev/null \
    | grep -oE 'profile="[^"]+".*' | sed -E 's/ (pid|fsuid|ouid|denied_mask|comm|requested|info|error|class)=[^ ]*//g' \
    | sort | uniq -c | sort -rn | head -n 15 | sed 's/^/  /'

echo "policy:"
[ "$(stat -c %u:%a /etc/harness-guard/policy.toml 2>/dev/null)" = 0:644 ] \
    && echo "  ok    /etc/harness-guard/policy.toml root-owned" || { echo "  FAIL  policy.toml missing or not root-owned 644"; status=1; }
compiled=$(/usr/local/sbin/harness-guard-apply --print 2>&1)
loaded=$(for f in /etc/apparmor.d/harness-guard/*; do printf '== %s\n%s\n\n' "${f##*/}" "$(cat "$f")"; done)
[ "$compiled" = "$loaded" ] && echo "  ok    loaded rules match the policy" \
    || { echo "  FAIL  policy changed or invalid; run: sudo harness-guard-apply"; status=1; }

echo "launcher:"
claude --version >/dev/null && echo "  ok    claude --version through the launcher (clean label, private namespace)" \
    || { echo "  FAIL  claude --version"; status=1; }
agy --version >/dev/null && echo "  ok    agy --version through the launcher" \
    || { echo "  FAIL  agy --version"; status=1; }
[ "$(stat -c %u ~/.local/bin/agy)" = 0 ] && lsattr ~/.local/bin/agy 2>/dev/null | grep -q '^....i' \
    && echo "  ok    ~/.local/bin/agy is a root-owned, immutable forwarder" \
    || { echo "  FAIL  ~/.local/bin/agy is not the guard's forwarder"; status=1; }
[ "$(stat -c %u ~/.local/state/claude/guard-bin/agy)" = 0 ] \
    && lsattr ~/.local/state/claude/guard-bin/agy 2>/dev/null | grep -q '^....i' \
    && echo "  ok    Claude Code's private ~/.local/bin/agy is a root-owned, immutable forwarder" \
    || { echo "  FAIL  Claude Code's private ~/.local/bin/agy is not the guard's forwarder"; status=1; }
# The hand-off must be running and refuse callers outside the guards it lists.
python3 - <<'PY' && echo "  ok    the agy hand-off is running and refuses unguarded callers" \
    || { echo "  FAIL  agy hand-off (systemctl --user status harness-guard-handoff.socket)"; status=1; }
import json, os, socket
request = json.dumps({'agent': 'agy', 'args': ['--version']}).encode()
null = os.open('/dev/null', os.O_RDWR)
with socket.socket(socket.AF_UNIX) as conn:
    conn.connect('/run/user/1000/harness-guard-handoff.sock')
    socket.send_fds(conn, [len(request).to_bytes(4, 'big') + request],
                    [null, null, null, os.open('.', os.O_RDONLY | os.O_DIRECTORY)])
    raise SystemExit(conn.recv(4, socket.MSG_WAITALL) != (126).to_bytes(4, 'big', signed=True))
PY
[ ! -L /usr/local/bin/antigravity ] && grep -qs harness-guard /usr/local/bin/antigravity \
    && grep -qx 'Exec=/usr/local/bin/antigravity %U' ~/.local/share/applications/antigravity.desktop \
    && echo "  ok    the antigravity command and menu entry go through the launcher" \
    || { echo "  FAIL  Antigravity starts without the launcher (rerun install.sh after reinstalling it)"; status=1; }
echo "console:"
owned=ok
for file in /usr/local/lib/harness-guard-console/harness-guard-console /usr/local/lib/harness-guard-console/main.qml \
            /usr/local/libexec/harness-guard-check /usr/share/polkit-1/actions/org.harness-guard.apply.policy; do
    [ "$(stat -c %u "$file" 2>/dev/null)" = 0 ] && [ $(( 0$(stat -c %a "$file") & 022 )) = 0 ] || owned=
done
[ -n "$owned" ] && [ "$(readlink /usr/local/bin/harness-guard-console)" = /usr/local/lib/harness-guard-console/harness-guard-console ] \
    && echo "  ok    the console and its pkexec action are installed root-owned" \
    || { echo "  FAIL  console files missing or writable by others (rerun install.sh)"; status=1; }
exit $status
