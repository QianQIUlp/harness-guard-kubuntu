# Validation and remaining limits

These results come from saved deployment tests and interface confirmation. Packaging did not repeat them. Versions, hashes, labels, and device permissions are in the timestamped [deployment snapshot](../evidence/deployment-2026-10-06.json).

| Behavior | Evidence and scope |
| --- | --- |
| Private-file boundary | Both guards denied synthetic private-file reads/writes; prior CLI tests covered src read/write, symlink escape denial, and inherited restrictions in Git hooks, offline npm scripts, and compiled children |
| Native CLI execution | Enforce label, NNP=1, CapEff/CapAmb=0; one earlier authorized model request succeeded and was not repeated |
| CLI update/activation | Official update 2.1.289 to 2.1.291; official install selected 2.1.289 for the next normal entry and then restored 2.1.291; immutable host entry preserved |
| Desktop package update | Actual update to 2.19675.1 and reboot preserved the LOCAL diversion, guard, and native process confinement |
| Actual desktop interface | Three window controls, tray, and startup toggle confirmed; the conversation terminal produced an interactive shell prompt |
| Quit | At 18:18, native tray Quit ended the main process and all guarded helpers after menu launch |
| Startup state | Native creation/atomic replacement/disable worked in the private view; host entry write/delete/rename were denied; state returned to disabled |
| GTK/images | Correct three-control layout and SVG decode; actual SVG helper inherited the main enforce label |
| Desktop services | URI dispatch, public settings, file dialog open/cancel, and shortcut-session create/list/close; no key-binding changes |
| Audio/Cowork prerequisites | Device query and 100 ms silent playback; KVM/vhost-vsock opening and helper execution; no recording or full VM task |
| Development tools, 20:31–20:34 | Both guards passed Java 25 compile/run, Rust/Cargo 1.88 offline build/run, PTY/Bash/pnpm 11.17, and pnpm/Vite HTTP; private-file and host Docker denial also passed |
| GitHub during tool repair | Existing token retrieval/inheritance and HTTPS helper configuration tested locally; no remote API, push, or PR validation in that phase |
| Shell initialization | Public im-config and kernel UUID reads restored; both login shells passed; private migration credentials remained denied |
| Rollback | Default Desktop inspection passed; actual rollback was not executed |

The 20:47 snapshot includes earlier native process observations: CLI at 18:48 and Desktop at 20:31. PIDs are historical, not current process identities. The Desktop process list was captured while the application remained open; it is not evidence of Quit failure. An empty terminal-process list does not negate a previously opened terminal. A stale loaded `glycin-bwrap` label does not identify the current SVG helper's label.

## Unverified or intentionally unavailable

- Complete new OAuth, microphone recording, every MCP/plugin integration, a full Cowork VM task, and every update channel were not individually validated.
- Existing KWallet key use works; initialization after key loss/replacement has no extra write permission. Vendor sensitive-configuration exception behavior was not changed and has no observed current trigger.
- Non-GitHub private credentials and root Docker service access remain unavailable. Go/Ruby are not installed. The private migration credential script may still warn during shell startup.
- Different installers, new NVM versions, and another host need their own dependency review. A successful current update does not prove every future layout.

## Repository packaging

Packaging checks cover Python syntax, existing launcher self-checks, offline AppArmor parsing, GTK compilation, installed-source comparison, local documentation links, and staged content. No application restart, kernel policy load, system modification, rollback, or model request is part of packaging. The result is recorded in [the packaging receipt](../evidence/repository-check-2026-10-06.json).

The private GitHub repository creation and push are a separate authorized publication operation. They do not broaden the repair-phase account-validation claims above.
