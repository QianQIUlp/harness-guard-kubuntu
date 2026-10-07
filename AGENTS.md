# Notes for agents working on this repository

This repository defines the AppArmor guard that confines you. Read `README.md` first.

- You can edit the repository but can't apply it: installation needs sudo, which is
  denied inside the guard. The owner runs `./install.sh` (builds the Debian package, then `sudo apt install`) and
  `tools/check.sh`. Root code never runs from `~/src`: only the installed package does.
- Never weaken a boundary to make something work without saying so explicitly: no new
  write access to paths that unguarded programs execute or read config from (shell
  startup files, autostart, `~/.local/bin`, shared caches, `~/.config/gh`, `~/.gitconfig`).
- Prefer the smallest rule that fixes an observed denial (`journalctl -k | grep apparmor`
  on the host). Check AppArmor, GLib/GTK, Glycin, and Electron behavior against
  version-matched docs (Context7) or upstream source.
- Decisions the owner has already made: the whole of `~/src` is a work area; GitHub
  credentials are allowed; Desktop may use KWallet `readPassword`; Cowork gets
  `/dev/vhost-vsock`; Docker and other credentials stay denied; global KDE settings
  and network routing are not changed.
- Never commit tokens, wallet contents, private application config, or session logs.
