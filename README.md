📄 README.md (full file)
# btrfs CoW Self-Healing Guard

## Overview

This tool automatically detects and fixes high disk IO issues on Btrfs systems by safely applying the `chattr +C` flag (No CoW) to appropriate directories.

It is designed to:

- Reduce IO contention
- Prevent CoW fragmentation
- Improve performance under heavy write workloads
- Avoid unsafe or unsupported operations

---

## ⚠️ Safety Principles

- Never modifies unsupported filesystems
- Never applies changes to system-critical paths blindly
- Skips directories that do not exist
- Logs all actions for auditability
- Uses explicit validation before making changes

---

## Supported Filesystems

- ✅ Btrfs (only filesystem where `+C` is valid)
- ❌ ext4, xfs, tmpfs (skipped automatically)

---

## What It Does

The script:

1. Detects filesystem type for each target directory
2. Validates whether `chattr +C` is supported
3. Applies the flag only when safe
4. Logs:
   - Applied changes
   - Skipped paths (with reason)
   - Failures
5. Scans Firefox cache directories (`~/.mozilla/**/cache2`) safely
6. Avoids `/tmp` when it is `tmpfs`

---

## Target Directories

Default monitored paths:

- `~/.cache`
- `~/.local/share/Trash`
- `~/Downloads`
- `/var/cache`
- `~/.mozilla/cache2`
- `/tmp` (only if applicable)

---

## Requirements

- Linux system
- `btrfs` filesystem
- `chattr` available (`e2fsprogs`)
- `iostat` (optional but recommended)

---

## Installation

```bash
git clone https://github.com/YOUR_USERNAME/btrfs-cow-self-healing-guard.git
cd btrfs-cow-self-healing-guard
chmod +x btrfs_coW_self_healing_guard.sh
Usage
./btrfs_coW_self_healing_guard.sh

Logs are written to:

/tmp/btrfs_coW_guard.log
Example Output
[2026-04-09 14:27:36] APPLY: chattr +C /home/owner/.cache
[2026-04-09 14:27:36] SUCCESS: +C applied to /home/owner/.cache

[2026-04-09 14:27:36] SKIP: /tmp is tmpfs (CoW not applicable)
[2026-04-09 14:27:36] SKIP: /home/owner/projects/build-dir does not exist
Limitations
Only affects directories on Btrfs
Does not modify already-existing files inside directories
Does not migrate existing data to NoCoW automatically
Advanced Notes
Firefox cache (cache2) is targeted instead of entire profile to avoid corruption risk
/tmp is skipped when using tmpfs
Safe for repeated execution (idempotent behavior)
Future Enhancements
systemd service integration
real-time IO monitoring loop
automatic rollback on performance degradation
adaptive throttling based on IO pressure
License

MIT License