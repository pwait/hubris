#!/bin/bash
#
# CREATE BOOTABLE USB SCRIPT
# Downloads a minimal Linux ISO and creates a bootable USB with disk wipe tools
#
# This script will:
# 1. Download a minimal Linux distribution (SystemRescue or similar)
# 2. Write it to a USB drive
# 3. Copy the disk wipe scripts to the USB
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_color() {
    echo -e "${1}${2}${NC}"
}

print_header() {
    clear
    print_color "$CYAN" "╔════════════════════════════════════════════════════════════════╗"
    print_color "$CYAN" "║          CREATE BOOTABLE DISK WIPE USB                         ║"
    print_color "$CYAN" "╚════════════════════════════════════════════════════════════════╝"
    echo ""
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_color "$RED" "ERROR: This script must be run as root (sudo)"
        exit 1
    fi
}

check_dependencies() {
    local missing=()

    for cmd in wget dd lsblk; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        print_color "$RED" "Missing required tools: ${missing[*]}"
        exit 1
    fi
}

# Recommended distributions for disk wiping
show_distro_options() {
    print_color "$WHITE" "Recommended Linux distributions for disk wiping:"
    echo ""
    print_color "$GREEN" "  [1] SystemRescue (Recommended)"
    echo "      - Designed for system rescue and disk operations"
    echo "      - Includes nwipe, shred, hdparm, and more"
    echo "      - Size: ~700MB"
    echo ""
    print_color "$GREEN" "  [2] ShredOS"
    echo "      - Purpose-built for disk wiping"
    echo "      - Boots directly into nwipe"
    echo "      - Size: ~25MB"
    echo ""
    print_color "$GREEN" "  [3] Tiny Core Linux + Tools"
    echo "      - Minimal Linux distribution"
    echo "      - Very small, very fast boot"
    echo "      - Size: ~20MB (core) + tools"
    echo ""
    print_color "$GREEN" "  [4] Ubuntu Live (Full featured)"
    echo "      - Full desktop environment"
    echo "      - Good for manual disk operations"
    echo "      - Size: ~4GB"
    echo ""
    print_color "$GREEN" "  [5] Use existing ISO file"
    echo "      - Provide path to your own ISO"
    echo ""
}

download_systemrescue() {
    local download_dir=${1:-/tmp}
    local version="11.01"
    local url="https://sourceforge.net/projects/systemrescuecd/files/sysresccd-x86/${version}/systemrescue-${version}-amd64.iso/download"
    local output="$download_dir/systemrescue-${version}-amd64.iso"

    print_color "$BLUE" "Downloading SystemRescue ${version}..."
    wget -O "$output" "$url" --show-progress

    echo "$output"
}

download_shredos() {
    local download_dir=${1:-/tmp}

    print_color "$BLUE" "Downloading ShredOS..."

    # Get latest release URL from GitHub
    local latest_url
    latest_url=$(wget -qO- "https://api.github.com/repos/PartialVolume/shredos.x86_64/releases/latest" | \
        grep "browser_download_url.*img.xz" | head -1 | cut -d '"' -f 4)

    if [[ -z "$latest_url" ]]; then
        print_color "$RED" "Could not find ShredOS download URL"
        return 1
    fi

    local filename
    filename=$(basename "$latest_url")
    local output="$download_dir/$filename"

    wget -O "$output" "$latest_url" --show-progress

    # Extract if xz compressed
    if [[ "$output" == *.xz ]]; then
        print_color "$BLUE" "Extracting..."
        xz -d "$output"
        output="${output%.xz}"
    fi

    echo "$output"
}

list_usb_devices() {
    print_color "$WHITE" "Available USB devices:"
    echo ""

    local devices=()
    local i=1

    while IFS= read -r line; do
        local name size model rm
        name=$(echo "$line" | awk '{print $1}')
        size=$(echo "$line" | awk '{print $2}')
        rm=$(echo "$line" | awk '{print $3}')
        model=$(echo "$line" | awk '{$1=$2=$3=""; print $0}' | sed 's/^ *//')

        # Only show removable devices
        if [[ "$rm" == "1" ]]; then
            devices+=("/dev/$name")
            printf "  ${GREEN}[%d]${NC} /dev/%s (%s) - %s\n" "$i" "$name" "$size" "$model"
            ((i++))
        fi
    done < <(lsblk -d -o NAME,SIZE,RM,MODEL -n | grep -v "^loop" | grep -v "^sr")

    echo ""

    if [[ ${#devices[@]} -eq 0 ]]; then
        print_color "$RED" "No USB devices found!"
        return 1
    fi

    USB_DEVICES=("${devices[@]}")
}

write_iso_to_usb() {
    local iso_path=$1
    local usb_device=$2

    print_color "$RED" "╔════════════════════════════════════════════════════════════════╗"
    print_color "$RED" "║                       WARNING                                  ║"
    print_color "$RED" "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    print_color "$RED" "This will ERASE ALL DATA on $usb_device"
    echo ""

    lsblk "$usb_device" -o NAME,SIZE,TYPE,MOUNTPOINT 2>/dev/null || true
    echo ""

    print_color "$YELLOW" "Type 'YES' to confirm: "
    read -r confirm
    if [[ "$confirm" != "YES" ]]; then
        print_color "$GREEN" "Cancelled."
        return 1
    fi

    # Unmount any mounted partitions
    print_color "$BLUE" "Unmounting any mounted partitions..."
    for part in "$usb_device"*; do
        umount "$part" 2>/dev/null || true
    done

    # Determine if it's an ISO or IMG file
    local file_type
    file_type=$(file "$iso_path" | cut -d: -f2)

    print_color "$BLUE" "Writing image to USB..."
    print_color "$YELLOW" "This may take several minutes..."

    dd if="$iso_path" of="$usb_device" bs=4M status=progress conv=fsync

    sync

    print_color "$GREEN" "Image written successfully!"
}

add_persistence_partition() {
    local usb_device=$1

    print_color "$BLUE" "Adding persistence partition for storing scripts..."

    # Get the last sector used by the ISO
    local iso_end
    iso_end=$(parted -s "$usb_device" unit s print | grep "^ 1" | awk '{print $3}' | tr -d 's')

    if [[ -z "$iso_end" ]]; then
        print_color "$YELLOW" "Could not determine ISO partition size. Skipping persistence partition."
        return 1
    fi

    # Create a new partition starting after the ISO
    local start=$((iso_end + 1))

    parted -s "$usb_device" mkpart primary ext4 "${start}s" 100%
    sleep 2

    # Format the new partition
    local part_num=2
    local partition="${usb_device}${part_num}"

    if [[ ! -b "$partition" ]]; then
        partition="${usb_device}p${part_num}"
    fi

    if [[ -b "$partition" ]]; then
        mkfs.ext4 -L "WIPE_TOOLS" "$partition"
        print_color "$GREEN" "Persistence partition created: $partition"

        # Mount and copy scripts
        local mount_point="/tmp/wipe_tools_mount_$$"
        mkdir -p "$mount_point"
        mount "$partition" "$mount_point"

        cp -r "$SCRIPT_DIR"/* "$mount_point/"
        chmod +x "$mount_point"/*.sh

        umount "$mount_point"
        rmdir "$mount_point"

        print_color "$GREEN" "Disk wipe scripts copied to USB."
    else
        print_color "$YELLOW" "Could not find partition to format."
    fi
}

create_simple_data_partition() {
    local usb_device=$1

    print_color "$BLUE" "Creating data partition for scripts..."

    # Just copy scripts to a FAT32 partition that we create
    # This is simpler and more compatible

    local part="${usb_device}1"
    if [[ ! -b "$part" ]]; then
        part="${usb_device}p1"
    fi

    if mount | grep -q "$part"; then
        local mount_point
        mount_point=$(mount | grep "$part" | awk '{print $3}')

        mkdir -p "$mount_point/disk-wipe"
        cp -r "$SCRIPT_DIR"/* "$mount_point/disk-wipe/"
        chmod +x "$mount_point/disk-wipe"/*.sh 2>/dev/null || true

        print_color "$GREEN" "Scripts copied to $mount_point/disk-wipe/"
    fi
}

main() {
    print_header
    check_root
    check_dependencies

    echo ""
    show_distro_options

    print_color "$WHITE" "Select distribution (or 'q' to quit): "
    read -r distro_choice

    if [[ "$distro_choice" == "q" ]]; then
        exit 0
    fi

    local iso_path=""

    case $distro_choice in
        1)
            iso_path=$(download_systemrescue)
            ;;
        2)
            iso_path=$(download_shredos)
            ;;
        3)
            print_color "$YELLOW" "Tiny Core requires manual setup. Downloading base..."
            # Would need custom implementation
            print_color "$RED" "Not yet implemented. Please use SystemRescue or ShredOS."
            exit 1
            ;;
        4)
            print_color "$YELLOW" "Please download Ubuntu from https://ubuntu.com/download/desktop"
            print_color "$WHITE" "Enter path to Ubuntu ISO: "
            read -r iso_path
            ;;
        5)
            print_color "$WHITE" "Enter path to ISO/IMG file: "
            read -r iso_path
            ;;
        *)
            print_color "$RED" "Invalid selection."
            exit 1
            ;;
    esac

    if [[ ! -f "$iso_path" ]]; then
        print_color "$RED" "ISO file not found: $iso_path"
        exit 1
    fi

    print_header
    if ! list_usb_devices; then
        exit 1
    fi

    print_color "$WHITE" "Select USB device number: "
    read -r usb_choice

    if ! [[ "$usb_choice" =~ ^[0-9]+$ ]] || [[ "$usb_choice" -lt 1 ]] || [[ "$usb_choice" -gt ${#USB_DEVICES[@]} ]]; then
        print_color "$RED" "Invalid selection."
        exit 1
    fi

    local selected_usb="${USB_DEVICES[$((usb_choice-1))]}"

    if ! write_iso_to_usb "$iso_path" "$selected_usb"; then
        exit 1
    fi

    # Try to add scripts partition
    print_color "$WHITE" "Would you like to add a partition for the wipe scripts? [y/N]: "
    read -r add_scripts

    if [[ "$add_scripts" =~ ^[Yy] ]]; then
        add_persistence_partition "$selected_usb" || \
            create_simple_data_partition "$selected_usb" || \
            print_color "$YELLOW" "Could not add scripts partition. Copy them manually."
    fi

    echo ""
    print_color "$GREEN" "╔════════════════════════════════════════════════════════════════╗"
    print_color "$GREEN" "║                BOOTABLE USB CREATED                            ║"
    print_color "$GREEN" "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    print_color "$WHITE" "Your bootable USB is ready!"
    echo ""
    print_color "$WHITE" "To use:"
    echo "  1. Boot from the USB drive"
    echo "  2. Run the disk wipe scripts from /disk-wipe/ or use nwipe directly"
    echo ""
    print_color "$YELLOW" "If using ShredOS, it will boot directly into nwipe."
    print_color "$YELLOW" "If using SystemRescue, open a terminal and run 'nwipe'."
}

main "$@"
