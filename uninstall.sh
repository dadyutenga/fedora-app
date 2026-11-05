#!/usr/bin/env bash
# Reverse install.sh. Leaves ~/Apps contents and system packages in place.
set -euo pipefail

HOME_DIR="${HOME}"
BIN="${HOME_DIR}/.local/bin/appimage-watcher"
UNIT="${HOME_DIR}/.config/systemd/user/appimage-watcher.service"
STATE_DIR="${HOME_DIR}/.local/state/appimage-watcher"
STATE_FILE="${STATE_DIR}/state.tsv"
DESKTOP_DIR="${HOME_DIR}/.local/share/applications"
ICON_ROOT="${HOME_DIR}/.local/share/icons/"

echo "Stopping appimage-watcher..."
systemctl --user disable --now appimage-watcher.service 2>/dev/null || true
rm -f "${UNIT}"
systemctl --user daemon-reload || true

if [[ -f "${STATE_FILE}" ]]; then
  echo "Removing desktop entries and icons created by the watcher..."
  while IFS=$'\t' read -r path app_id size mtime desktop icons; do
    [[ "${path}" == \#* ]] && continue
    if [[ -n "${desktop:-}" && "${desktop}" == "${DESKTOP_DIR}/appimage-"*.desktop ]]; then
      rm -f "${desktop}"
    fi
    IFS=':' read -ra arr <<<"${icons:-}"
    for ic in "${arr[@]}"; do
      [[ -n "${ic}" && "${ic}" == "${ICON_ROOT}"* ]] && rm -f "${ic}"
    done
  done <"${STATE_FILE}"
fi

# Catch any leftover watcher-owned desktop files
shopt -s nullglob
for d in "${DESKTOP_DIR}"/appimage-*.desktop; do
  if grep -q '^X-AppImage-Watcher=1' "${d}" 2>/dev/null; then
    rm -f "${d}"
  fi
done
shopt -u nullglob

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "${DESKTOP_DIR}" >/dev/null 2>&1 || true
fi

rm -f "${BIN}"
rm -rf "${STATE_DIR}"

echo "Removed the watcher binary, user service, state, and launcher entries it created."
echo "Left in place: ${HOME_DIR}/Apps, ~/.config/appimage-watcher, inotify-tools, fuse-libs."
echo "Delete those manually if you want a full wipe."
