#!/bin/bash
#
# DISK WIPE UTILITY
# A comprehensive disk wiping tool for secure data destruction
#
# WARNING: This tool will PERMANENTLY DESTROY all data on selected disks.
#          There is NO way to recover data after wiping.
#
# Usage: sudo ./wipe-disk.sh
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#######################################
# Print colored output
#######################################
print_color() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

print_header() {
    clear
    print_color "$CYAN" "╔════════════════════════════════════════════════════════════════╗"
    print_color "$CYAN" "║                     DISK WIPE UTILITY                          ║"
    print_color "$CYAN" "║            Secure Data Destruction Tool v1.0                   ║"
    print_color "$CYAN" "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    print_color "$RED" "  ⚠️  WARNING: This tool PERMANENTLY DESTROYS all data!"
    print_color "$RED" "  ⚠️  There is NO recovery possible after wiping!"
    echo ""
}

#######################################
# Check if running as root
#######################################
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_color "$RED" "ERROR: This script must be run as root (sudo)"
        exit 1
    fi
}

#######################################
# Check for required tools
#######################################
check_dependencies() {
    local missing=()

    for cmd in lsblk dd; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        print_color "$RED" "Missing required tools: ${missing[*]}"
        exit 1
    fi

    # Check for optional enhanced tools
    if command -v nwipe &> /dev/null; then
        NWIPE_AVAILABLE=true
    else
        NWIPE_AVAILABLE=false
    fi

    if command -v shred &> /dev/null; then
        SHRED_AVAILABLE=true
    else
        SHRED_AVAILABLE=false
    fi
}

#######################################
# List available disks (excluding the boot USB)
#######################################
list_disks() {
    print_color "$WHITE" "Available disks:"
    echo ""

    # Get list of block devices that are disks (not partitions)
    local disks=()
    local i=1

    while IFS= read -r line; do
        local name size model type rm
        name=$(echo "$line" | awk '{print $1}')
        size=$(echo "$line" | awk '{print $2}')
        model=$(echo "$line" | awk '{$1=$2=""; print $0}' | sed 's/^ *//')

        # Skip if this appears to be our boot device
        # Check if any partition is mounted as root or boot
        local is_boot=false
        for part in /dev/"${name}"*; do
            if mount | grep -q "^$part on / " || mount | grep -q "^$part on /boot"; then
                is_boot=true
                break
            fi
        done

        if [[ "$is_boot" == "true" ]]; then
            print_color "$YELLOW" "  [SKIP] /dev/$name ($size) - $model [BOOT DEVICE]"
        else
            disks+=("/dev/$name")
            printf "  ${GREEN}[%d]${NC} /dev/%s (%s) - %s\n" "$i" "$name" "$size" "$model"
            ((i++))
        fi
    done < <(lsblk -d -o NAME,SIZE,MODEL -n | grep -v "^loop" | grep -v "^sr" | grep -v "^ram")

    echo ""
    AVAILABLE_DISKS=("${disks[@]}")
}

#######################################
# Display wipe methods
#######################################
show_wipe_methods() {
    print_color "$WHITE" "Available wipe methods:"
    echo ""
    print_color "$GREEN" "  [1] Quick Zero Fill"
    echo "      - Single pass of zeros"
    echo "      - Fastest method, suitable for SSDs"
    echo ""
    print_color "$GREEN" "  [2] Random Fill"
    echo "      - Single pass of random data"
    echo "      - Good for most use cases"
    echo ""
    print_color "$GREEN" "  [3] DoD 5220.22-M (3-pass)"
    echo "      - Pass 1: Write zeros"
    echo "      - Pass 2: Write ones (0xFF)"
    echo "      - Pass 3: Write random data"
    echo "      - US Department of Defense standard"
    echo ""
    print_color "$GREEN" "  [4] DoD 5220.22-M ECE (7-pass)"
    echo "      - Extended DoD standard with 7 passes"
    echo "      - Higher security, takes longer"
    echo ""
    if [[ "$NWIPE_AVAILABLE" == "true" ]]; then
        print_color "$GREEN" "  [5] Gutmann (35-pass) via nwipe"
        echo "      - Maximum security, 35 different patterns"
        echo "      - Very slow, mostly for magnetic drives"
        echo ""
    fi
    print_color "$GREEN" "  [6] NIST 800-88 Secure Erase (ATA)"
    echo "      - Uses drive's built-in secure erase"
    echo "      - Best for SSDs, very fast"
    echo ""
}

#######################################
# Confirm wipe action with multiple prompts
#######################################
confirm_wipe() {
    local disk=$1
    local method=$2

    print_color "$RED" "╔════════════════════════════════════════════════════════════════╗"
    print_color "$RED" "║                    FINAL CONFIRMATION                          ║"
    print_color "$RED" "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    print_color "$WHITE" "You are about to PERMANENTLY WIPE:"
    print_color "$YELLOW" "  Disk: $disk"
    print_color "$YELLOW" "  Method: $method"
    echo ""

    # Show disk info
    print_color "$WHITE" "Disk details:"
    lsblk "$disk" -o NAME,SIZE,TYPE,MOUNTPOINT 2>/dev/null || true
    echo ""

    # First confirmation
    print_color "$RED" "Type 'YES' (uppercase) to confirm: "
    read -r confirm1
    if [[ "$confirm1" != "YES" ]]; then
        print_color "$GREEN" "Wipe cancelled."
        return 1
    fi

    # Second confirmation with disk name
    print_color "$RED" "Type the disk name (e.g., sda) to confirm: "
    read -r confirm2
    local disk_name
    disk_name=$(basename "$disk")
    if [[ "$confirm2" != "$disk_name" ]]; then
        print_color "$GREEN" "Wipe cancelled."
        return 1
    fi

    return 0
}

#######################################
# Wipe with zeros
#######################################
wipe_zeros() {
    local disk=$1
    print_color "$BLUE" "Starting zero fill on $disk..."

    # Get disk size for progress
    local size
    size=$(blockdev --getsize64 "$disk" 2>/dev/null || echo "0")

    dd if=/dev/zero of="$disk" bs=4M status=progress conv=fsync 2>&1 || true
    sync

    print_color "$GREEN" "Zero fill complete."
}

#######################################
# Wipe with random data
#######################################
wipe_random() {
    local disk=$1
    print_color "$BLUE" "Starting random fill on $disk..."

    dd if=/dev/urandom of="$disk" bs=4M status=progress conv=fsync 2>&1 || true
    sync

    print_color "$GREEN" "Random fill complete."
}

#######################################
# Wipe with pattern (0xFF)
#######################################
wipe_ones() {
    local disk=$1
    print_color "$BLUE" "Starting 0xFF fill on $disk..."

    # Create a block of 0xFF bytes
    tr '\0' '\377' < /dev/zero | dd of="$disk" bs=4M status=progress conv=fsync 2>&1 || true
    sync

    print_color "$GREEN" "0xFF fill complete."
}

#######################################
# DoD 5220.22-M 3-pass wipe
#######################################
wipe_dod_3pass() {
    local disk=$1

    print_color "$BLUE" "Starting DoD 5220.22-M 3-pass wipe on $disk..."
    echo ""

    print_color "$CYAN" "Pass 1/3: Writing zeros..."
    wipe_zeros "$disk"

    print_color "$CYAN" "Pass 2/3: Writing ones (0xFF)..."
    wipe_ones "$disk"

    print_color "$CYAN" "Pass 3/3: Writing random data..."
    wipe_random "$disk"

    print_color "$GREEN" "DoD 3-pass wipe complete."
}

#######################################
# DoD 5220.22-M ECE 7-pass wipe
#######################################
wipe_dod_7pass() {
    local disk=$1

    print_color "$BLUE" "Starting DoD 5220.22-M ECE 7-pass wipe on $disk..."
    echo ""

    for pass in 1 2 3 4 5 6 7; do
        case $pass in
            1|4|7)
                print_color "$CYAN" "Pass $pass/7: Writing random data..."
                wipe_random "$disk"
                ;;
            2|5)
                print_color "$CYAN" "Pass $pass/7: Writing zeros..."
                wipe_zeros "$disk"
                ;;
            3|6)
                print_color "$CYAN" "Pass $pass/7: Writing ones (0xFF)..."
                wipe_ones "$disk"
                ;;
        esac
    done

    print_color "$GREEN" "DoD 7-pass wipe complete."
}

#######################################
# Gutmann 35-pass wipe using nwipe
#######################################
wipe_gutmann() {
    local disk=$1

    if [[ "$NWIPE_AVAILABLE" != "true" ]]; then
        print_color "$RED" "nwipe is not available. Please install it first."
        return 1
    fi

    print_color "$BLUE" "Starting Gutmann 35-pass wipe using nwipe on $disk..."
    nwipe --autonuke --method=gutmann --nogui "$disk"

    print_color "$GREEN" "Gutmann 35-pass wipe complete."
}

#######################################
# ATA Secure Erase
#######################################
wipe_secure_erase() {
    local disk=$1

    print_color "$BLUE" "Attempting ATA Secure Erase on $disk..."

    # Check if hdparm is available
    if ! command -v hdparm &> /dev/null; then
        print_color "$RED" "hdparm is not available. Cannot perform ATA Secure Erase."
        return 1
    fi

    # Check if drive supports secure erase
    if ! hdparm -I "$disk" 2>/dev/null | grep -q "supported: enhanced erase"; then
        print_color "$YELLOW" "Drive may not support ATA Secure Erase. Attempting anyway..."
    fi

    # Check if drive is frozen
    if hdparm -I "$disk" 2>/dev/null | grep -q "frozen"; then
        print_color "$YELLOW" "Drive is frozen. Attempting to unfreeze by suspending system..."
        print_color "$YELLOW" "Press Enter to suspend, then wake the system..."
        read -r
        echo mem > /sys/power/state || true
        sleep 2
    fi

    # Set password and perform secure erase
    print_color "$CYAN" "Setting security password..."
    hdparm --user-master u --security-set-pass Erase "$disk" || {
        print_color "$RED" "Failed to set security password."
        return 1
    }

    print_color "$CYAN" "Performing secure erase (this may take a while)..."
    hdparm --user-master u --security-erase Erase "$disk" || {
        print_color "$RED" "Secure erase failed."
        return 1
    }

    print_color "$GREEN" "ATA Secure Erase complete."
}

#######################################
# Use shred if available
#######################################
wipe_shred() {
    local disk=$1
    local passes=${2:-3}

    if [[ "$SHRED_AVAILABLE" != "true" ]]; then
        print_color "$RED" "shred is not available."
        return 1
    fi

    print_color "$BLUE" "Starting shred with $passes passes on $disk..."
    shred -v -n "$passes" "$disk"

    print_color "$GREEN" "Shred complete."
}

#######################################
# Interactive nwipe session
#######################################
run_nwipe_interactive() {
    if [[ "$NWIPE_AVAILABLE" != "true" ]]; then
        print_color "$RED" "nwipe is not available."
        print_color "$YELLOW" "Run: sudo ./setup-nwipe.sh to install it."
        return 1
    fi

    print_color "$BLUE" "Launching nwipe interactive mode..."
    print_color "$YELLOW" "Use arrow keys to select disks, Space to toggle, F10 to start."
    echo ""
    sleep 2

    nwipe
}

#######################################
# Main menu
#######################################
main_menu() {
    while true; do
        print_header

        print_color "$WHITE" "Main Menu:"
        echo ""
        print_color "$GREEN" "  [1] Wipe a specific disk"
        print_color "$GREEN" "  [2] Launch nwipe interactive (recommended)"
        print_color "$GREEN" "  [3] View disk information"
        print_color "$GREEN" "  [4] Check tools status"
        print_color "$GREEN" "  [Q] Quit"
        echo ""
        print_color "$WHITE" "Select an option: "
        read -r choice

        case $choice in
            1)
                wipe_disk_menu
                ;;
            2)
                run_nwipe_interactive
                print_color "$WHITE" "Press Enter to continue..."
                read -r
                ;;
            3)
                print_header
                print_color "$WHITE" "Disk Information:"
                echo ""
                lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL
                echo ""
                print_color "$WHITE" "Press Enter to continue..."
                read -r
                ;;
            4)
                print_header
                print_color "$WHITE" "Tools Status:"
                echo ""
                for tool in dd nwipe shred hdparm lsblk blkdiscard; do
                    if command -v "$tool" &> /dev/null; then
                        print_color "$GREEN" "  ✓ $tool - available"
                    else
                        print_color "$RED" "  ✗ $tool - not installed"
                    fi
                done
                echo ""
                print_color "$WHITE" "Press Enter to continue..."
                read -r
                ;;
            [Qq])
                print_color "$GREEN" "Goodbye!"
                exit 0
                ;;
            *)
                print_color "$RED" "Invalid option."
                sleep 1
                ;;
        esac
    done
}

#######################################
# Disk wipe menu
#######################################
wipe_disk_menu() {
    print_header
    list_disks

    if [[ ${#AVAILABLE_DISKS[@]} -eq 0 ]]; then
        print_color "$RED" "No disks available for wiping."
        print_color "$WHITE" "Press Enter to continue..."
        read -r
        return
    fi

    print_color "$WHITE" "Enter disk number to wipe (or 'q' to go back): "
    read -r disk_choice

    if [[ "$disk_choice" == "q" ]]; then
        return
    fi

    if ! [[ "$disk_choice" =~ ^[0-9]+$ ]] || [[ "$disk_choice" -lt 1 ]] || [[ "$disk_choice" -gt ${#AVAILABLE_DISKS[@]} ]]; then
        print_color "$RED" "Invalid selection."
        sleep 1
        return
    fi

    local selected_disk="${AVAILABLE_DISKS[$((disk_choice-1))]}"

    # Show wipe methods
    print_header
    show_wipe_methods

    print_color "$WHITE" "Select wipe method (or 'q' to go back): "
    read -r method_choice

    if [[ "$method_choice" == "q" ]]; then
        return
    fi

    local method_name
    case $method_choice in
        1) method_name="Quick Zero Fill" ;;
        2) method_name="Random Fill" ;;
        3) method_name="DoD 5220.22-M (3-pass)" ;;
        4) method_name="DoD 5220.22-M ECE (7-pass)" ;;
        5) method_name="Gutmann (35-pass)" ;;
        6) method_name="NIST 800-88 ATA Secure Erase" ;;
        *)
            print_color "$RED" "Invalid selection."
            sleep 1
            return
            ;;
    esac

    # Confirm wipe
    print_header
    if ! confirm_wipe "$selected_disk" "$method_name"; then
        return
    fi

    # Unmount all partitions on the disk
    print_color "$BLUE" "Unmounting any mounted partitions..."
    for part in "$selected_disk"*; do
        umount "$part" 2>/dev/null || true
    done

    # Perform the wipe
    local start_time
    start_time=$(date +%s)

    case $method_choice in
        1) wipe_zeros "$selected_disk" ;;
        2) wipe_random "$selected_disk" ;;
        3) wipe_dod_3pass "$selected_disk" ;;
        4) wipe_dod_7pass "$selected_disk" ;;
        5) wipe_gutmann "$selected_disk" ;;
        6) wipe_secure_erase "$selected_disk" ;;
    esac

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    echo ""
    print_color "$GREEN" "╔════════════════════════════════════════════════════════════════╗"
    print_color "$GREEN" "║                    WIPE COMPLETE                               ║"
    print_color "$GREEN" "╚════════════════════════════════════════════════════════════════╝"
    print_color "$WHITE" "Disk: $selected_disk"
    print_color "$WHITE" "Method: $method_name"
    print_color "$WHITE" "Duration: $((duration / 60)) minutes $((duration % 60)) seconds"
    echo ""
    print_color "$WHITE" "Press Enter to continue..."
    read -r
}

#######################################
# Main
#######################################
main() {
    check_root
    check_dependencies
    main_menu
}

# Run main
main "$@"
