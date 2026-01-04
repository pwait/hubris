#!/bin/bash
#
# MESH FILE SHARING
# Simple file sharing over local mesh/ad-hoc networks
#
# Uses netcat for transfers - works without any internet
# Includes a simple discovery mechanism
#

set -euo pipefail

SHARE_PORT=9999
DISCOVERY_PORT=9998
SHARE_DIR="${HOME}/mesh-share"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_color() {
    echo -e "${1}${2}${NC}"
}

ensure_share_dir() {
    mkdir -p "$SHARE_DIR"
}

get_local_ip() {
    # Get IP from mesh interface (bat0) or any available
    ip -4 addr show bat0 2>/dev/null | grep -oP '(?<=inet\s)\d+\.\d+\.\d+\.\d+' | head -1 || \
    ip -4 addr show | grep -oP '(?<=inet\s)10\.\d+\.\d+\.\d+' | head -1 || \
    ip -4 addr show | grep -oP '(?<=inet\s)192\.168\.\d+\.\d+' | head -1 || \
    hostname -I | awk '{print $1}'
}

announce_presence() {
    local ip
    ip=$(get_local_ip)
    local hostname
    hostname=$(hostname)

    print_color "$BLUE" "Announcing presence on network..."

    while true; do
        # Broadcast announcement
        echo "MESHNODE:$hostname:$ip:$SHARE_PORT" | \
            socat - UDP-DATAGRAM:255.255.255.255:$DISCOVERY_PORT,broadcast 2>/dev/null || \
            echo "MESHNODE:$hostname:$ip:$SHARE_PORT" | nc -u -b 255.255.255.255 $DISCOVERY_PORT 2>/dev/null || true
        sleep 30
    done
}

discover_nodes() {
    print_color "$BLUE" "Discovering nodes on mesh network..."
    print_color "$YELLOW" "(Listening for 10 seconds)"
    echo ""

    local nodes_file="/tmp/mesh_nodes_$$"
    > "$nodes_file"

    # Listen for announcements
    timeout 10 socat -u UDP-RECV:$DISCOVERY_PORT - 2>/dev/null | while read -r line; do
        if [[ "$line" == MESHNODE:* ]]; then
            echo "$line" >> "$nodes_file"
            local parts
            IFS=':' read -ra parts <<< "$line"
            print_color "$GREEN" "Found: ${parts[1]} at ${parts[2]}:${parts[3]}"
        fi
    done || true

    echo ""
    if [[ -s "$nodes_file" ]]; then
        print_color "$WHITE" "Discovered nodes:"
        sort -u "$nodes_file" | while read -r line; do
            IFS=':' read -ra parts <<< "$line"
            echo "  ${parts[1]} - ${parts[2]}:${parts[3]}"
        done
    else
        print_color "$YELLOW" "No nodes discovered. They may not be announcing."
        print_color "$WHITE" "You can still connect directly if you know the IP."
    fi

    rm -f "$nodes_file"
}

send_file() {
    local target_ip="$1"
    local filepath="$2"

    if [[ ! -f "$filepath" ]]; then
        print_color "$RED" "File not found: $filepath"
        exit 1
    fi

    local filename
    filename=$(basename "$filepath")
    local filesize
    filesize=$(stat -c%s "$filepath")

    print_color "$BLUE" "Sending: $filename ($filesize bytes) to $target_ip:$SHARE_PORT"

    # Send header first (filename and size)
    echo "FILE:$filename:$filesize" | nc -w 2 "$target_ip" $SHARE_PORT

    sleep 1

    # Send file content
    nc -w 30 "$target_ip" $SHARE_PORT < "$filepath"

    print_color "$GREEN" "File sent!"
}

receive_files() {
    ensure_share_dir

    local ip
    ip=$(get_local_ip)

    print_color "$CYAN" "╔════════════════════════════════════════════════════════════════╗"
    print_color "$CYAN" "║                 MESH FILE RECEIVER                             ║"
    print_color "$CYAN" "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    print_color "$WHITE" "Listening on $ip:$SHARE_PORT"
    print_color "$WHITE" "Files will be saved to: $SHARE_DIR"
    print_color "$YELLOW" "Press Ctrl+C to stop"
    echo ""

    while true; do
        # Wait for connection and receive header
        local header
        header=$(nc -l -p $SHARE_PORT -w 60 | head -1) || continue

        if [[ "$header" == FILE:* ]]; then
            IFS=':' read -ra parts <<< "$header"
            local filename="${parts[1]}"
            local filesize="${parts[2]}"

            print_color "$BLUE" "Receiving: $filename ($filesize bytes)"

            # Receive file content
            nc -l -p $SHARE_PORT -w 60 > "$SHARE_DIR/$filename"

            local received_size
            received_size=$(stat -c%s "$SHARE_DIR/$filename" 2>/dev/null || echo 0)

            if [[ "$received_size" -gt 0 ]]; then
                print_color "$GREEN" "Received: $SHARE_DIR/$filename ($received_size bytes)"
            else
                print_color "$RED" "Failed to receive file"
            fi
        fi
    done
}

start_web_share() {
    ensure_share_dir

    local ip
    ip=$(get_local_ip)
    local port="${1:-8080}"

    print_color "$CYAN" "Starting simple HTTP file server..."
    print_color "$WHITE" "Sharing: $SHARE_DIR"
    print_color "$WHITE" "URL: http://$ip:$port"
    echo ""
    print_color "$YELLOW" "Press Ctrl+C to stop"

    cd "$SHARE_DIR"

    # Try Python 3, then Python 2, then busybox httpd
    if command -v python3 &>/dev/null; then
        python3 -m http.server "$port"
    elif command -v python &>/dev/null; then
        python -m SimpleHTTPServer "$port"
    elif command -v busybox &>/dev/null; then
        busybox httpd -f -p "$port"
    else
        print_color "$RED" "No HTTP server available"
        print_color "$YELLOW" "Install python3 or use nc-based transfer"
        exit 1
    fi
}

show_help() {
    echo "Mesh File Sharing"
    echo ""
    echo "Usage: $0 [command] [args]"
    echo ""
    echo "Commands:"
    echo "  discover          - Find other nodes on the mesh"
    echo "  receive           - Start receiving files"
    echo "  send <ip> <file>  - Send a file to another node"
    echo "  web [port]        - Start HTTP file server (default: 8080)"
    echo "  announce          - Announce presence (run in background)"
    echo ""
    echo "Examples:"
    echo "  $0 discover"
    echo "  $0 receive"
    echo "  $0 send 10.99.0.2 myfile.txt"
    echo "  $0 web 8000"
}

case "${1:-help}" in
    discover)
        discover_nodes
        ;;
    receive)
        receive_files
        ;;
    send)
        if [[ $# -lt 3 ]]; then
            print_color "$RED" "Usage: $0 send <ip> <file>"
            exit 1
        fi
        send_file "$2" "$3"
        ;;
    web)
        start_web_share "${2:-8080}"
        ;;
    announce)
        announce_presence &
        print_color "$GREEN" "Announcing in background (PID: $!)"
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
