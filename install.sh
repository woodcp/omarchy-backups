#!/usr/bin/env bash
# Install omarchy-backups: link the tool, seed config, add the Super+B binding
# and floating window rule, and enable the nightly timer.
#
# Reuses an existing ~/.config/cold-storage-backup config (repo, password,
# excludes) if present, so an earlier setup keeps its snapshots.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
key="${BACKUPS_KEY:-SUPER + B}"
cfg="$HOME/.config/omarchy-backups"
bindings="$HOME/.config/hypr/bindings.lua"

mkdir -p "$HOME/.local/bin" "$cfg" "$HOME/.config/systemd/user"
ln -sfn "$here/bin/omarchy-backups" "$HOME/.local/bin/omarchy-backups"

# Seed config, migrating from the older cold-storage-backup if it exists.
old="$HOME/.config/cold-storage-backup"
[[ -f $cfg/config   ]] || cp "$here/config.example"   "$cfg/config"
if [[ -f $old/excludes && ! -f $cfg/excludes ]]; then cp "$old/excludes" "$cfg/excludes"; else [[ -f $cfg/excludes ]] || cp "$here/excludes.example" "$cfg/excludes"; fi
if [[ -f $old/password && ! -f $cfg/password ]]; then cp "$old/password" "$cfg/password"; fi
[[ -f $cfg/sources ]] || cp "$here/sources.example" "$cfg/sources"
[[ -f $cfg/password ]] && chmod 600 "$cfg/password" || true

# systemd timer.
install -m644 "$here/systemd/omarchy-backups.service" "$HOME/.config/systemd/user/"
install -m644 "$here/systemd/omarchy-backups.timer"   "$HOME/.config/systemd/user/"
systemctl --user daemon-reload
systemctl --user enable --now omarchy-backups.timer

# Retire the older cold-storage-backup timer if it was running.
if systemctl --user is-enabled cold-storage-backup.timer >/dev/null 2>&1; then
  systemctl --user disable --now cold-storage-backup.timer || true
  echo "Disabled the old cold-storage-backup.timer (config and snapshots kept)."
fi

# Hyprland binding. The presentation floating terminal already floats and themes gum.
if ! grep -q 'omarchy-backups' "$bindings" 2>/dev/null; then
  cat >> "$bindings" <<LUA

-- omarchy-backups: restic backup dashboard (https://github.com/woodcp/omarchy-backups)
o.bind("$key", "Backups", "omarchy-launch-floating-terminal-with-presentation omarchy-backups")
LUA
  echo "Added binding $key to $bindings"
fi
hyprctl reload >/dev/null 2>&1 && hyprctl configerrors || true

echo "Installed. Password file: $cfg/password (keep a copy in your password manager)."
echo "Press $key for the dashboard, or run: omarchy-backups status"
