#!/bin/bash
#
# QUICK WIPE SCRIPT
# Non-interactive disk wipe for automation/scripting
#
# Usage: sudo ./quick-wipe.sh <device> [method]
#
# Methods:
#   zero    - Single pass zero fill (default)
#   random  - Single pass random fill
#   dod     - DoD 5220.22-M 3-pass
#   dod7    - DoD 5220.22-M ECE 7-pass
#   shred   - Use shred with 3 passes
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_color() {
    echo -e "${1}${2}${NC}"
}

usage() {
    echo "Usage: $0 <device> [method]"
    echo ""
    echo "Arguments:"
    echo "  device  - Block device to wipe (e.g., /dev/sda)"
    echo "  method  - Wipe method (default: zero)"
    echo ""
    echo "Methods:"
    echo "  zero    - Single pass zero fill (fastest)"
    echo "  random  - Single pass random fill"
    echo "  dod     - DoD 5220.22-M 3-pass"
    echo "  dod7    - DoD 5220.22-M ECE 7-pass"
    echo "  shred   - Use shred with 3 passes"
    echo ""
    echo "Examples:"
    echo "  $0 /dev/sda             # Zero fill /dev/sda"
    echo "  $0 /dev/sdb dod         # DoD 3-pass wipe /dev/sdb"
    echo "  $0 /dev/nvme0n1 random  # Random fill NVMe drive"
    echo ""
    echo "Options:"
    echo "  --force, -f    Skip confirmation prompts"
    echo "  --help, -h     Show this help"
    exit 1
}

# Check for root
if [[ $EUID -ne 0 ]]; then
    print_color "$RED" "ERROR: This script must be run as root"
    exit 1
fi

# Parse arguments
FORCE=false
DEVICE=""
METHOD="zero"

while [[ $# -gt 0 ]]; do
    case $1 in
        --force|-f)
            FORCE=true
            shift
            ;;
        --help|-h)
            usage
            ;;
        /dev/*)
            DEVICE="$1"
            shift
            ;;
        zero|random|dod|dod7|shred)
            METHOD="$1"
            shift
            ;;
        *)
            print_color "$RED" "Unknown argument: $1"
            usage
            ;;
    esac
done

if [[ -z "$DEVICE" ]]; then
    print_color "$RED" "ERROR: No device specified"
    usage
fi

# Verify device exists
if [[ ! -b "$DEVICE" ]]; then
    print_color "$RED" "ERROR: Device not found: $DEVICE"
    exit 1
fi

# Check if boot device
if mount | grep -q "^$DEVICE.* on / "; then
    print_color "$RED" "ERROR: Cannot wipe the boot device!"
    exit 1
fi

# Get device info
DEVICE_SIZE=$(lsblk -d -n -o SIZE "$DEVICE" 2>/dev/null | tr -d ' ')
DEVICE_MODEL=$(lsblk -d -n -o MODEL "$DEVICE" 2>/dev/null | sed 's/^ *//;s/ *$//')

print_color "$CYAN" "╔════════════════════════════════════════════════════════════════╗"
print_color "$CYAN" "║                    QUICK DISK WIPE                             ║"
print_color "$CYAN" "╚════════════════════════════════════════════════════════════════╝"
echo ""
print_color "$WHITE" "Device: $DEVICE"
print_color "$WHITE" "Size: $DEVICE_SIZE"
print_color "$WHITE" "Model: $DEVICE_MODEL"
print_color "$WHITE" "Method: $METHOD"
echo ""

# Confirmation
if [[ "$FORCE" != "true" ]]; then
    print_color "$RED" "WARNING: This will PERMANENTLY DESTROY all data on $DEVICE!"
    print_color "$YELLOW" "Type 'YES' to confirm: "
    read -r confirm
    if [[ "$confirm" != "YES" ]]; then
        print_color "$GREEN" "Cancelled."
        exit 0
    fi
fi

# Unmount all partitions
print_color "$BLUE" "Unmounting partitions..."
for part in "$DEVICE"*; do
    umount "$part" 2>/dev/null || true
done

# Record start time
START_TIME=$(date +%s)
START_DATE=$(date)

print_color "$BLUE" "Starting wipe at $START_DATE"
echo ""

# Perform wipe based on method
case $METHOD in
    zero)
        print_color "$BLUE" "Writing zeros to $DEVICE..."
        dd if=/dev/zero of="$DEVICE" bs=4M status=progress conv=fsync 2>&1 || true
        ;;
    random)
        print_color "$BLUE" "Writing random data to $DEVICE..."
        dd if=/dev/urandom of="$DEVICE" bs=4M status=progress conv=fsync 2>&1 || true
        ;;
    dod)
        print_color "$BLUE" "Performing DoD 5220.22-M 3-pass wipe..."

        print_color "$CYAN" "Pass 1/3: Writing zeros..."
        dd if=/dev/zero of="$DEVICE" bs=4M status=progress conv=fsync 2>&1 || true

        print_color "$CYAN" "Pass 2/3: Writing 0xFF..."
        tr '\0' '\377' < /dev/zero | dd of="$DEVICE" bs=4M status=progress conv=fsync 2>&1 || true

        print_color "$CYAN" "Pass 3/3: Writing random..."
        dd if=/dev/urandom of="$DEVICE" bs=4M status=progress conv=fsync 2>&1 || true
        ;;
    dod7)
        print_color "$BLUE" "Performing DoD 5220.22-M ECE 7-pass wipe..."

        for pass in 1 2 3 4 5 6 7; do
            case $pass in
                1|4|7)
                    print_color "$CYAN" "Pass $pass/7: Writing random..."
                    dd if=/dev/urandom of="$DEVICE" bs=4M status=progress conv=fsync 2>&1 || true
                    ;;
                2|5)
                    print_color "$CYAN" "Pass $pass/7: Writing zeros..."
                    dd if=/dev/zero of="$DEVICE" bs=4M status=progress conv=fsync 2>&1 || true
                    ;;
                3|6)
                    print_color "$CYAN" "Pass $pass/7: Writing 0xFF..."
                    tr '\0' '\377' < /dev/zero | dd of="$DEVICE" bs=4M status=progress conv=fsync 2>&1 || true
                    ;;
            esac
        done
        ;;
    shred)
        if ! command -v shred &> /dev/null; then
            print_color "$RED" "ERROR: shred not available"
            exit 1
        fi
        print_color "$BLUE" "Using shred with 3 passes..."
        shred -v -n 3 "$DEVICE"
        ;;
esac

sync

# Calculate duration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
print_color "$GREEN" "╔════════════════════════════════════════════════════════════════╗"
print_color "$GREEN" "║                    WIPE COMPLETE                               ║"
print_color "$GREEN" "╚════════════════════════════════════════════════════════════════╝"
echo ""
print_color "$WHITE" "Device: $DEVICE"
print_color "$WHITE" "Method: $METHOD"
print_color "$WHITE" "Duration: $((DURATION / 3600))h $((DURATION % 3600 / 60))m $((DURATION % 60))s"
print_color "$WHITE" "Completed: $(date)"
echo ""

# Generate simple certificate/log
LOG_FILE="/tmp/wipe-log-$(date +%Y%m%d-%H%M%S).txt"
cat > "$LOG_FILE" << EOF
DISK WIPE CERTIFICATE
======================

Device: $DEVICE
Model: $DEVICE_MODEL
Size: $DEVICE_SIZE
Method: $METHOD

Started: $START_DATE
Completed: $(date)
Duration: $((DURATION / 3600))h $((DURATION % 3600 / 60))m $((DURATION % 60))s

Status: COMPLETED

---
Generated by Disk Wipe Utility
EOF

print_color "$WHITE" "Wipe log saved to: $LOG_FILE"
