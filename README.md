# appimage-watcher

Drop an `.AppImage` into `~/Apps`. A systemd **user** service makes it executable, installs missing Fedora libraries, and adds a GNOME launcher entry. Deleting the file removes the entry.

Tested on Fedora 45 Workstation (GNOME / Wayland, SELinux enforcing).

## Install

```bash
git clone <repo-url> ~/Projects/appimage-watcher
cd ~/Projects/appimage-watcher
./install.sh
```

This creates `~/Apps`, installs `~/.local/bin/appimage-watcher`, enables `appimage-watcher.service`, and (via Polkit) installs `inotify-tools` and `fuse-libs` if they are missing.

```bash
./uninstall.sh
```

Uninstall leaves `~/Apps` contents and the RPM packages in place.

## Usage

1. Copy or move a file named `*.AppImage` (any case) into `~/Apps`.
2. Wait a few seconds while the size settles (handles slow copies).
3. Open the GNOME app launcher; the app should appear.
4. Delete the AppImage from `~/Apps` to drop the launcher entry and icon.

Partial downloads (`.part`, `.crdownload`, `.tmp`) are ignored.

## Design choices

**Watcher:** `inotifywait` (from `inotify-tools`). Small C tool with `close_write` / `moved_to` / `delete`, no extra Python package. If it is missing, the service polls every 2 seconds.

**Privilege:** `pkexec dnf install -y …`. Each package install shows a Polkit dialog. Safer than a passwordless sudoers rule for `dnf`, which would let any process of yours install RPMs unattended. You approve each transaction.

**FUSE:** Type 2 AppImages need `libfuse.so.2` (`fuse-libs`). If it cannot be installed, the `.desktop` `Exec=` line uses `--appimage-extract-and-run` and the log says so.

**`--no-sandbox`:** Added only for Electron apps when `unshare -Ur` fails (no user namespaces).

**SELinux:** Left enforcing. AppImages get `restorecon`; SELinux is never disabled.

## Config

`~/.config/appimage-watcher/config` (see `config.example`):

| Key | Default | Meaning |
| --- | --- | --- |
| `WATCH_DIR` | `~/Apps` | Folder to watch |
| `STABLE_SECONDS` | `3` | Size must be unchanged this many seconds |
| `SMOKE_TEST` | `0` | `1` runs `--appimage-version` only (no GUI) |
| `INSTALL_DEPS` | `1` | `0` skips `pkexec` / `dnf` |

## Layout

```
appimage-watcher          # watcher daemon (bash)
appimage-watcher.service  # systemd user unit
install.sh / uninstall.sh
config.example
```

Installed files:

- `~/.local/bin/appimage-watcher`
- `~/.config/systemd/user/appimage-watcher.service`
- `~/.local/share/applications/appimage-<name>.desktop`
- `~/.local/share/icons/hicolor/<size>/apps/appimage-<name>.png`
- `~/.local/state/appimage-watcher/` (log + state)

## Logs

```bash
journalctl --user -u appimage-watcher -f
tail -f ~/.local/state/appimage-watcher/log
appimage-watcher --status
```

## Troubleshooting

**Launcher entry missing.** Check the log. Run `update-desktop-database ~/.local/share/applications`. GNOME search can take a moment; try searching for the app name.

**App does not start (FUSE).** Confirm `rpm -q fuse-libs` and `ls /usr/lib64/libfuse.so.2`. If Polkit was dismissed, re-run `pkexec dnf install -y fuse-libs` or set `INSTALL_DEPS=1` and drop the file again. The fallback is `--appimage-extract-and-run` in the desktop file.

**Polkit dialog never appears.** The service needs a graphical session. `systemctl --user restart appimage-watcher` after login.

**SELinux denials.** Keep enforcing. Inspect with `ausearch -m avc -ts recent | grep -i -e fuse -e appimage`. Fix labels with `restorecon` on the AppImage; do not `setenforce 0`.

**Duplicate launchers.** This tool writes `~/.local/share/applications/appimage-<name>.desktop` only. Other leftover `.desktop` files are left alone.

**Same app, new version.** Drop the new AppImage; the existing `appimage-<name>.desktop` is reused and `Exec=` points at the newest file (by mtime).

## Manual commands

```bash
appimage-watcher --reconcile          # scan ~/Apps once
appimage-watcher --process FILE       # integrate one file
appimage-watcher --status
systemctl --user restart appimage-watcher
```

## License

MIT
