# Disk Wipe Utility

A comprehensive toolkit for securely erasing data from hard drives and SSDs. This is a modern replacement for DBAN (Darik's Boot and Nuke) that can be run from a USB stick.

## Quick Start

### Option 1: Use with a Linux Live USB (Recommended)

1. Boot your computer from a Linux Live USB (Ubuntu, SystemRescue, etc.)
2. Mount this USB stick containing these scripts
3. Open a terminal and navigate to the disk-wipe directory
4. Run the setup script first:
   ```bash
   sudo ./setup-nwipe.sh
   ```
5. Then run the main wipe utility:
   ```bash
   sudo ./wipe-disk.sh
   ```

### Option 2: Create a Dedicated Bootable USB

```bash
sudo ./create-bootable-usb.sh
```

This will download a Linux distribution (SystemRescue or ShredOS) and create a bootable USB with all the disk wipe tools included.

### Option 3: Use ShredOS (Simplest)

[ShredOS](https://github.com/PartialVolume/shredos.x86_64) boots directly into nwipe. Just:
1. Download ShredOS from GitHub
2. Write it to a USB with `dd` or Balena Etcher
3. Boot from it - it automatically starts nwipe

## Scripts Included

| Script | Description |
|--------|-------------|
| `wipe-disk.sh` | Interactive menu-driven disk wipe utility |
| `quick-wipe.sh` | Command-line quick wipe for automation |
| `setup-nwipe.sh` | Installs nwipe and required tools |
| `create-bootable-usb.sh` | Creates a bootable USB with wipe tools |

## Wipe Methods

| Method | Passes | Description | Use Case |
|--------|--------|-------------|----------|
| Zero Fill | 1 | Writes zeros to entire disk | SSDs, quick erase |
| Random Fill | 1 | Writes random data | General use |
| DoD 5220.22-M | 3 | US DoD standard (zeros, ones, random) | Government/corporate |
| DoD 5220.22-M ECE | 7 | Extended DoD standard | High security |
| Gutmann | 35 | Maximum security patterns | Paranoid level |
| ATA Secure Erase | 1 | Uses drive's built-in erase | SSDs (recommended) |

### Choosing a Method

- **SSDs**: Use Zero Fill or ATA Secure Erase. Multiple passes don't improve security on SSDs due to wear leveling.
- **HDDs**: DoD 3-pass is sufficient for most purposes. Gutmann 35-pass is overkill for modern drives.
- **Quick disposal**: Zero Fill is fast and effective.
- **Compliance**: DoD 5220.22-M meets most regulatory requirements.

## Usage Examples

### Interactive Mode
```bash
sudo ./wipe-disk.sh
```

### Quick Wipe (Command Line)
```bash
# Zero fill a disk
sudo ./quick-wipe.sh /dev/sda

# DoD 3-pass wipe
sudo ./quick-wipe.sh /dev/sdb dod

# Random fill with no confirmation prompt
sudo ./quick-wipe.sh /dev/sdc random --force
```

### Using nwipe Directly
```bash
# Interactive mode (recommended)
sudo nwipe

# Automated wipe with specific method
sudo nwipe --autonuke --method=dodshort /dev/sda
```

## Safety Features

- **Boot device protection**: Scripts refuse to wipe the device you booted from
- **Multiple confirmations**: Requires typing "YES" and the device name
- **Device listing**: Shows all available devices with sizes and models
- **Unmount protection**: Automatically unmounts partitions before wiping

## Creating a Bootable USB

### Recommended: ShredOS

ShredOS is purpose-built for disk wiping and boots directly into nwipe:

1. Download from: https://github.com/PartialVolume/shredos.x86_64/releases
2. Write to USB:
   ```bash
   # Linux
   sudo dd if=shredos.img of=/dev/sdX bs=4M status=progress

   # Or use Balena Etcher (Windows/Mac/Linux)
   ```
3. Boot from USB
4. Use arrow keys to select disks, Space to toggle, F10 to start

### Alternative: SystemRescue

SystemRescue includes nwipe and many other rescue tools:

1. Download from: https://www.system-rescue.org/
2. Write ISO to USB with dd or Rufus
3. Boot and run `nwipe` from terminal

## Directory Structure

```
disk-wipe/
├── README.md              # This file
├── wipe-disk.sh           # Interactive wipe utility
├── quick-wipe.sh          # Command-line wipe
├── setup-nwipe.sh         # Tool installation script
├── create-bootable-usb.sh # Bootable USB creator
├── bin/                   # Helper binaries/scripts
└── lib/                   # Library functions
    └── disk-utils.sh      # Disk utility functions
```

## Requirements

- Linux environment (live USB or installed)
- Root/sudo access
- At least one of: `dd`, `nwipe`, `shred`

### Recommended Tools
- `nwipe` - Full-featured disk wipe (DBAN's dwipe fork)
- `hdparm` - For ATA Secure Erase
- `shred` - GNU coreutils shred

## Verification

After wiping, you can verify the disk is clean:

```bash
# Read first few sectors (should be all zeros for zero fill)
sudo hexdump -C /dev/sdX | head -20

# Check random sectors
sudo dd if=/dev/sdX bs=512 skip=1000 count=1 | hexdump -C
```

## Troubleshooting

### "Device is frozen" (ATA Secure Erase)
Some drives enter a "frozen" state. To unfreeze:
1. Suspend and resume the system, OR
2. Hot-plug the drive (if SATA)

### "Permission denied"
Run with `sudo`:
```bash
sudo ./wipe-disk.sh
```

### nwipe not found
Run the setup script:
```bash
sudo ./setup-nwipe.sh
```

### Slow wipe speed
- HDDs: ~100MB/s is normal
- SSDs: ~300-500MB/s is normal
- USB 2.0: ~30MB/s maximum

## Security Notes

- **SSDs and Flash**: Wear leveling means some data may remain in spare cells. Use ATA Secure Erase for best results.
- **Encrypted drives**: If drive was encrypted, wiping the header (first 10MB) is usually sufficient.
- **Physical destruction**: For highest security requirements, physical destruction (shredding) is the only guarantee.

## Compliance

These wipe methods meet various standards:
- **NIST 800-88**: Clear/Purge methods
- **DoD 5220.22-M**: 3 and 7 pass methods
- **GDPR Article 17**: Right to erasure

## License

This toolkit is provided as-is for data destruction purposes. Use at your own risk.

## Credits

- [nwipe](https://github.com/martijnvanbrummelen/nwipe) - The disk wipe engine
- [ShredOS](https://github.com/PartialVolume/shredos.x86_64) - Bootable nwipe distribution
- [SystemRescue](https://www.system-rescue.org/) - Linux rescue distribution
