#!/bin/sh
# One-off, read-only survey of Antigravity and agy for writing their guards.
# Run as qiu from a normal terminal, with the Antigravity IDE open. Prints names,
# owners, versions and library names only: no file contents, tokens or settings.
out=/tmp/claude-1000/antigravity-survey.txt
{
echo "== IDE install"
stat -c '%U:%G %a %n' /opt/antigravity /opt/antigravity/antigravity /usr/local/bin/antigravity
ls /opt/antigravity
grep -E '"(nameShort|applicationName|dataFolderName|version|quality|updateUrl|urlProtocol)"' \
    /opt/antigravity/resources/app/product.json
echo "-- executables over 1 MB"
find /opt/antigravity -type f -perm -u+x -size +1M -printf '%u %s %p\n'
echo "-- non-root-owned files: $(find /opt/antigravity ! -user root | wc -l)"

echo "== agy"
stat -c '%U:%G %a %s %n' "$HOME/.local/bin/agy"
"$HOME/.local/bin/agy" --version 2>&1 | head -n 3
"$HOME/.local/bin/agy" --help 2>&1 | head -n 60
echo "-- libraries and variables named in the binary"
strings "$HOME/.local/bin/agy" | grep -oE 'github\.com/(zalando/go-keyring|99designs/keyring|danieljoos/wincred|creativeprojects/go-selfupdate|minio/selfupdate|inconshreveable/go-update|sanbornm/go-selfupdate)|AGY_[A-Z0-9_]+|GEMINI_[A-Z0-9_]+|ANTIGRAVITY_[A-Z0-9_]+' | sort -u
for f in $(find /opt/antigravity -type f -name 'language_server*' 2>/dev/null); do
    echo "-- $f"
    strings "$f" | grep -oE 'github\.com/(zalando/go-keyring|99designs/keyring)|ANTIGRAVITY_[A-Z0-9_]+|GEMINI_[A-Z0-9_]+' | sort -u
done

echo "== state (names and sizes only)"
for d in "$HOME/.gemini" "$HOME/.antigravity" "$HOME/.config/Antigravity" "$HOME/.cache/Antigravity" \
         "$HOME/.local/share/antigravity" "$HOME/.local/state/antigravity"; do
    [ -e "$d" ] && find "$d" -maxdepth 3 -not -path '*/node_modules/*' -printf '%y %u %10s %p\n' | head -n 120
done
ls -d "$HOME"/.config/*[Aa]ntigravity* "$HOME"/.cache/*[Aa]ntigravity* "$HOME"/.local/share/*[Aa]ntigravity* 2>/dev/null

echo "== running (executable paths only)"
for p in /proc/[0-9]*; do
    exe=$(readlink "$p/exe" 2>/dev/null) || continue
    case $exe in /opt/antigravity/*|*/agy|*chrome*) echo "$exe";; esac
done | sort | uniq -c

echo "== links, keyring and browser"
grep -hsE 'MimeType=.*antigravity|^Exec=.*antigravity' /usr/share/applications/*.desktop "$HOME"/.local/share/applications/*.desktop
grep -hsi antigravity "$HOME/.config/mimeapps.list"
busctl --user list --no-pager 2>/dev/null | awk '{print $1}' | grep -E 'secrets|kwalletd|gnome.keyring'
command -v google-chrome google-chrome-stable chromium chromium-browser
} 2>&1 | tee "$out"
echo "Saved to $out"
