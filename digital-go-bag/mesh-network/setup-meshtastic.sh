#!/bin/bash
#
# MESHTASTIC SETUP & MANAGEMENT
# Configure and manage Meshtastic LoRa mesh devices
#
# Meshtastic creates long-range (km+) mesh networks using LoRa radio.
# Works without any internet/cellular infrastructure.
#
# Hardware needed:
#   - Meshtastic-compatible device (TTGO T-Beam, Heltec, RAK, etc.)
#   - ~$25-50 per node
#
# Range: 1-10+ km depending on terrain and antenna
#
# Usage: ./setup-meshtastic.sh [install|configure|send|status]
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

install_meshtastic() {
    print_color "$CYAN" "╔════════════════════════════════════════════════════════════════╗"
    print_color "$CYAN" "║              MESHTASTIC CLI INSTALLATION                       ║"
    print_color "$CYAN" "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    # Check for Python
    if ! command -v python3 &>/dev/null; then
        print_color "$RED" "Python 3 is required."
        print_color "$YELLOW" "Install with: sudo apt install python3 python3-pip"
        exit 1
    fi

    print_color "$BLUE" "Installing Meshtastic CLI..."
    pip3 install --user meshtastic

    # Add to PATH if needed
    if ! command -v meshtastic &>/dev/null; then
        export PATH="$HOME/.local/bin:$PATH"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    fi

    print_color "$GREEN" "Meshtastic CLI installed!"
    echo ""
    print_color "$WHITE" "Connect your Meshtastic device via USB and run:"
    echo "  meshtastic --info"
}

detect_device() {
    # Look for common Meshtastic device paths
    local devices=(
        "/dev/ttyUSB0"
        "/dev/ttyACM0"
        "/dev/ttyUSB1"
        "/dev/ttyACM1"
    )

    for dev in "${devices[@]}"; do
        if [[ -e "$dev" ]]; then
            echo "$dev"
            return 0
        fi
    done

    # Try to find by USB ID
    if command -v lsusb &>/dev/null; then
        # Common Meshtastic device USB IDs
        if lsusb | grep -qiE "1a86:7523|10c4:ea60|303a:1001"; then
            # Found a likely device, check tty
            for dev in /dev/ttyUSB* /dev/ttyACM*; do
                if [[ -e "$dev" ]]; then
                    echo "$dev"
                    return 0
                fi
            done
        fi
    fi

    return 1
}

configure_device() {
    print_color "$CYAN" "╔════════════════════════════════════════════════════════════════╗"
    print_color "$CYAN" "║              MESHTASTIC DEVICE CONFIGURATION                   ║"
    print_color "$CYAN" "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    local device
    if ! device=$(detect_device); then
        print_color "$RED" "No Meshtastic device found."
        print_color "$YELLOW" "Connect device via USB and try again."
        exit 1
    fi

    print_color "$GREEN" "Found device: $device"
    echo ""

    # Show current config
    print_color "$BLUE" "Current device info:"
    meshtastic --port "$device" --info
    echo ""

    # Configuration options
    print_color "$WHITE" "Configuration Options:"
    echo ""
    echo "  [1] Set device name"
    echo "  [2] Set region (radio frequency)"
    echo "  [3] Set channel (encryption key)"
    echo "  [4] Enable/disable GPS"
    echo "  [5] Set as router (extends mesh)"
    echo "  [6] Factory reset"
    echo "  [7] Exit"
    echo ""

    while true; do
        print_color "$WHITE" "Select option: "
        read -r choice

        case $choice in
            1)
                print_color "$WHITE" "Enter device name: "
                read -r name
                meshtastic --port "$device" --set-owner "$name"
                print_color "$GREEN" "Name set to: $name"
                ;;
            2)
                print_color "$WHITE" "Select region:"
                echo "  US - United States (915MHz)"
                echo "  EU_868 - Europe (868MHz)"
                echo "  AU - Australia (915MHz)"
                echo "  JP - Japan (920MHz)"
                echo "  CN - China (470MHz)"
                print_color "$WHITE" "Enter region code: "
                read -r region
                meshtastic --port "$device" --set lora.region "$region"
                print_color "$GREEN" "Region set to: $region"
                ;;
            3)
                print_color "$WHITE" "Channel setup:"
                echo "  1) Use default channel (open, anyone can join)"
                echo "  2) Create private channel with password"
                print_color "$WHITE" "Choice: "
                read -r ch_choice
                if [[ "$ch_choice" == "2" ]]; then
                    print_color "$WHITE" "Enter channel name: "
                    read -r ch_name
                    print_color "$WHITE" "Enter password (PSK): "
                    read -r ch_psk
                    meshtastic --port "$device" --ch-set name "$ch_name" --ch-set psk "$ch_psk" --ch-index 0
                    print_color "$GREEN" "Private channel created: $ch_name"
                    print_color "$YELLOW" "Share this with others to join your mesh:"
                    meshtastic --port "$device" --qr
                else
                    meshtastic --port "$device" --ch-set psk none --ch-index 0
                    print_color "$GREEN" "Using default open channel"
                fi
                ;;
            4)
                print_color "$WHITE" "Enable GPS? [y/n]: "
                read -r gps_choice
                if [[ "$gps_choice" =~ ^[Yy] ]]; then
                    meshtastic --port "$device" --set position.gps_enabled true
                    print_color "$GREEN" "GPS enabled"
                else
                    meshtastic --port "$device" --set position.gps_enabled false
                    print_color "$GREEN" "GPS disabled"
                fi
                ;;
            5)
                print_color "$WHITE" "Device roles:"
                echo "  CLIENT - Normal device"
                echo "  ROUTER - Extends mesh, always listening"
                echo "  ROUTER_CLIENT - Router that also shows messages"
                print_color "$WHITE" "Enter role: "
                read -r role
                meshtastic --port "$device" --set device.role "$role"
                print_color "$GREEN" "Role set to: $role"
                ;;
            6)
                print_color "$RED" "This will erase all settings!"
                print_color "$WHITE" "Type 'RESET' to confirm: "
                read -r confirm
                if [[ "$confirm" == "RESET" ]]; then
                    meshtastic --port "$device" --factory-reset
                    print_color "$GREEN" "Factory reset complete"
                fi
                ;;
            7)
                break
                ;;
        esac
        echo ""
    done
}

send_message() {
    local message="$*"

    if [[ -z "$message" ]]; then
        print_color "$WHITE" "Enter message: "
        read -r message
    fi

    local device
    if ! device=$(detect_device); then
        print_color "$RED" "No device found."
        exit 1
    fi

    print_color "$BLUE" "Sending: $message"
    meshtastic --port "$device" --sendtext "$message"
    print_color "$GREEN" "Message sent!"
}

show_status() {
    print_color "$CYAN" "Meshtastic Status"
    echo ""

    local device
    if ! device=$(detect_device); then
        print_color "$RED" "No device connected."
        return
    fi

    print_color "$GREEN" "Device: $device"
    echo ""

    print_color "$WHITE" "Device Info:"
    meshtastic --port "$device" --info 2>/dev/null || true
    echo ""

    print_color "$WHITE" "Nodes in mesh:"
    meshtastic --port "$device" --nodes 2>/dev/null || true
}

start_monitor() {
    local device
    if ! device=$(detect_device); then
        print_color "$RED" "No device found."
        exit 1
    fi

    print_color "$CYAN" "Starting message monitor (Ctrl+C to stop)..."
    echo ""

    # Monitor incoming messages
    meshtastic --port "$device" --listen
}

show_help() {
    echo "Meshtastic Setup & Management"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  install    - Install Meshtastic CLI tool"
    echo "  configure  - Interactive device configuration"
    echo "  send       - Send a message to the mesh"
    echo "  status     - Show device and mesh status"
    echo "  monitor    - Listen for incoming messages"
    echo "  help       - Show this help"
    echo ""
    echo "Hardware:"
    echo "  Recommended devices:"
    echo "    - LILYGO T-Beam (~\$35) - Has GPS"
    echo "    - Heltec LoRa 32 (~\$20) - Compact"
    echo "    - RAK WisBlock (~\$30) - Modular"
    echo ""
    echo "  Range: 1-10+ km line of sight"
    echo "  Power: Days on battery, solar capable"
}

# Main
case "${1:-help}" in
    install)
        install_meshtastic
        ;;
    configure|config)
        configure_device
        ;;
    send)
        shift
        send_message "$@"
        ;;
    status)
        show_status
        ;;
    monitor|listen)
        start_monitor
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
