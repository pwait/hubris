#!/bin/bash
#
# SDR (Software Defined Radio) SCANNER SETUP
# Listen to radio frequencies using cheap RTL-SDR dongles
#
# Hardware: RTL-SDR dongle (~$25) - RTL2832U based
# Frequency range: 24 MHz - 1766 MHz
#
# Can receive:
#   - FM broadcast radio
#   - NOAA weather radio
#   - Aircraft communications
#   - Amateur radio
#   - Public safety (unencrypted)
#   - Marine VHF
#

set -euo pipefail

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

install_rtlsdr() {
    print_color "$CYAN" "╔════════════════════════════════════════════════════════════════╗"
    print_color "$CYAN" "║                 RTL-SDR INSTALLATION                           ║"
    print_color "$CYAN" "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    # Detect distro
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    else
        DISTRO="unknown"
    fi

    print_color "$BLUE" "Installing RTL-SDR tools for $DISTRO..."

    case $DISTRO in
        ubuntu|debian|linuxmint|pop)
            sudo apt-get update
            sudo apt-get install -y rtl-sdr librtlsdr-dev sox
            # Optional GUI tools
            sudo apt-get install -y gqrx-sdr 2>/dev/null || true
            ;;
        fedora)
            sudo dnf install -y rtl-sdr rtl-sdr-devel sox
            sudo dnf install -y gqrx 2>/dev/null || true
            ;;
        arch|manjaro)
            sudo pacman -Sy --noconfirm rtl-sdr sox
            sudo pacman -S --noconfirm gqrx 2>/dev/null || true
            ;;
        *)
            print_color "$RED" "Unknown distro. Install rtl-sdr manually."
            return 1
            ;;
    esac

    # Blacklist kernel driver that conflicts with RTL-SDR
    print_color "$BLUE" "Configuring kernel modules..."
    echo 'blacklist dvb_usb_rtl28xxu' | sudo tee /etc/modprobe.d/blacklist-rtlsdr.conf
    echo 'blacklist rtl2832' | sudo tee -a /etc/modprobe.d/blacklist-rtlsdr.conf

    # Udev rules for non-root access
    print_color "$BLUE" "Setting up udev rules..."
    cat << 'RULES' | sudo tee /etc/udev/rules.d/20-rtlsdr.rules
SUBSYSTEM=="usb", ATTRS{idVendor}=="0bda", ATTRS{idProduct}=="2838", GROUP="plugdev", MODE="0666"
SUBSYSTEM=="usb", ATTRS{idVendor}=="0bda", ATTRS{idProduct}=="2832", GROUP="plugdev", MODE="0666"
RULES
    sudo udevadm control --reload-rules
    sudo udevadm trigger

    print_color "$GREEN" "RTL-SDR installed!"
    print_color "$YELLOW" "Unplug and replug your RTL-SDR dongle."
}

test_device() {
    print_color "$BLUE" "Testing RTL-SDR device..."

    if ! command -v rtl_test &>/dev/null; then
        print_color "$RED" "rtl_test not found. Run: $0 install"
        return 1
    fi

    # Quick test
    timeout 5 rtl_test -t 2>&1 || true

    print_color "$GREEN" "If you see 'Found 1 device(s)', the SDR is working."
}

listen_fm() {
    local freq="${1:-98.5}"

    print_color "$BLUE" "Listening to FM ${freq} MHz..."
    print_color "$YELLOW" "Press Ctrl+C to stop"

    # RTL_FM to audio
    rtl_fm -f "${freq}M" -M wbfm -s 200000 -r 48000 - | \
        play -r 48000 -t raw -e s -b 16 -c 1 -V1 -
}

listen_noaa() {
    # NOAA weather frequencies
    local freqs=(162.400 162.425 162.450 162.475 162.500 162.525 162.550)

    print_color "$BLUE" "Scanning NOAA weather frequencies..."
    print_color "$YELLOW" "Press Ctrl+C to stop"

    for freq in "${freqs[@]}"; do
        print_color "$CYAN" "Trying ${freq} MHz..."
        timeout 10 rtl_fm -f "${freq}M" -M fm -s 12000 -r 12000 - 2>/dev/null | \
            play -r 12000 -t raw -e s -b 16 -c 1 -V1 - 2>/dev/null &
        local pid=$!
        sleep 8
        kill $pid 2>/dev/null || true
    done
}

scan_range() {
    local start="${1:-88}"
    local end="${2:-108}"
    local step="${3:-0.2}"

    print_color "$BLUE" "Scanning ${start}-${end} MHz..."

    if ! command -v rtl_power &>/dev/null; then
        print_color "$RED" "rtl_power not found"
        return 1
    fi

    local output="/tmp/scan_$(date +%s).csv"
    print_color "$YELLOW" "Saving to: $output"

    rtl_power -f "${start}M:${end}M:${step}M" -g 50 -i 10 "$output"

    print_color "$GREEN" "Scan complete. Results in: $output"
}

launch_gqrx() {
    if ! command -v gqrx &>/dev/null; then
        print_color "$RED" "GQRX not installed."
        print_color "$YELLOW" "GQRX is a graphical SDR application."
        print_color "$YELLOW" "Install with: sudo apt install gqrx-sdr"
        return 1
    fi

    print_color "$BLUE" "Launching GQRX..."
    gqrx &
}

show_frequencies() {
    print_color "$CYAN" "╔════════════════════════════════════════════════════════════════╗"
    print_color "$CYAN" "║              COMMON FREQUENCIES                                ║"
    print_color "$CYAN" "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    cat << 'EOF'
FM Broadcast:       88-108 MHz
NOAA Weather:       162.400-162.550 MHz
Aircraft:           118-137 MHz
Marine VHF:         156-163 MHz
2m Amateur:         144-148 MHz
70cm Amateur:       420-450 MHz
FRS/GMRS:           462-467 MHz
MURS:               151-154 MHz
Railroad:           160-161 MHz
Pagers:             152, 157, 454, 931 MHz

Note: Reception only - transmitting requires license and proper equipment
EOF
}

show_help() {
    echo "SDR Scanner - RTL-SDR Radio Receiver"
    echo ""
    echo "Usage: $0 [command] [args]"
    echo ""
    echo "Commands:"
    echo "  install           - Install RTL-SDR software"
    echo "  test              - Test SDR device"
    echo "  fm <freq>         - Listen to FM radio (e.g., 98.5)"
    echo "  noaa              - Scan NOAA weather frequencies"
    echo "  scan <start> <end>- Scan frequency range"
    echo "  gqrx              - Launch GQRX GUI"
    echo "  frequencies       - Show common frequencies"
    echo ""
    echo "Examples:"
    echo "  $0 fm 101.5        - Listen to 101.5 FM"
    echo "  $0 noaa            - Find active weather station"
    echo "  $0 scan 118 137    - Scan aircraft band"
}

case "${1:-help}" in
    install)
        install_rtlsdr
        ;;
    test)
        test_device
        ;;
    fm)
        listen_fm "${2:-98.5}"
        ;;
    noaa|weather)
        listen_noaa
        ;;
    scan)
        scan_range "${2:-88}" "${3:-108}" "${4:-0.2}"
        ;;
    gqrx)
        launch_gqrx
        ;;
    freq|frequencies)
        show_frequencies
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_color "$RED" "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
