#!/bin/bash
#
# HARDWARE INFORMATION UTILITY
# Comprehensive system hardware report
#

set -euo pipefail

# Colors
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_section() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
}

show_summary() {
    print_section "SYSTEM SUMMARY"

    echo ""
    echo -e "${WHITE}Hostname:${NC} $(hostname)"
    echo -e "${WHITE}Kernel:${NC} $(uname -r)"
    echo -e "${WHITE}Architecture:${NC} $(uname -m)"
    echo -e "${WHITE}OS:${NC} $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || uname -o)"
    echo -e "${WHITE}Uptime:${NC} $(uptime -p 2>/dev/null || uptime)"
}

show_cpu() {
    print_section "CPU"

    if [[ -f /proc/cpuinfo ]]; then
        local model cores threads freq

        model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ *//')
        cores=$(grep "cpu cores" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ *//')
        threads=$(grep -c "processor" /proc/cpuinfo)
        freq=$(grep "cpu MHz" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ *//')

        echo ""
        echo -e "${WHITE}Model:${NC} $model"
        echo -e "${WHITE}Cores:${NC} ${cores:-?}"
        echo -e "${WHITE}Threads:${NC} $threads"
        echo -e "${WHITE}Current Freq:${NC} ${freq:-?} MHz"

        # Temperature
        if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
            local temp
            temp=$(cat /sys/class/thermal/thermal_zone0/temp)
            echo -e "${WHITE}Temperature:${NC} $((temp/1000))°C"
        fi

        # Governor
        if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]]; then
            echo -e "${WHITE}Governor:${NC} $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
        fi
    fi
}

show_memory() {
    print_section "MEMORY"

    echo ""
    free -h

    echo ""
    echo -e "${WHITE}Memory Details:${NC}"
    grep -E "MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree" /proc/meminfo
}

show_storage() {
    print_section "STORAGE"

    echo ""
    echo -e "${WHITE}Block Devices:${NC}"
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL 2>/dev/null || lsblk

    echo ""
    echo -e "${WHITE}Disk Usage:${NC}"
    df -h -x tmpfs -x devtmpfs -x squashfs 2>/dev/null || df -h
}

show_network() {
    print_section "NETWORK"

    echo ""
    echo -e "${WHITE}Interfaces:${NC}"
    ip -br addr 2>/dev/null || ip addr

    echo ""
    echo -e "${WHITE}Wireless:${NC}"
    if command -v iw &>/dev/null; then
        for dev in /sys/class/net/wlan*; do
            if [[ -d "$dev" ]]; then
                local iface
                iface=$(basename "$dev")
                echo "  $iface:"
                iw dev "$iface" info 2>/dev/null | grep -E "ssid|channel|txpower" | sed 's/^/    /'
            fi
        done
    else
        echo "  iw not installed"
    fi

    echo ""
    echo -e "${WHITE}Routing:${NC}"
    ip route | head -5
}

show_usb() {
    print_section "USB DEVICES"

    echo ""
    if command -v lsusb &>/dev/null; then
        lsusb
    else
        echo "lsusb not installed"
        ls /sys/bus/usb/devices/ 2>/dev/null || true
    fi
}

show_pci() {
    print_section "PCI DEVICES"

    echo ""
    if command -v lspci &>/dev/null; then
        lspci | grep -E "VGA|Network|Audio|USB|SATA|NVMe" || lspci
    else
        echo "lspci not installed"
    fi
}

show_battery() {
    print_section "POWER/BATTERY"

    echo ""
    for bat in /sys/class/power_supply/BAT*; do
        if [[ -d "$bat" ]]; then
            echo -e "${WHITE}$(basename "$bat"):${NC}"
            echo "  Status: $(cat "$bat/status" 2>/dev/null || echo "?")"
            echo "  Capacity: $(cat "$bat/capacity" 2>/dev/null || echo "?")%"

            local energy_full energy_now
            energy_full=$(cat "$bat/energy_full" 2>/dev/null || echo "0")
            energy_now=$(cat "$bat/energy_now" 2>/dev/null || echo "0")
            if [[ "$energy_full" != "0" ]]; then
                echo "  Energy: $((energy_now/1000000))/$((energy_full/1000000)) Wh"
            fi
        fi
    done

    for ac in /sys/class/power_supply/AC* /sys/class/power_supply/ADP*; do
        if [[ -f "$ac/online" ]]; then
            local status="Disconnected"
            [[ $(cat "$ac/online") == "1" ]] && status="Connected"
            echo -e "${WHITE}AC Adapter:${NC} $status"
        fi
    done 2>/dev/null
}

show_all() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              COMPLETE HARDWARE REPORT                          ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"

    show_summary
    show_cpu
    show_memory
    show_storage
    show_network
    show_usb
    show_pci
    show_battery

    print_section "REPORT COMPLETE"
    echo ""
    echo "Generated: $(date)"
}

save_report() {
    local output="${1:-hardware-report-$(date +%Y%m%d-%H%M%S).txt}"

    show_all > "$output"
    echo -e "${GREEN}Report saved to: $output${NC}"
}

show_help() {
    echo "Hardware Information Utility"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  all       - Show complete hardware report (default)"
    echo "  summary   - System summary only"
    echo "  cpu       - CPU information"
    echo "  memory    - Memory information"
    echo "  storage   - Storage devices and usage"
    echo "  network   - Network interfaces"
    echo "  usb       - USB devices"
    echo "  pci       - PCI devices"
    echo "  battery   - Power/battery status"
    echo "  save      - Save report to file"
    echo "  help      - Show this help"
}

case "${1:-all}" in
    all) show_all ;;
    summary) show_summary ;;
    cpu) show_cpu ;;
    memory|mem|ram) show_memory ;;
    storage|disk) show_storage ;;
    network|net) show_network ;;
    usb) show_usb ;;
    pci) show_pci ;;
    battery|power) show_battery ;;
    save) save_report "${2:-}" ;;
    help|--help|-h) show_help ;;
    *) echo "Unknown: $1"; show_help; exit 1 ;;
esac
