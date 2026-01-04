#!/bin/bash
#
# KIWIX OFFLINE WIKIPEDIA & KNOWLEDGE SETUP
# Download and serve Wikipedia and other knowledge bases offline
#
# Kiwix allows you to access Wikipedia, Wikibooks, medical guides, etc.
# without any internet connection.
#
# Storage requirements:
#   - Wikipedia (English, no images): ~10GB
#   - Wikipedia (English, with images): ~90GB
#   - Medical guides: ~500MB-2GB
#   - Wikibooks: ~1GB
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIWIX_DIR="${HOME}/kiwix"
ZIM_DIR="${KIWIX_DIR}/zim"

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

install_kiwix() {
    print_color "$CYAN" "╔════════════════════════════════════════════════════════════════╗"
    print_color "$CYAN" "║                 KIWIX INSTALLATION                             ║"
    print_color "$CYAN" "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    mkdir -p "$KIWIX_DIR" "$ZIM_DIR"

    # Detect architecture
    local arch
    arch=$(uname -m)
    case $arch in
        x86_64) arch="x86_64" ;;
        aarch64) arch="aarch64" ;;
        armv7l) arch="armhf" ;;
        *) print_color "$RED" "Unsupported architecture: $arch"; exit 1 ;;
    esac

    print_color "$BLUE" "Downloading Kiwix tools for $arch..."

    # Download kiwix-tools (includes kiwix-serve)
    local version="3.5.0"
    local url="https://download.kiwix.org/release/kiwix-tools/kiwix-tools_linux-${arch}-${version}.tar.gz"

    cd "$KIWIX_DIR"
    wget -q --show-progress "$url" -O kiwix-tools.tar.gz
    tar -xzf kiwix-tools.tar.gz
    rm kiwix-tools.tar.gz

    # Move binaries
    mv kiwix-tools_linux-*/* . 2>/dev/null || true
    rmdir kiwix-tools_linux-* 2>/dev/null || true

    print_color "$GREEN" "Kiwix installed to: $KIWIX_DIR"
    echo ""
    print_color "$WHITE" "Available tools:"
    echo "  kiwix-serve - Serve ZIM files via web browser"
    echo "  kiwix-search - Search ZIM content"
    echo "  kiwix-manage - Manage ZIM library"
}

show_available_content() {
    print_color "$CYAN" "╔════════════════════════════════════════════════════════════════╗"
    print_color "$CYAN" "║              AVAILABLE OFFLINE CONTENT                         ║"
    print_color "$CYAN" "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    print_color "$WHITE" "Essential Knowledge (Recommended for survival):"
    echo ""
    print_color "$GREEN" "[1] Wikipedia - Simple English (~1.5GB)"
    echo "    Simplified articles, easier to store"
    echo ""
    print_color "$GREEN" "[2] Wikipedia - English, No Images (~10GB)"
    echo "    Full articles without pictures"
    echo ""
    print_color "$GREEN" "[3] Wikipedia - English, Full (~90GB)"
    echo "    Complete with all images"
    echo ""
    print_color "$GREEN" "[4] WikiMed Medical Encyclopedia (~700MB)"
    echo "    Medical knowledge for emergencies"
    echo ""
    print_color "$GREEN" "[5] Wikibooks (~1GB)"
    echo "    How-to guides and textbooks"
    echo ""
    print_color "$GREEN" "[6] Wikivoyage (~700MB)"
    echo "    Travel and geography"
    echo ""
    print_color "$GREEN" "[7] iFixit Repair Guides (~3GB)"
    echo "    Device and equipment repair"
    echo ""
    print_color "$GREEN" "[8] Stack Overflow (~50GB)"
    echo "    Programming knowledge"
    echo ""
    print_color "$GREEN" "[9] Project Gutenberg Books (~60GB)"
    echo "    Free ebooks library"
    echo ""
    print_color "$GREEN" "[10] TED Talks (~25GB)"
    echo "    Educational videos"
    echo ""
}

download_content() {
    local choice="$1"

    mkdir -p "$ZIM_DIR"
    cd "$ZIM_DIR"

    # Base URL for ZIM downloads
    local base_url="https://download.kiwix.org/zim"
    local url=""
    local filename=""

    case $choice in
        1)
            print_color "$BLUE" "Downloading Simple English Wikipedia..."
            url="${base_url}/wikipedia_en_simple_all_nopic_latest.zim"
            filename="wikipedia_simple.zim"
            ;;
        2)
            print_color "$BLUE" "Downloading English Wikipedia (no images)..."
            url="${base_url}/wikipedia_en_all_nopic_latest.zim"
            filename="wikipedia_en_nopic.zim"
            ;;
        3)
            print_color "$BLUE" "Downloading English Wikipedia (full)..."
            print_color "$YELLOW" "WARNING: This is ~90GB and will take a long time!"
            url="${base_url}/wikipedia_en_all_maxi_latest.zim"
            filename="wikipedia_en_full.zim"
            ;;
        4)
            print_color "$BLUE" "Downloading WikiMed Medical Encyclopedia..."
            url="${base_url}/wikipedia_en_medicine_nopic_latest.zim"
            filename="wikimed.zim"
            ;;
        5)
            print_color "$BLUE" "Downloading Wikibooks..."
            url="${base_url}/wikibooks_en_all_nopic_latest.zim"
            filename="wikibooks.zim"
            ;;
        6)
            print_color "$BLUE" "Downloading Wikivoyage..."
            url="${base_url}/wikivoyage_en_all_nopic_latest.zim"
            filename="wikivoyage.zim"
            ;;
        7)
            print_color "$BLUE" "Downloading iFixit..."
            url="${base_url}/ifixit_en_all_latest.zim"
            filename="ifixit.zim"
            ;;
        8)
            print_color "$BLUE" "Downloading Stack Overflow..."
            print_color "$YELLOW" "WARNING: This is ~50GB!"
            url="${base_url}/stackoverflow.com_en_all_latest.zim"
            filename="stackoverflow.zim"
            ;;
        9)
            print_color "$BLUE" "Downloading Project Gutenberg..."
            url="${base_url}/gutenberg_en_all_latest.zim"
            filename="gutenberg.zim"
            ;;
        10)
            print_color "$BLUE" "Downloading TED Talks..."
            print_color "$YELLOW" "WARNING: This is ~25GB!"
            url="${base_url}/ted_en_all_latest.zim"
            filename="ted.zim"
            ;;
        *)
            print_color "$RED" "Invalid choice"
            return 1
            ;;
    esac

    # Download with resume support
    wget -c --show-progress "$url" -O "$filename"

    print_color "$GREEN" "Downloaded: $ZIM_DIR/$filename"
}

start_server() {
    local port="${1:-8888}"

    if [[ ! -d "$KIWIX_DIR" ]] || [[ ! -f "$KIWIX_DIR/kiwix-serve" ]]; then
        print_color "$RED" "Kiwix not installed. Run: $0 install"
        exit 1
    fi

    # Find all ZIM files
    local zim_files=()
    while IFS= read -r -d '' file; do
        zim_files+=("$file")
    done < <(find "$ZIM_DIR" -name "*.zim" -print0 2>/dev/null)

    if [[ ${#zim_files[@]} -eq 0 ]]; then
        print_color "$RED" "No ZIM files found in $ZIM_DIR"
        print_color "$YELLOW" "Run: $0 download"
        exit 1
    fi

    local ip
    ip=$(hostname -I | awk '{print $1}')

    print_color "$CYAN" "╔════════════════════════════════════════════════════════════════╗"
    print_color "$CYAN" "║                 KIWIX SERVER STARTING                          ║"
    print_color "$CYAN" "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    print_color "$WHITE" "Serving ${#zim_files[@]} ZIM file(s)"
    print_color "$WHITE" "Access at: http://${ip}:${port}"
    print_color "$WHITE" "Or locally: http://localhost:${port}"
    echo ""
    print_color "$YELLOW" "Press Ctrl+C to stop"
    echo ""

    "$KIWIX_DIR/kiwix-serve" --port "$port" "${zim_files[@]}"
}

list_content() {
    print_color "$WHITE" "Downloaded content in $ZIM_DIR:"
    echo ""

    if [[ -d "$ZIM_DIR" ]]; then
        local total=0
        while IFS= read -r file; do
            local size
            size=$(du -h "$file" | cut -f1)
            local name
            name=$(basename "$file")
            echo "  $name ($size)"
            ((total++))
        done < <(find "$ZIM_DIR" -name "*.zim" 2>/dev/null)

        if [[ $total -eq 0 ]]; then
            print_color "$YELLOW" "No ZIM files downloaded yet."
            echo "  Run: $0 download"
        fi
    else
        print_color "$YELLOW" "Kiwix directory not found."
    fi
}

download_essential() {
    print_color "$BLUE" "Downloading essential survival knowledge..."

    # Download key resources
    download_content 1  # Simple English Wikipedia
    download_content 4  # WikiMed Medical
    download_content 5  # Wikibooks

    print_color "$GREEN" "Essential content downloaded!"
}

show_help() {
    echo "Kiwix Offline Knowledge Setup"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  install     - Install Kiwix tools"
    echo "  download    - Interactive content download"
    echo "  essential   - Download essential survival content"
    echo "  serve       - Start web server (access via browser)"
    echo "  list        - List downloaded content"
    echo "  help        - Show this help"
    echo ""
    echo "Quick Start:"
    echo "  1. $0 install"
    echo "  2. $0 essential  (or $0 download for custom)"
    echo "  3. $0 serve"
    echo "  4. Open http://localhost:8888 in browser"
}

interactive_download() {
    show_available_content
    print_color "$WHITE" "Enter numbers to download (comma-separated, or 'q' to quit): "
    read -r choices

    if [[ "$choices" == "q" ]]; then
        return
    fi

    IFS=',' read -ra nums <<< "$choices"
    for num in "${nums[@]}"; do
        num=$(echo "$num" | tr -d ' ')
        download_content "$num" || true
    done
}

# Main
case "${1:-help}" in
    install)
        install_kiwix
        ;;
    download)
        interactive_download
        ;;
    essential)
        download_essential
        ;;
    serve|start)
        start_server "${2:-8888}"
        ;;
    list)
        list_content
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
