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

- The console and compiler are installed root-owned by the package (`/usr/lib`,
  `/usr/libexec`, `/usr/sbin`), never run from this checkout, because `~/src` is
  writable by agents.
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
3. Done: Antigravity app and `agy` (`agy-guard`, `antigravity-guard`, file logins,
   keyring denied), installed and checked 2026-10-07, including sign-in and agy as
   Claude's subagent. `bin/xdg-open` calls the portal directly: `gio open` starts the
   default browser itself and uses the portal only if that start fails, which inside a
   guard it never does (the browser is denied after GLib reports success). From the
   app's code (2.19.1) and a runtime survey:
   - Electron in qiu-owned `/opt/antigravity`, started by `/usr/local/bin/antigravity`
     and `~/.local/share/applications/antigravity.desktop`. electron-updater picks the
     AppImage updater (no `resources/package-type`), which is inactive without
     `APPIMAGE`, so the guard keeps `/opt/antigravity` read-only.
   - The app spawns `resources/bin/language_server` (`--app_data_dir antigravity`, so
     `~/.gemini/antigravity`) with the login shell's environment (`shell-env`). The
     language server shares agy's token code: Secret Service entry `service=gemini`
     (it also calls `CreateItem`), or the file `jetski-standalone-oauth-token` in an
     SSH session or when the keyring fails. `SSH_CONNECTION` also switches sign-in to
     a paste-the-code flow (`TerminalTokenAcquirer`) that the app only logs, so the app
     runs without it: the guard refuses the Secret Service quietly and the language
     server falls back to its file, with the normal browser sign-in.
   - The browser agent uses the app's own CDP port (`--remote-debugging-port=0`,
     `DevToolsActivePort` in `~/.config/Antigravity`), not Chrome. Terminals are plain
     bash; MCP servers run through nvm `npx` or `~/.config/Antigravity/bin/agy-node`
     (`ELECTRON_RUN_AS_NODE`).
   - D-Bus: the same tray, notification, portal and systemd-scope calls as Claude
     Desktop, so both use `abstractions/harness-guard-electron` (Desktop's compiled
     profile is byte-identical after the move).
   - agy as Claude's subagent: a guard can't switch into another (`no_new_privs`; a
     stacked label would only intersect both profiles), so the launcher hands the
     request to `harness-guard-handoff`, a per-connection user socket service outside
     the guards. It checks the caller's label (`SO_PEERSEC`) against agy's
     `handoff_from`, takes the working directory as a descriptor the caller opened, and
     runs the normal launcher. This is the one socket an agent can drive; it can only
     start the listed agent in that agent's own guard.
4. Console UI for the four agents (`console/`, PyQt6 + Kirigami 6, loaded from the
   system QML modules only). Agents, Integrity and Activity are read-only; Permissions
   edits a copy and applies it with `pkexec harness-guard-apply --replace SHA256`, the
   reviewed text on stdin. The agent table's switch to guard a new agent, and a tree
   view of paths, wait until more agents are in scope; paths are a flat list.
5. Done: the console's own look and an agent-centred layout (below).
6. Done: state as colour, starting and stopping agents, history, tray and
   notifications (below).
7. Built, waiting for the owner's install check: one application that installs,
   updates and removes everything (below).

## Look

The visual floor is me.qiu.works: warm paper, ink and one red, hairlines, large type,
small letter-spaced mono captions, IBM Plex Sans/Serif/Mono. Light/dark follows the
system. The controls are drawn by the console (Qt Quick Basic), not Breeze.

- An agent's state is a field of colour, so it reads before any word: **red** is open
  (not guarded or not enforcing: needs you), **ink** is running (held, active, with
  its last three minutes of processes along the floor), **paper** is idle (held, at
  rest). The overview cards and the agent page's hero use the same fills; the rail and
  logs use the same three as small squares (round dots are checks). An open agent's
  name is a hairline outline.
- The hero carries the one action that matters in that state: Start (idle), New
  session and Stop (running CLI), Stop (running app), "what the check says" (open).
- Numbers that matter are set large (places it reaches, it can write, refused in 24
  hours, GitHub token) and turn red while edited.
- Red stays reserved for "needs you": open guards, failed checks, refusals worth
  allowing, unapplied edits.

## Running agents from the console

Start runs `/usr/libexec/harness-guard/launcher AGENT` directly, never the entry point
(which may no longer be the forwarder), so it fails closed like any other start. CLI
agents (`terminal = true` in their spec) open in Konsole in a folder you choose,
remembered per agent. Stop sends SIGTERM to every process whose label is the agent's
profile, after a second click.

## History, tray and notifications

`~/.local/state/harness-guard-console/` (no guard can write it) keeps 60 days of:
refusals per agent per hour (recomputed for the current boot from the journal, so a
restart never double-counts), check runs (pass/fail counts), and a log of starts,
stops, guards opening or closing, and applied policies. Closing the window leaves the
console in the tray, where it keeps following the journal and re-probes every agent's
guard every 30 s. It notifies when a guard opens, when the check starts failing, and
what an agent was just refused (at most every 10 minutes per agent), unless its window
has focus. "Start at login" writes the user's own autostart entry for `--tray`. A
second start signals the first (SIGUSR1, after checking that PID is a console of this
user) to show its window, so there is still no socket.

## One application

Until 0.7 `install.sh` was the installer, run as root from this checkout, with paths
for one user on one machine. Now it is an application you install once, from a
release, and remove once, leaving the machine as it was:

- **A Debian package** (`harness-guard_VERSION_all.deb`, built by a script in this
  repository and attached to releases). Kubuntu installs it with a double click
  (Discover) or `apt install ./harness-guard_*.deb`, and removes it the same way.
  dpkg owns every system file, so removal can't leave strays. The package moves the
  program out of `/usr/local` (`/usr/lib/harness-guard`, `/usr/libexec/harness-guard`,
  `/usr/sbin/harness-guard-apply`, `/usr/bin/harness-guard-console`). Updates are
  newer packages; the console can show when a newer release exists, but it never
  installs anything without the same `pkexec` password.
- **Guarding an agent is an action in the app, with a receipt.** What `install.sh`
  does per agent today (forwarders, the Desktop diversion, moving `agy`, the
  Antigravity menu entry, Cowork's device) becomes `harness-guard-setup guard AGENT`
  and `release AGENT`, a root helper run through `pkexec`. Before changing anything it
  records the original (file contents, owner, mode, diversion) in
  `/var/lib/harness-guard/receipts/AGENT.json`; `release` puts exactly that back. The
  package's `prerm` releases every agent, so uninstalling restores the machine.
- **Per machine, not per user.** The user, home and UID come from
  `/etc/harness-guard/owner.toml`, which postinst detects once (the sudo user, else the
  first UID 1000 user) and keeps on upgrade. `harness-guard-apply` writes them to
  `/etc/apparmor.d/tunables/harness-guard` as `@{HG_USER}`, `@{HG_HOME}` and `@{HG_UID}`,
  which every profile includes, so the profiles name no one. The launcher expands
  `{uid}` in the agent specs. Only the four agents are supported. The same file holds
  `@{HG_ATTACH_*}`: the vendor paths a profile attaches to while its agent has a receipt,
  so a released agent runs as its vendor ships it; setup reloads after each guard and release.
- **Detecting agents.** `harness-guard-setup status` reports which of the four are
  installed (their vendor program is at its standard place). The console lists only
  those, and Settings lets you guard or release each one.
- The development path stays: `./install.sh` builds the package from this checkout
  as you (`fakeroot`) and `sudo apt install`s it, so there is one way in and one way
  out, and no root code runs from `~/src`.
- **Upgrades** keep the receipts: prerm releases only on removal, and the new
  postinst reapplies each guard (newer forwarder text), keeping the recorded originals
  and recording only items the new version adds. Installing over the old
  `/usr/local` layout first undoes it, so the first receipts record the original
  machine. An agent you release by name stays released across upgrades until you
  guard it again (or purge).
