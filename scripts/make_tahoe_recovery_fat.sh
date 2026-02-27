#!/usr/bin/env bash
set -euo pipefail

OUTDIR="${1:-/root/com.apple.recovery.tahoe}"
IMG="${2:-/var/lib/vz/template/iso/recovery-tahoe-fat.img}"
MNT="/mnt/recovery-tahoe"
BOARD_ID="Mac-CFF7D910A743CAAF"
MLB="00000000000000000"

if [[ -x /root/OpenCorePkg/Utilities/macrecovery/macrecovery.py ]]; then
  MACRECOVERY="/root/OpenCorePkg/Utilities/macrecovery/macrecovery.py"
elif [[ -x /root/OSX-PROXMOX/tools/macrecovery/macrecovery.py ]]; then
  MACRECOVERY="/root/OSX-PROXMOX/tools/macrecovery/macrecovery.py"
else
  echo "ERROR: macrecovery.py not found in expected locations." >&2
  exit 1
fi

mkdir -p "$OUTDIR"

# macrecovery can fail in non-interactive sessions without a pseudo-tty.
if command -v script >/dev/null 2>&1; then
  script -q -c "python3 '$MACRECOVERY' -b '$BOARD_ID' -m '$MLB' -os latest -o '$OUTDIR' download" /dev/null
else
  python3 "$MACRECOVERY" -b "$BOARD_ID" -m "$MLB" -os latest -o "$OUTDIR" download
fi

rm -f "$IMG"
fallocate -x -l 1450M "$IMG"
mkfs.msdos -F 32 "$IMG" >/dev/null

mkdir -p "$MNT"
LOOPDEV=$(losetup -f --show "$IMG")
cleanup() {
  set +e
  mountpoint -q "$MNT" && umount "$MNT"
  [[ -n "${LOOPDEV:-}" ]] && losetup -d "$LOOPDEV" 2>/dev/null
  rmdir "$MNT" 2>/dev/null || true
}
trap cleanup EXIT

mount "$LOOPDEV" "$MNT"
mkdir -p "$MNT/com.apple.recovery.boot"
cp "$OUTDIR/BaseSystem.dmg" "$MNT/com.apple.recovery.boot/"
cp "$OUTDIR/BaseSystem.chunklist" "$MNT/com.apple.recovery.boot/"
sync
umount "$MNT"
losetup -d "$LOOPDEV"
LOOPDEV=""
rmdir "$MNT" || true
trap - EXIT

echo "OK: created $IMG"
echo "Board-id used: $BOARD_ID"
