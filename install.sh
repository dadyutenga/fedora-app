#!/usr/bin/env bash
# Install the AppImage auto-installer (user systemd service).
set -euo pipefail

PREFIX="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${HOME}"
BIN_DIR="${HOME_DIR}/.local/bin"
UNIT_DIR="${HOME_DIR}/.config/systemd/user"
CFG_DIR="${HOME_DIR}/.config/appimage-watcher"
STATE_DIR="${HOME_DIR}/.local/state/appimage-watcher"
WATCH_DIR="${HOME_DIR}/Apps"

echo "AppImage auto-installer setup"
echo "  source: ${PREFIX}"

mkdir -p "${BIN_DIR}" "${UNIT_DIR}" "${CFG_DIR}" "${STATE_DIR}" "${WATCH_DIR}" \
  "${HOME_DIR}/.local/share/applications" \
  "${HOME_DIR}/.local/share/icons/hicolor"

SHARE_DIR="${HOME_DIR}/.local/share/appimage-watcher"
mkdir -p "${SHARE_DIR}"
install -m 0755 "${PREFIX}/appimage-watcher" "${BIN_DIR}/appimage-watcher"
install -m 0644 "${PREFIX}/appimage-watcher.service" "${UNIT_DIR}/appimage-watcher.service"
if [[ -f "${PREFIX}/README.md" ]]; then
  install -m 0644 "${PREFIX}/README.md" "${SHARE_DIR}/README.md"
fi
if [[ ! -f "${CFG_DIR}/config" && -f "${PREFIX}/config.example" ]]; then
  install -m 0644 "${PREFIX}/config.example" "${CFG_DIR}/config"
fi

need=()
rpm -q inotify-tools >/dev/null 2>&1 || need+=(inotify-tools)
rpm -q fuse-libs >/dev/null 2>&1 || need+=(fuse-libs)

if (( ${#need[@]} )); then
  echo
  echo "The following packages are missing: ${need[*]}"
  echo "  inotify-tools  - directory watcher (inotifywait)"
  echo "  fuse-libs      - libfuse.so.2 for type 2 AppImages"
  echo
  echo "A Polkit dialog will ask for your password (pkexec)."
  echo "No sudoers rule is installed (safer: approval each time, no passwordless dnf)."
  echo
  pkexec /usr/bin/dnf install -y "${need[@]}"
else
  echo "Required packages already present (inotify-tools, fuse-libs)."
fi

systemctl --user daemon-reload
systemctl --user enable --now appimage-watcher.service

echo
echo "Enabled user service: appimage-watcher.service"
systemctl --user --no-pager --full status appimage-watcher.service || true
echo
echo "Drop .AppImage files into ${WATCH_DIR}"
echo "Logs: journalctl --user -u appimage-watcher -f"
echo "      ${STATE_DIR}/log"
