# omarchy-backups

Encrypted, versioned local backups for [Omarchy](https://omarchy.org), with a
one-key dashboard. Press **Super+B** for a menu that backs up now, browses and
restores snapshots, and checks the repository. A nightly timer runs it
unattended.

Built on [restic](https://restic.net): backups are deduplicated, compressed,
encrypted, and snapshotted, so you keep months of history in a fraction of the
space and can pull back any file from any night. The backup drive stays
readable by Windows, which suits a repurposed NTFS backup volume.

## Why

A backup should be boring: it runs on its own, it never fills the disk, and a
restore is one command when you need it. This wires restic to a local drive
with sensible defaults so you get that without assembling it yourself.

## Install

```bash
git clone https://github.com/woodcp/omarchy-backups.git ~/Work/omarchy-backups
~/Work/omarchy-backups/install.sh
```

The installer symlinks the tool into `~/.local/bin`, seeds config under
`~/.config/omarchy-backups/`, adds a **Super+B** binding, enables a nightly
timer, and reloads Hyprland. If an older `cold-storage-backup` setup is
present, its repository, password, and excludes are carried over so no history
is lost. Choose a different key with `BACKUPS_KEY="SUPER + SHIFT + B"` before
running it.

### Requirements

- `restic` (`omarchy pkg add restic`)
- `gum` for the menu, part of a stock Omarchy install
- A mounted backup drive (see below)

## First-time drive setup

The backup targets a drive mounted at a fixed path. To make an existing NTFS
volume a permanent mount, add it to `/etc/fstab` (adjust UUID and point):

```
UUID=<disk-uuid>  /mnt/cold-storage  ntfs3  rw,nofail,uid=1000,gid=1000,umask=022,windows_names  0 0
```

`nofail` means a missing drive never blocks boot, and the backup cleanly skips
a run when the drive is unmounted rather than writing to nowhere. Find the UUID
with `lsblk -no UUID <device>`.

Then set `REPO` and `MOUNT` in `~/.config/omarchy-backups/config` to match.

## The dashboard

Press **Super+B**:

| Choice | What it does |
|--------|--------------|
| Back up now | Run a backup and prune old snapshots |
| Status | Drive state, latest snapshot, disk usage |
| Browse snapshots | Page through every snapshot |
| Restore a file | Pick a snapshot and path, restore to a folder |
| Verify a restore | Restore one file and confirm it matches the original |
| Check integrity | Verify the repository's packs and blobs |
| Edit config | Open the config in your editor |

## Command line

```bash
omarchy-backups now                       # back up and prune
omarchy-backups status                    # quick health line
omarchy-backups snapshots                 # list snapshots
omarchy-backups verify                    # prove a restore works
omarchy-backups restore latest ~/Restored --include ~/Work/afoa/notes.md
omarchy-backups check                     # repository integrity
```

Any other arguments pass straight through to `restic` against the configured
repository, so `omarchy-backups diff <a> <b>` and friends work too.

## Configuration

`~/.config/omarchy-backups/`:

| File | Purpose |
|------|---------|
| `config` | Repository path, mount point, retention counts |
| `sources` | One path per line to back up (`~` expands; missing paths are skipped) |
| `excludes` | restic exclude patterns (caches, build output, container data) |
| `password` | The repository encryption key |

Default retention keeps 7 daily, 4 weekly, 6 monthly, and 2 yearly snapshots.

> **Keep a copy of `password` in your password manager.** It is the encryption
> key. Without it the backup cannot be restored, and it lives nowhere else.

## What is and isn't backed up

Backed up: your work, documents, media, and real config, including `.config`,
`.ssh`, `.gnupg`, and shell files. Skipped by default: caches, downloads,
package stores, browser and chat data, and container-owned database
directories, which are unreadable at the file level and inconsistent if copied
live. Back databases up with a proper dump instead.

## Restore from scratch

On a fresh machine: install restic, mount the drive, put the password back in
place, then

```bash
restic -r /mnt/cold-storage/Omarchy/restic restore latest --target /
```

## License

MIT, Wood Consulting Partners, LLC.
