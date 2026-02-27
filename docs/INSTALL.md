# macOS Tahoe on Proxmox 9 (Intel)

This is the only supported install path in this project.

## Requirements

- Proxmox VE 9 on Intel (VT-x enabled)
- Storage with enough free space for:
  - EFI disk (4 MB)
  - System disk (recommended 100 GB+)
  - OpenCore raw disk (~96 MB)
  - Recovery disk (~1.5 GB)
- 16 GB RAM recommended

## 0) Optional preflight checks

```bash
qm list
cat /sys/devices/system/clocksource/clocksource0/current_clocksource
pvesm status
```

Expected: `tsc` clocksource and enough free space on your target storage.

## 1) Create a clean VM baseline

Set your VMID once (example uses `900`):

```bash
VMID=900
STORAGE=local-lvm
BRIDGE=vmbr0
```

Create VM:

```bash
qm stop "$VMID" || true
qm destroy "$VMID" --purge 1 --destroy-unreferenced-disks 1 || true

qm create "$VMID" \
  --name macos-tahoe \
  --machine pc-q35-8.1 \
  --bios ovmf \
  --cores 4 \
  --sockets 1 \
  --memory 16384 \
  --balloon 0 \
  --ostype other \
  --scsihw virtio-scsi-pci \
  --net0 vmxnet3,bridge="$BRIDGE" \
  --vga vmware \
  --agent 1 \
  --tablet 1 \
  --onboot 0

qm set "$VMID" --efidisk0 "$STORAGE":1,efitype=4m,pre-enrolled-keys=0
qm set "$VMID" --sata0 "$STORAGE":100,cache=none,discard=on,ssd=1
```

## 2) Prepare OpenCore disk (raw)

```bash
/bin/bash -c "$(curl -fsSL https://install.osx-proxmox.com)"

cd /var/lib/vz/template/iso
qemu-img convert -f raw -O raw opencore-osx-proxmox-vm.iso opencore.raw
qm importdisk "$VMID" opencore.raw "$STORAGE"
```

Attach imported OpenCore disk to `ide0`:

```bash
qm config "$VMID" | grep '^unused'
# Example output: unused0: local-lvm:vm-900-disk-2
qm set "$VMID" --ide0 local-lvm:vm-"$VMID"-disk-2
```

## 3) Build Tahoe recovery image

Use the Tahoe script (verified board-id `Mac-CFF7D910A743CAAF`):

```bash
cd /root/proxmox-macos-install-guide
scripts/make_tahoe_recovery_fat.sh \
  /root/com.apple.recovery.tahoe \
  /var/lib/vz/template/iso/recovery-tahoe-fat.img
```

Import and attach to `ide2`:

```bash
qm importdisk "$VMID" /var/lib/vz/template/iso/recovery-tahoe-fat.img "$STORAGE"
qm config "$VMID" | grep '^unused'
# Example output: unused1: local-lvm:vm-900-disk-3
qm set "$VMID" --ide2 local-lvm:vm-"$VMID"-disk-3
```

## 4) Set stable CPU/QEMU args and boot order

```bash
qm set "$VMID" --args '-device isa-applesmc,osk="ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc" -smbios type=2 -device usb-kbd,bus=ehci.0,port=2 -device usb-mouse,bus=ehci.0,port=3 -global ICH9-LPC.acpi-pci-hotplug-with-bridge-support=off -cpu Cascadelake-Server,vendor=GenuineIntel,+invtsc,-pcid,-hle,-rtm,-avx512f,-avx512dq,-avx512cd,-avx512bw,-avx512vl,-avx512vnni,kvm=on,vmware-cpuid-freq=on'
qm set "$VMID" --boot "order=ide0;ide2;sata0"
qm start "$VMID"
```

Important:
- Do not put `-v` into `qm set --args`.
- Verbose belongs to OpenCore boot-args, not QEMU args.

## 5) Install Tahoe in recovery UI

In OpenCore:
1. Run `Reset NVRAM` once.
2. Choose `Install macOS Tahoe`.

If installer says no disk is large enough:
1. Back to recovery main menu.
2. Open Disk Utility.
3. `View -> Show All Devices`.
4. Select `QEMU HARDDISK Media` (~107 GB).
5. Erase with:
   - Name: `Macintosh HD`
   - Format: `APFS`
   - Scheme: `GUID Partition Map`
6. Retry install.

## 6) Post-install cleanup

After first successful boot:

```bash
qm set "$VMID" --boot "order=ide0;sata0"
# optional:
qm set "$VMID" --delete ide2
qm snapshot "$VMID" clean-install
```

## 7) Verify you really got Tahoe

Inside installer/recovery UI, it should show `Install macOS Tahoe`.

If it shows another release (for example Sequoia), use the troubleshooting doc:
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
