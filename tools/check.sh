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
    for sock in /run/docker.sock /run/user/1000/systemd/private /run/user/1000/gnupg/S.gpg-agent; do
        python3 -c "import socket,sys; socket.socket(socket.AF_UNIX).connect(sys.argv[1])" "$sock" 2>/dev/null \
            && bad "$sock reachable" || ok "$sock denied"
    done
    exit $failed'

status=0
for profile in claude-code-guard claude-desktop-guard; do
    setpriv --no-new-privs -- aa-exec -p "$profile" -- /bin/sh -c "$probe" sh "$profile" || status=1
done
# Unguarded programs that would run something Claude can write: browser native-messaging
# hosts, desktop entries, autostart and user units pointing into a guarded writable area.
echo "unguarded launchers:"
writable="$HOME/src/|$HOME/.claude|$HOME/.config/Claude/|$HOME/.cache/claude-guard/|/tmp/claude-1000/|$HOME/.local/share/claude/|$HOME/.local/state/claude/"
hits=$(grep -lsE "(\"path\"|Exec|ExecStart)[\": =]+\"?($writable)" \
    ~/.config/google-chrome/NativeMessagingHosts/*.json ~/.config/chromium/NativeMessagingHosts/*.json \
    ~/.config/microsoft-edge/NativeMessagingHosts/*.json ~/.mozilla/native-messaging-hosts/*.json \
    ~/.local/share/applications/*.desktop ~/.config/autostart/*.desktop ~/.config/systemd/user/*.service)
[ -z "$hits" ] && echo "  ok    none point into a guarded writable area" || { echo "$hits" | sed 's/^/  FAIL  runs guard-writable code: /'; status=1; }

echo "denials this boot (most frequent):"
journalctl -k -b -q -g 'apparmor="DENIED".*profile="claude-' 2>/dev/null \
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
exit $status
