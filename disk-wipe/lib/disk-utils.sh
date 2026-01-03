#!/bin/bash
#
# Disk Utilities Library
# Helper functions for disk operations
#

# Get list of all physical disks
get_physical_disks() {
    lsblk -d -n -o NAME,TYPE | awk '$2=="disk" {print "/dev/"$1}' | grep -v "loop" | grep -v "sr"
}

# Get disk size in bytes
get_disk_size() {
    local disk=$1
    blockdev --getsize64 "$disk" 2>/dev/null || echo "0"
}

# Get disk size in human readable format
get_disk_size_human() {
    local disk=$1
    lsblk -d -n -o SIZE "$disk" 2>/dev/null | tr -d ' '
}

# Get disk model
get_disk_model() {
    local disk=$1
    lsblk -d -n -o MODEL "$disk" 2>/dev/null | sed 's/^ *//;s/ *$//'
}

# Get disk serial number
get_disk_serial() {
    local disk=$1
    local name
    name=$(basename "$disk")
    cat "/sys/block/$name/device/serial" 2>/dev/null || \
        hdparm -I "$disk" 2>/dev/null | grep "Serial Number" | awk -F: '{print $2}' | tr -d ' ' || \
        echo "N/A"
}

# Check if disk is removable (USB)
is_removable() {
    local disk=$1
    local name
    name=$(basename "$disk")
    [[ $(cat "/sys/block/$name/removable" 2>/dev/null) == "1" ]]
}

# Check if disk is an SSD
is_ssd() {
    local disk=$1
    local name
    name=$(basename "$disk")
    [[ $(cat "/sys/block/$name/queue/rotational" 2>/dev/null) == "0" ]]
}

# Check if disk is NVMe
is_nvme() {
    local disk=$1
    [[ "$disk" == *"nvme"* ]]
}

# Check if disk has mounted partitions
has_mounted_partitions() {
    local disk=$1
    mount | grep -q "^$disk"
}

# Get mount points for a disk
get_mount_points() {
    local disk=$1
    mount | grep "^$disk" | awk '{print $3}'
}

# Unmount all partitions on a disk
unmount_disk() {
    local disk=$1
    local success=true

    for part in "$disk"*; do
        if mount | grep -q "^$part"; then
            if ! umount "$part" 2>/dev/null; then
                if ! umount -f "$part" 2>/dev/null; then
                    success=false
                fi
            fi
        fi
    done

    $success
}

# Check if disk is the boot device
is_boot_device() {
    local disk=$1
    local root_dev
    root_dev=$(findmnt -n -o SOURCE / 2>/dev/null | sed 's/[0-9]*$//' | sed 's/p$//')

    [[ "$disk" == "$root_dev" ]]
}

# Get disk transport type (SATA, NVMe, USB, etc.)
get_transport_type() {
    local disk=$1
    local name
    name=$(basename "$disk")

    if [[ "$name" == nvme* ]]; then
        echo "NVMe"
    elif is_removable "$disk"; then
        echo "USB"
    else
        local transport
        transport=$(cat "/sys/block/$name/device/transport" 2>/dev/null || echo "unknown")
        echo "${transport^^}"
    fi
}

# Get estimated wipe time (rough estimate based on disk size and method)
estimate_wipe_time() {
    local disk=$1
    local passes=${2:-1}

    local size
    size=$(get_disk_size "$disk")

    # Assume ~100MB/s write speed for HDDs, ~500MB/s for SSDs
    local speed
    if is_ssd "$disk"; then
        speed=500000000  # 500 MB/s
    else
        speed=100000000  # 100 MB/s
    fi

    local time_per_pass=$((size / speed))
    local total_time=$((time_per_pass * passes))

    # Format as hours:minutes:seconds
    printf "%02d:%02d:%02d" $((total_time/3600)) $((total_time%3600/60)) $((total_time%60))
}

# Print disk information
print_disk_info() {
    local disk=$1

    echo "Device: $disk"
    echo "Model: $(get_disk_model "$disk")"
    echo "Size: $(get_disk_size_human "$disk")"
    echo "Serial: $(get_disk_serial "$disk")"
    echo "Transport: $(get_transport_type "$disk")"
    echo "SSD: $(is_ssd "$disk" && echo "Yes" || echo "No")"
    echo "Removable: $(is_removable "$disk" && echo "Yes" || echo "No")"

    if has_mounted_partitions "$disk"; then
        echo "Mounted: Yes ($(get_mount_points "$disk" | tr '\n' ' '))"
    else
        echo "Mounted: No"
    fi
}

# Verify wipe by reading random sectors
verify_wipe() {
    local disk=$1
    local pattern=${2:-"00"}  # Default to checking for zeros
    local sectors_to_check=10

    local size
    size=$(get_disk_size "$disk")
    local sector_size=512
    local total_sectors=$((size / sector_size))

    local verified=true

    for i in $(seq 1 $sectors_to_check); do
        local sector=$((RANDOM % total_sectors))
        local data
        data=$(dd if="$disk" bs=$sector_size skip="$sector" count=1 2>/dev/null | xxd -p | head -c 32)

        if [[ "$pattern" == "00" ]]; then
            if ! echo "$data" | grep -q "^0*$"; then
                verified=false
                break
            fi
        fi
    done

    $verified
}
