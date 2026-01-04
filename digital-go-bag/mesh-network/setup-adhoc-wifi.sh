#!/bin/bash
#
# SIMPLE AD-HOC WIFI NETWORK
# Creates a basic peer-to-peer WiFi network without any infrastructure
#
# This is simpler than BATMAN-adv but doesn't provide mesh routing.
# Good for small groups in close proximity.
#
# Usage: sudo ./setup-adhoc-wifi.sh [start|stop|status]
#

set -euo pipefail

# Configuration - EDIT THESE
WIFI_INTERFACE="wlan0"
ADHOC_ESSID="LOCALNET"
ADHOC_CHANNEL="6"
NODE_IP="192.168.50.1"          # Change for each device: .1, .2, .3, etc.
NETMASK="255.255.255.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_color() {
    echo -e "${1}${2}${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_color "$RED" "ERROR: Run as root"
        exit 1
    fi
}

start_adhoc() {
    print_color "$BLUE" "Setting up ad-hoc WiFi network..."

    # Stop NetworkManager control of interface
    if command -v nmcli &>/dev/null; then
        nmcli device set "$WIFI_INTERFACE" managed no 2>/dev/null || true
    fi

    # Stop any existing connections
    pkill -f "wpa_supplicant.*$WIFI_INTERFACE" 2>/dev/null || true
    pkill -f "dhclient.*$WIFI_INTERFACE" 2>/dev/null || true

    # Configure interface
    ip link set "$WIFI_INTERFACE" down
    iw dev "$WIFI_INTERFACE" set type ibss
    ip link set "$WIFI_INTERFACE" up

    # Calculate frequency from channel (2.4GHz band)
    local freq=$((2407 + ADHOC_CHANNEL * 5))

    # Join/create ad-hoc network
    iw dev "$WIFI_INTERFACE" ibss join "$ADHOC_ESSID" "$freq"

    # Set IP address
    ip addr flush dev "$WIFI_INTERFACE"
    ip addr add "$NODE_IP/$NETMASK" dev "$WIFI_INTERFACE"

    print_color "$GREEN" "Ad-hoc network active!"
    echo "  ESSID: $ADHOC_ESSID"
    echo "  Channel: $ADHOC_CHANNEL"
    echo "  IP: $NODE_IP"
    echo ""
    print_color "$YELLOW" "Other devices: Connect to '$ADHOC_ESSID' and set IP 192.168.50.X"
}

stop_adhoc() {
    print_color "$BLUE" "Stopping ad-hoc network..."

    iw dev "$WIFI_INTERFACE" ibss leave 2>/dev/null || true
    ip link set "$WIFI_INTERFACE" down
    iw dev "$WIFI_INTERFACE" set type managed 2>/dev/null || true
    ip link set "$WIFI_INTERFACE" up

    if command -v nmcli &>/dev/null; then
        nmcli device set "$WIFI_INTERFACE" managed yes 2>/dev/null || true
    fi

    print_color "$GREEN" "Stopped."
}

show_status() {
    print_color "$BLUE" "Ad-hoc Network Status:"
    iw dev "$WIFI_INTERFACE" info 2>/dev/null || echo "Not configured"
    echo ""
    ip addr show "$WIFI_INTERFACE"
}

case "${1:-start}" in
    start) check_root; start_adhoc ;;
    stop) check_root; stop_adhoc ;;
    status) show_status ;;
    *) echo "Usage: $0 [start|stop|status]" ;;
esac
