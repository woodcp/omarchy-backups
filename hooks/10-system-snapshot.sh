#!/usr/bin/env bash
# omarchy-backups pre-backup hook: snapshot system state that lives outside
# $HOME into a directory the backup already captures. Runs before every backup.
#
# No-root items are always captured. Root-only items (network secrets, custom
# sudo rules) are copied only when this hook can read them — run a backup once
# with sudo, or leave them out. See the README.
set -uo pipefail
out="${OMARCHY_BACKUPS_SYSTEM_DIR:-$HOME/.local/state/omarchy-backups/system}"
mkdir -p "$out"; chmod 700 "$out"

# --- package manifests (the key to rebuilding the machine) ------------------
if command -v pacman >/dev/null; then
  pacman -Qqe  > "$out/packages-explicit.txt" 2>/dev/null || true   # explicitly installed
  pacman -Qqm  > "$out/packages-aur.txt"      2>/dev/null || true   # AUR / foreign
  pacman -Q    > "$out/packages-all.txt"      2>/dev/null || true   # everything, with versions
fi

# --- hand-edited config, world-readable -------------------------------------
for f in /etc/fstab /etc/hosts /etc/os-release /etc/mkinitcpio.conf /etc/vconsole.conf /etc/locale.conf; do
  [[ -r $f ]] && install -m600 "$f" "$out/${f##*/}" 2>/dev/null || true
done

# --- enabled services (state, not files) ------------------------------------
systemctl list-unit-files --state=enabled --no-legend 2>/dev/null | awk '{print $1}' > "$out/services-enabled.txt" || true
systemctl --user list-unit-files --state=enabled --no-legend 2>/dev/null | awk '{print $1}' > "$out/services-enabled-user.txt" || true

# --- root-only items: copy only if readable (e.g. a sudo run) ---------------
if [[ -r /etc/sudoers.d ]]; then
  mkdir -p "$out/sudoers.d"; chmod 700 "$out/sudoers.d"
  cp -a /etc/sudoers.d/. "$out/sudoers.d/" 2>/dev/null || true
fi
if [[ -r /etc/NetworkManager/system-connections ]]; then
  mkdir -p "$out/network-connections"; chmod 700 "$out/network-connections"
  cp -a /etc/NetworkManager/system-connections/. "$out/network-connections/" 2>/dev/null || true
fi

date -Iseconds > "$out/captured-at.txt"
