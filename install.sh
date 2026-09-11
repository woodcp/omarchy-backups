#!/usr/bin/env bash
# Install omarchy-backups: link the tool, seed config, add the Super+B binding
# and floating window rule, and enable the nightly timer.
#
# Reuses an existing ~/.config/cold-storage-backup config (repo, password,
# excludes) if present, so an earlier setup keeps its snapshots.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
key="${BACKUPS_KEY:-SUPER + B}"
key_desc="$key"
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

# Bootstrap an encryption key on a fresh machine (no migrated password).
new_key=0
if [[ ! -s $cfg/password ]]; then
  ( umask 077; head -c 300 /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9' | cut -c1-40 > "$cfg/password" )
  new_key=1
fi
chmod 600 "$cfg/password"

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

if (( new_key )); then
  key=$(cat "$cfg/password")
  echo
  echo "  ┌────────────────────────────────────────────────────────────────┐"
  echo "  │   SAVE YOUR BACKUP ENCRYPTION KEY                               │"
  echo "  └────────────────────────────────────────────────────────────────┘"
  echo
  echo "  A new key was generated to encrypt your backups:"
  echo
  echo "      $key"
  echo
  echo "  This key is the ONLY way to restore your backups. Copy it into"
  echo "  your password manager now."
  echo
  echo "  It lives on this machine at:"
  echo "      $cfg/password"
  echo "  You can show it again with:  omarchy-backups key"
  echo "  But if THIS MACHINE is lost, only your saved copy can decrypt the"
  echo "  backup drive. No copy, no restore."
  echo
  if [[ -t 0 ]]; then
    if command -v gum >/dev/null; then
      until gum confirm "I have saved the encryption key in my password manager"; do :; done
    else
      read -r -p "  Type 'saved' once you have copied the key: " ack
      while [[ $ack != saved ]]; do read -r -p "  Type 'saved' to continue: " ack; done
    fi
  fi
fi
echo
echo "Installed. Press $key_desc for the dashboard."
(( new_key )) || echo "Encryption key: $cfg/password (keep a copy in your password manager)."
echo "Press $key for the dashboard, or run: omarchy-backups status"
