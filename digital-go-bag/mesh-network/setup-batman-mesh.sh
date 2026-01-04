#!/bin/bash
#
# BATMAN-ADV MESH NETWORK SETUP
# Creates a decentralized mesh network using the Linux kernel's BATMAN-adv protocol
#
# BATMAN-adv (Better Approach To Mobile Adhoc Networking - advanced) is a
# layer 2 mesh routing protocol that operates at the data link layer.
#
# Requirements:
#   - Linux with batman-adv kernel module
#   - WiFi adapter that supports ad-hoc mode
#   - batctl utility
#
# Usage: sudo ./setup-batman-mesh.sh [start|stop|status]
#

set -euo pipefail

# Configuration - EDIT THESE
MESH_INTERFACE="wlan0"          # Your WiFi interface
MESH_ESSID="MESHNET"            # Network name (all nodes must match)
MESH_CHANNEL="6"                # WiFi channel (all nodes must match)
MESH_IP="10.99.0.1"             # This node's IP (change for each node: .1, .2, .3, etc.)
MESH_NETMASK="255.255.0.0"      # Allows 65k+ nodes
BAT_INTERFACE="bat0"            # BATMAN virtual interface

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

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_color "$RED" "ERROR: This script must be run as root"
        exit 1
    fi
}

check_dependencies() {
    local missing=()

    # Check for required tools
    for cmd in ip iw batctl; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done

    # Check for batman-adv module
    if ! modprobe -n batman-adv 2>/dev/null; then
        missing+=("batman-adv kernel module")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        print_color "$RED" "Missing dependencies: ${missing[*]}"
        print_color "$YELLOW" "Install with:"
        print_color "$WHITE" "  Debian/Ubuntu: sudo apt install batctl wireless-tools iw"
        print_color "$WHITE" "  Fedora: sudo dnf install batctl iw wireless-tools"
        print_color "$WHITE" "  Arch: sudo pacman -S batctl iw"
        exit 1
    fi
}

check_interface() {
    if ! ip link show "$MESH_INTERFACE" &>/dev/null; then
        print_color "$RED" "ERROR: Interface $MESH_INTERFACE not found"
        print_color "$YELLOW" "Available interfaces:"
        ip link show | grep -E "^[0-9]+" | awk -F: '{print "  " $2}'
        exit 1
    fi

    # Check if interface supports ad-hoc
    if ! iw list 2>/dev/null | grep -q "IBSS"; then
        print_color "$YELLOW" "WARNING: Your WiFi adapter may not support ad-hoc mode"
    fi
}

stop_conflicting_services() {
    print_color "$BLUE" "Stopping conflicting services..."

    # Stop NetworkManager for this interface
    if command -v nmcli &>/dev/null; then
        nmcli device set "$MESH_INTERFACE" managed no 2>/dev/null || true
    fi

    # Stop wpa_supplicant
    pkill -f "wpa_supplicant.*$MESH_INTERFACE" 2>/dev/null || true

    # Kill dhclient
    pkill -f "dhclient.*$MESH_INTERFACE" 2>/dev/null || true
}

start_mesh() {
    print_color "$CYAN" "╔════════════════════════════════════════════════════════════════╗"
    print_color "$CYAN" "║              BATMAN-ADV MESH NETWORK SETUP                     ║"
    print_color "$CYAN" "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    check_root
    check_dependencies
    check_interface
    stop_conflicting_services

    print_color "$BLUE" "Loading batman-adv kernel module..."
    modprobe batman-adv

    print_color "$BLUE" "Configuring $MESH_INTERFACE for ad-hoc mode..."

    # Bring interface down
    ip link set "$MESH_INTERFACE" down

    # Set ad-hoc mode
    iw dev "$MESH_INTERFACE" set type ibss

    # Bring interface up
    ip link set "$MESH_INTERFACE" up

    # Join/create ad-hoc network
    print_color "$BLUE" "Joining mesh network: $MESH_ESSID on channel $MESH_CHANNEL..."
    iw dev "$MESH_INTERFACE" ibss join "$MESH_ESSID" 2412 # 2412 MHz = channel 1, adjust as needed

    # For specific channel, calculate frequency: 2407 + (channel * 5) MHz
    # Channel 6 = 2437 MHz, Channel 11 = 2462 MHz

    # Add interface to batman-adv
    print_color "$BLUE" "Adding $MESH_INTERFACE to BATMAN-adv..."
    batctl if add "$MESH_INTERFACE"

    # Bring up bat0 interface
    ip link set "$BAT_INTERFACE" up

    # Assign IP address
    print_color "$BLUE" "Assigning IP address: $MESH_IP..."
    ip addr add "$MESH_IP/$MESH_NETMASK" dev "$BAT_INTERFACE" 2>/dev/null || \
        ip addr replace "$MESH_IP/$MESH_NETMASK" dev "$BAT_INTERFACE"

    # Set MTU (optional, helps with some setups)
    ip link set "$BAT_INTERFACE" mtu 1500

    echo ""
    print_color "$GREEN" "╔════════════════════════════════════════════════════════════════╗"
    print_color "$GREEN" "║                  MESH NETWORK ACTIVE                           ║"
    print_color "$GREEN" "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    print_color "$WHITE" "Configuration:"
    echo "  Network Name: $MESH_ESSID"
    echo "  Channel: $MESH_CHANNEL"
    echo "  This Node IP: $MESH_IP"
    echo "  Interface: $BAT_INTERFACE"
    echo ""
    print_color "$WHITE" "Other nodes should run this script with a different MESH_IP"
    print_color "$WHITE" "Example: 10.99.0.2, 10.99.0.3, etc."
    echo ""
    print_color "$YELLOW" "Useful commands:"
    echo "  batctl n          - Show neighbor nodes"
    echo "  batctl o          - Show originator table (all mesh nodes)"
    echo "  batctl tg         - Show translation table"
    echo "  ping 10.99.0.X    - Ping another node"
}

stop_mesh() {
    print_color "$BLUE" "Stopping mesh network..."

    # Remove interface from batman-adv
    batctl if del "$MESH_INTERFACE" 2>/dev/null || true

    # Bring down bat0
    ip link set "$BAT_INTERFACE" down 2>/dev/null || true

    # Leave ad-hoc network
    iw dev "$MESH_INTERFACE" ibss leave 2>/dev/null || true

    # Reset interface to managed mode
    ip link set "$MESH_INTERFACE" down
    iw dev "$MESH_INTERFACE" set type managed 2>/dev/null || true
    ip link set "$MESH_INTERFACE" up

    # Re-enable NetworkManager management
    if command -v nmcli &>/dev/null; then
        nmcli device set "$MESH_INTERFACE" managed yes 2>/dev/null || true
    fi

    print_color "$GREEN" "Mesh network stopped."
}

show_status() {
    print_color "$CYAN" "BATMAN-adv Mesh Status"
    echo ""

    if ! ip link show "$BAT_INTERFACE" &>/dev/null; then
        print_color "$RED" "Mesh network is not running."
        return
    fi

    print_color "$WHITE" "Interface Status:"
    ip addr show "$BAT_INTERFACE"
    echo ""

    print_color "$WHITE" "BATMAN-adv Interfaces:"
    batctl if
    echo ""

    print_color "$WHITE" "Neighbor Nodes (directly connected):"
    batctl n 2>/dev/null || echo "  No neighbors found"
    echo ""

    print_color "$WHITE" "All Mesh Nodes (originator table):"
    batctl o 2>/dev/null || echo "  No originators found"
    echo ""

    print_color "$WHITE" "Gateway Mode:"
    batctl gw_mode
}

show_help() {
    echo "BATMAN-adv Mesh Network Setup"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  start   - Start the mesh network"
    echo "  stop    - Stop the mesh network"
    echo "  status  - Show mesh network status"
    echo "  help    - Show this help"
    echo ""
    echo "Configuration (edit script to change):"
    echo "  MESH_INTERFACE=$MESH_INTERFACE"
    echo "  MESH_ESSID=$MESH_ESSID"
    echo "  MESH_CHANNEL=$MESH_CHANNEL"
    echo "  MESH_IP=$MESH_IP"
}

# Main
case "${1:-start}" in
    start)
        start_mesh
        ;;
    stop)
        check_root
        stop_mesh
        ;;
    status)
        show_status
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
