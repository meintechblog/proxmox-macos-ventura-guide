# proxmox-macos-install-guide

Practical, tested guide to run macOS Tahoe on Proxmox VE 9 (Intel) with OpenCore.

## Scope

- Host: Proxmox VE 9
- CPU: Intel (VT-x)
- Guest: macOS Tahoe (26.x)
- Focus: stable boot, Apple-logo freeze mitigation, and host-safe VM-only changes

## Safety

- This project modifies VM configuration only.
- No GRUB edits, no kernel/module tweaks, no BIOS changes.
- Create snapshots before major guest updates.

## Quick Start

1. Follow the full install guide: [docs/INSTALL.md](docs/INSTALL.md)
2. Build Tahoe recovery image: `scripts/make_tahoe_recovery_fat.sh`
3. Optional VM rebuild helper: `scripts/vm900_rebuild.sh`
4. If needed, use fixes in: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

## Repo Layout

- `docs/INSTALL.md` - complete Tahoe install workflow
- `docs/TROUBLESHOOTING.md` - Tahoe-specific problems and fixes
- `scripts/make_tahoe_recovery_fat.sh` - build Tahoe recovery FAT image for Proxmox
- `scripts/vm900_rebuild.sh` - rebuild a VM with tested Tahoe settings
- `scripts/post_install_cleanup.sh` - remove recovery disk from boot order post-install

## Upstream Resources

- OpenCore ISO project:
  - https://github.com/LongQT-sea/OpenCore-ISO
  - https://github.com/LongQT-sea/OpenCore-ISO/releases
- macOS installer/recovery image builder:
  - https://github.com/LongQT-sea/macos-iso-builder
  - https://github.com/LongQT-sea/macos-iso-builder/releases

## Disclaimer

Use at your own risk. Ensure legal and licensing compliance for your environment.
