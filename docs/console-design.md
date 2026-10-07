# Harness Guard console: design

Goal: one place to find every coding agent on this machine, run each inside its own
AppArmor guard, and decide per agent, per path, what it may touch. Changes apply
while the agent is running.

## What is installed (2026-10-06)

| Agent | Entry point / self-update target | State it must write | Credentials | Built-in sandbox (must be off or compatible) |
| --- | --- | --- | --- | --- |
| Claude Code | `~/.local/share/claude/versions/*` (guarded today) | `~/.claude*` | `~/.claude/.credentials.json` | bwrap, off; conflicts with path-based MAC |
| Claude Desktop | `/usr/lib/claude-desktop` (guarded today) | `~/.config/Claude` | KWallet `readPassword` | none |
| Codex CLI 0.159 | `~/.codex/packages/standalone/*`, link in `~/.local/bin` | `CODEX_HOME` (`~/.codex`) | `cli_auth_credentials_store = "file"` → `~/.codex/auth.json` | bwrap + Landlock + seccomp; Landlock alone stacks with AppArmor (to verify), else `danger-full-access` |
| ChatGPT / Codex app | `/usr/lib/chatgpt` (Electron) | to survey | to survey | to survey |
| Grok Build CLI | `~/.grok/bin`, updates into `~/.grok/downloads` | `~/.grok` | to survey | own `--sandbox` profiles; mechanism to verify |
| Copilot CLI | `~/.copilot/pkg` (auto-update) | `~/.copilot` | `GH_TOKEN` or keyring | `/sandbox`; off |
| OpenCode | `~/.opencode/bin` | `~/.config/opencode`, `~/.local/share/opencode` | `~/.local/share/opencode/auth.json` | none (permission prompts only) |
| Gemini CLI | not on PATH (state only) | `GEMINI_CLI_HOME/.gemini` | `~/.gemini` or keyring | docker/podman/runsc; off (Docker stays denied) |
| Antigravity IDE + `agy` | `/opt/antigravity`, `~/.local/bin/agy` | `~/.gemini/antigravity*` | keyring | `enableTerminalSandbox`; mechanism to verify |
| Kiro IDE | `/usr/share/kiro` (Electron) | `~/.kiro` | to survey | none; `permissions.yaml` prompts |
| VS Code (+Copilot) | `/usr/share/code` | `~/.config/Code`, `~/.vscode` | keyring | none |

Common rules that fall out of the research:

- **Credentials go to files inside the agent's own state dir.** The Secret Service
  (KWallet's `org.freedesktop.secrets`) can't be scoped per item, so allowing it to one
  agent would expose every stored secret. Agents that prefer the keyring are configured
  for file storage (Codex: `cli_auth_credentials_store = "file"`).
- **Built-in sandboxes that build mount namespaces (bwrap, Docker) are off.** Allowing
  arbitrary bind mounts inside an AppArmor profile lets a process re-mount a denied
  path under an allowed name. Landlock-only sandboxes stack safely and can stay on.
- **Self-updaters write next to their binary.** Each agent gets the same treatment as
  Claude Code: a root-owned forwarder at the entry point, and the updater sees a private
  writable copy of `~/.local/bin` (or writes inside its own version dir).
- **Each agent gets its own profile.** Codex can't read `~/.claude`, Claude can't read
  `~/.codex/auth.json`. Caches are per agent (`~/.cache/harness-guard/<agent>`).
- **IDEs are different.** Kiro, Antigravity, VS Code and the ChatGPT app are editors
  you also use by hand, and their agents run inside the same processes. A guard limits
  you too, so for them it is opt-in, with the work areas plus the file chooser.

## Live changes

AppArmor replaces a loaded profile in place: "all processes running under old profiles
will transparently be switched to the updated versions" (AppArmor techdoc). Path
permissions you change in the console apply to running agents within a second, with no
restart, and open file descriptors are revalidated on next use. Only launcher-level
settings (environment, which entry points are wrapped) take effect on the agent's
next start, and the console says so next to those settings.

## Pieces (built)

```text
agents/<id>.toml        reviewed, in this repo: profile, program, environment, private binds
apparmor/<profile>      reviewed, hand-written: the agent's own state, D-Bus, devices
/etc/harness-guard/policy.toml
                        root-owned: your choices per agent (paths none/r/rx/rw/rwx,
                        GitHub token); never writable by any agent
harness-guard-apply     policy -> /etc/apparmor.d/harness-guard/<id>, which each profile
                        includes; validated, checked with apparmor_parser -Q, then -r live
harness-guard <id>      the generic launcher: allowlisted env, changeprofile, verify
                        enforce, no_new_privs, private namespace
```

Only the paths you choose are generated. Everything an agent needs to work (its state,
D-Bus peers, devices) stays hand-written and reviewed, so a policy edit can't break an
agent's basics or open a D-Bus service. The compiler rejects globs, quotes, symlinks,
grants covering the whole home folder, and write grants overlapping anything unguarded
programs execute or read config from.

Policy example:

```toml
[agents.claude-code]
github_token = true
paths = [
  { path = "~/src/", access = "rwx" },
  { path = "~/src/private-notes/", access = "none" },
  { path = "~/Documents/spec.pdf", access = "r" },
]
```

`access = "none"` compiles to `audit deny`, which wins over any allow. A single file
granted `rw` can be edited in place, but editors that save through a temporary file and
rename need the directory.

## Console

- **Agents:** what was detected, whether each one is guarded and enforcing, version,
  and a switch to guard it (installs forwarders and the profile).
- **Permissions:** a path tree per agent with read / write / execute / deny per directory
  or file. Applying it shows the compiled rule diff before the password prompt.
- **Activity:** live AppArmor denials per agent (`journalctl -k -f`). Each one offers
  "allow this path" as the smallest matching rule.
- **Integrity:** today's `tools/check.sh` as a live view: profiles enforcing, forwarders
  root-owned, no unguarded launcher (desktop entry, autostart, browser native host)
  pointing into an agent-writable area, and agent deep links (`codex://`, ...) that
  would start an agent unguarded.

## Security of the console itself

- The console and compiler are installed root-owned under `/usr/local`, never run from
  this checkout, because `~/src` is writable by agents.
- Applying needs root through `pkexec` with `auth_admin` (your password every time).
  Every guard denies `pkexec`/`sudo` and sets `no_new_privs`, so no agent can apply
  policy. The console exposes no D-Bus or socket API an agent could drive.
- The policy file is root-owned; the console edits a copy and submits it to the
  privileged helper, which validates it before compiling and loading.

## Order of work

Scope for now: Claude Code, Claude Desktop, the Antigravity IDE and the `agy` CLI.
The other agents in the table stay unguarded until later.

1. Done: Claude fixes (private `/dev/pts`, entry profile, check additions).
2. Done: spec format, compiler and generic launcher, Claude ported. The expanded
   profiles match the hand-written ones except the new names and an added deny for
   `~/.local/share/{kwalletd,keyrings}`.
3. Antigravity app and `agy`. agy: done (`agy-guard`, file login, keyring denied),
   installed and checked 2026-10-07. The app is next. Known so far:
   - The app is an Electron build in `/opt/antigravity`, owned by qiu (not a package),
     with a Go `language_server`; its browser agent drives `/opt/google/chrome`. State in
     `~/.config/Antigravity` and `~/.cache/antigravity`; `antigravity://` links.
   - `agy` 1.2.16 is a qiu-owned binary in `~/.local/bin` with `agy update`; state in
     `~/.gemini` (`config/`, `antigravity-cli/`).
   - The owner wants agy limited to its own credential. KWallet's Secret Service gives
     items counter-based object paths (`<collection>/<n>`, renumbered on restart), and
     `GetSecrets` takes any item list, so AppArmor D-Bus rules can't pin one entry.
     Round 2 confirmed agy uses the Secret Service (`SearchItems` on the default alias
     with `service=gemini`, then `GetSecret` on one item) and fails without it. agy
     switches to file storage (`~/.gemini/antigravity-cli/antigravity-oauth-token`)
     when it sees an SSH session (`SSH_CONNECTION` and similar, per
     soyelmismo/hermes-antigravity-subscription#18 on 1.2.14). If that works on 1.2.16,
     the agy guard sets it and denies the keyring; otherwise the owner accepts
     Secret Service access for agy. Confirmed on 1.2.16: with the keyring
     unreachable, a fresh `agy --print` used the file login.
   - agy 1.0.x's container file storage was write-only
     (google-antigravity/antigravity-cli#479), so test that a fresh process reads it.
4. Console UI for the four agents.
