# Troubleshooting (Tahoe)

## Installer shows Sequoia instead of Tahoe

Cause:
- Wrong recovery source/board-id was used.

Fix:
1. Rebuild recovery image with Tahoe board-id:
   - `Mac-CFF7D910A743CAAF`
   - with `-os latest`
2. Re-import the new recovery disk to VM (`ide2`).
3. Confirm image content before import:

```bash
7z l /root/com.apple.recovery.tahoe/BaseSystem.dmg | grep 'Install macOS'
```

Expected:
- `Install macOS Tahoe.app`

## Apple logo freeze / no progress bar

Fix checklist:
1. Machine type is `pc-q35-8.1`.
2. OpenCore is attached as `ide0`.
3. Recovery disk is attached as `ide2`.
4. Boot order is `ide0;ide2;sata0`.
5. VM uses tested CPU args with `+invtsc`.
6. Run `Reset NVRAM` once from OpenCore.

## VM starts, then stalls with high CPU

Try the fallback CPU model:

```bash
qm stop <VMID>
qm set <VMID> --args '-device isa-applesmc,osk="ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc" -smbios type=2 -global ICH9-LPC.acpi-pci-hotplug-with-bridge-support=off -cpu Cascadelake-Server,vendor=GenuineIntel,+invtsc,-pcid,-hle,-rtm,-avx512f,-avx512dq,-avx512cd,-avx512bw,-avx512vl,-avx512vnni,kvm=on,vmware-cpuid-freq=on'
qm start <VMID>
```

## "No volume large enough" in installer

Cause:
- System disk is present but not initialized as APFS/GUID.

Fix:
1. Back to recovery menu.
2. Open Disk Utility.
3. `View -> Show All Devices`.
4. Select `QEMU HARDDISK Media`.
5. Erase with:
   - Name: `Macintosh HD`
   - Format: `APFS`
   - Scheme: `GUID Partition Map`
6. Retry install.

## QEMU error: `kvm: -v: invalid option`

Cause:
- `-v` was incorrectly added to QEMU args.

Fix:
- Remove `-v` from `qm set --args`.
- If needed, set verbose mode in OpenCore boot-args, not QEMU.

## German keyboard in noVNC

Preferred:
- Change input source in macOS UI (top-right) to German.

Optional Proxmox side setting:

```bash
qm set <VMID> --keyboard de
```
