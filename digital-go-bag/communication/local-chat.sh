#!/bin/bash
#
# LOCAL NETWORK CHAT
# Simple text chat over local network (mesh, ad-hoc, LAN)
# No internet required - works peer-to-peer
#

set -euo pipefail

CHAT_PORT=9876
NICK="${USER:-anon}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

get_local_ip() {
    ip -4 addr show | grep -oP '(?<=inet\s)(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)\d+\.\d+' | head -1 || \
    hostname -I | awk '{print $1}'
}

get_broadcast() {
    local ip
    ip=$(get_local_ip)
    echo "${ip%.*}.255"
}

start_server() {
    local ip
    ip=$(get_local_ip)

    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    LOCAL CHAT SERVER                           ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}Listening on $ip:$CHAT_PORT${NC}"
    echo -e "${WHITE}Nick: $NICK${NC}"
    echo -e "${YELLOW}Others can connect with: $0 connect $ip${NC}"
    echo ""
    echo -e "${YELLOW}Type messages and press Enter. Ctrl+C to quit.${NC}"
    echo ""

    # Start receiver in background
    nc -luk $CHAT_PORT | while read -r line; do
        echo -e "${GREEN}$line${NC}"
    done &
    local recv_pid=$!

    # Send messages
    trap "kill $recv_pid 2>/dev/null; exit" INT TERM

    while read -r msg; do
        if [[ -n "$msg" ]]; then
            echo "[$NICK] $msg" | nc -u -b "$(get_broadcast)" $CHAT_PORT 2>/dev/null || true
        fi
    done

    kill $recv_pid 2>/dev/null
}

connect_to() {
    local target="${1:-$(get_broadcast)}"

    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    LOCAL CHAT CLIENT                           ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}Connected to: $target:$CHAT_PORT${NC}"
    echo -e "${WHITE}Nick: $NICK${NC}"
    echo ""
    echo -e "${YELLOW}Type messages and press Enter. Ctrl+C to quit.${NC}"
    echo ""

    # Start receiver
    nc -luk $CHAT_PORT | while read -r line; do
        echo -e "${GREEN}$line${NC}"
    done &
    local recv_pid=$!

    trap "kill $recv_pid 2>/dev/null; exit" INT TERM

    while read -r msg; do
        if [[ -n "$msg" ]]; then
            echo "[$NICK] $msg" | nc -u "$target" $CHAT_PORT 2>/dev/null || \
            echo "[$NICK] $msg" | nc -u -b "$(get_broadcast)" $CHAT_PORT 2>/dev/null || true
        fi
    done

    kill $recv_pid 2>/dev/null
}

broadcast_message() {
    local msg="$*"
    local bc
    bc=$(get_broadcast)

    echo "[$NICK] $msg" | nc -u -b "$bc" $CHAT_PORT
    echo "Message broadcast to $bc:$CHAT_PORT"
}

show_help() {
    echo "Local Network Chat"
    echo ""
    echo "Usage: $0 [command] [args]"
    echo ""
    echo "Commands:"
    echo "  server              - Start chat server (listens for messages)"
    echo "  connect [ip]        - Connect to chat (default: broadcast)"
    echo "  send <message>      - Send single message and exit"
    echo ""
    echo "Environment:"
    echo "  NICK=yourname $0 server   - Set your nickname"
    echo ""
    echo "Examples:"
    echo "  NICK=alice $0 server"
    echo "  NICK=bob $0 connect 10.99.0.1"
    echo "  $0 send \"Hello everyone!\""
}

case "${1:-help}" in
    server|start)
        start_server
        ;;
    connect|join)
        connect_to "${2:-}"
        ;;
    send|msg)
        shift
        broadcast_message "$@"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
