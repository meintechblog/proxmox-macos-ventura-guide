# macOS Ventura on Proxmox 9 (Intel) - Practical Installation Routine

## Base reference
https://www.xda-developers.com/i-installed-macos-on-proxmox-and-it-works-well/

## Requirements

- Intel CPU with VT-x enabled
- Proxmox 9
- `local-lvm` storage available
- At least 8 GB RAM (16 GB recommended)
- Existing bridge (example used here: `vmbr0`)

------------------------------------------------------------------------

## 0) Host safety (important)

This routine changes only VM `900`.

- No edits to `/etc/default/grub`
- No kernel/module changes
- No BIOS changes

------------------------------------------------------------------------

## 1) Check TSC (important since Monterey)

```bash
dmesg | grep -i -e tsc -e clocksource
cat /sys/devices/system/clocksource/clocksource0/current_clocksource
```

Expected:

    clocksource: Switched to clocksource tsc
    tsc

------------------------------------------------------------------------

## 2) Rebuild VM 900 (baseline)

If VM `900` already exists:

```bash
qm stop 900 || true
qm destroy 900 --purge 1 --destroy-unreferenced-disks 1
```

Create fresh VM:

```bash
qm create 900 \
  --name macos-hulki \
  --machine pc-q35-8.1 \
  --bios ovmf \
  --cores 4 \
  --sockets 1 \
  --memory 16384 \
  --balloon 0 \
  --ostype other \
  --scsihw virtio-scsi-pci \
  --net0 vmxnet3,bridge=vmbr0 \
  --vga vmware \
  --agent 1 \
  --tablet 1 \
  --onboot 0

qm set 900 --efidisk0 local-lvm:1,efitype=4m,pre-enrolled-keys=0
qm set 900 --sata0 local-lvm:100,cache=none,discard=on,ssd=1
```

------------------------------------------------------------------------

## 3) Generate OpenCore

```bash
/bin/bash -c "$(curl -fsSL https://install.osx-proxmox.com)"
```

Prompts:
- Generate serial -> `y`
- SystemProductName -> `iMacPro1,1`
- Apply changes -> `y`
- Reboot -> Enter

------------------------------------------------------------------------

## 4) Convert/import OpenCore ISO as RAW

```bash
cd /var/lib/vz/template/iso
qemu-img convert -f raw -O raw opencore-osx-proxmox-vm.iso opencore.raw
qm importdisk 900 opencore.raw local-lvm
```

Attach OpenCore on `ide0` (not as CD-ROM):

```bash
qm config 900 | grep '^unused'
# Example: unused0: local-lvm:vm-900-disk-2
qm set 900 --ide0 local-lvm:vm-900-disk-2
```

------------------------------------------------------------------------

## 5) Download Ventura recovery correctly (critical)

Use Ventura board-id:

`Mac-B4831CEBD52A0C4C`

```bash
python3 /root/OSX-PROXMOX/tools/macrecovery/macrecovery.py \
  -b Mac-B4831CEBD52A0C4C \
  -m 00000000000000000 \
  -o /root/com.apple.recovery.ventura \
  download
```

Build a FAT recovery image containing `com.apple.recovery.boot`:

```bash
fallocate -x -l 1024M /var/lib/vz/template/iso/recovery-ventura-fat.img
mkfs.msdos -F 32 /var/lib/vz/template/iso/recovery-ventura-fat.img
mkdir -p /mnt/recovery-ventura
LOOPDEV=$(losetup -f --show /var/lib/vz/template/iso/recovery-ventura-fat.img)
mount "$LOOPDEV" /mnt/recovery-ventura
mkdir -p /mnt/recovery-ventura/com.apple.recovery.boot
cp /root/com.apple.recovery.ventura/BaseSystem.dmg /mnt/recovery-ventura/com.apple.recovery.boot/
cp /root/com.apple.recovery.ventura/BaseSystem.chunklist /mnt/recovery-ventura/com.apple.recovery.boot/
sync
umount /mnt/recovery-ventura
losetup -d "$LOOPDEV"
rmdir /mnt/recovery-ventura
```

Import and attach as `ide2`:

```bash
qm importdisk 900 /var/lib/vz/template/iso/recovery-ventura-fat.img local-lvm
qm config 900 | grep '^unused'
# Example: unused2: local-lvm:vm-900-disk-6
qm set 900 --ide2 local-lvm:vm-900-disk-6
```

------------------------------------------------------------------------

## 6) Apply stability args (Apple-logo freeze fix)

```bash
qm set 900 --args '-device isa-applesmc,osk="ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc" -smbios type=2 -device usb-kbd,bus=ehci.0,port=2 -device usb-mouse,bus=ehci.0,port=3 -global ICH9-LPC.acpi-pci-hotplug-with-bridge-support=off -cpu Cascadelake-Server,vendor=GenuineIntel,+invtsc,-pcid,-hle,-rtm,-avx512f,-avx512dq,-avx512cd,-avx512bw,-avx512vl,-avx512vnni,kvm=on,vmware-cpuid-freq=on'
qm set 900 --boot "order=ide0;ide2;sata0"
```

Important:
- Do not put `-v` in `qm set --args`
- Verbose belongs to OpenCore boot args, not QEMU args

Optional (only if noVNC/OpenCore keeps US keyboard layout):

```bash
qm set 900 --keyboard de
```

Note: often not required. In many setups selecting German keyboard in macOS UI (top-right) is enough.

------------------------------------------------------------------------

## 7) Start + install

```bash
qm start 900
```

In OpenCore:
- Run `Reset NVRAM` once
- Then select `Install macOS Ventura`

If installer says no volume is large enough:
1. Click `Back`
2. Open `Disk Utility`
3. `View` -> `Show All Devices`
4. Select `QEMU HARDDISK Media` (~107 GB)
5. Click `Erase` with:
   - Name: `Macintosh HD`
   - Format: `APFS`
   - Scheme: `GUID Partition Map`
6. Close Disk Utility and start Ventura install again

------------------------------------------------------------------------

## Post-install cleanup

Remove recovery from boot order:

```bash
qm set 900 --boot "order=ide0;sata0"
```

Optional: remove recovery disk:

```bash
qm set 900 --delete ide2
```

Optional: create snapshot:

```bash
qm snapshot 900 clean-install
```

------------------------------------------------------------------------

## Common issues and causes

| Problem | Cause | Fix |
| --- | --- | --- |
| UEFI shell | OpenCore attached incorrectly | Import OpenCore as RAW and attach on `ide0` |
| Apple logo freeze | Unstable CPU/machine combination | Use `pc-q35-8.1` + Cascadelake args above |
| Recovery boots but later stalls | Wrong board-id used for recovery download | Re-download Ventura recovery with `Mac-B4831CEBD52A0C4C` |
| `kvm: -v: invalid option` | `-v` was set in QEMU args | Set `qm set 900 --args ...` without `-v` |
| No install volume large enough | 100 GB target disk not initialized | Disk Utility -> Show All Devices -> erase 107 GB disk as APFS/GUID |
| Keyboard behaves as US | noVNC/OpenCore/macOS layouts not aligned | Set layout in macOS UI first; optionally `qm set 900 --keyboard de` |

------------------------------------------------------------------------

## Short recommendation

- Prefer Ventura over Sonoma/Sequoia for stability
- Always snapshot before macOS updates
- Keep host untouched while VM config is stable
