#!/bin/bash
#
# NWIPE SETUP SCRIPT
# Downloads and installs nwipe - the DBAN replacement
#
# nwipe is the open-source fork of DBAN's dwipe
# https://github.com/martijnvanbrummelen/nwipe
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"

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
        print_color "$RED" "This script should be run as root for installation."
        print_color "$YELLOW" "Trying with current user..."
    fi
}

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        DISTRO_LIKE=${ID_LIKE:-$ID}
    elif [ -f /etc/debian_version ]; then
        DISTRO="debian"
        DISTRO_LIKE="debian"
    elif [ -f /etc/redhat-release ]; then
        DISTRO="rhel"
        DISTRO_LIKE="rhel fedora"
    else
        DISTRO="unknown"
        DISTRO_LIKE="unknown"
    fi

    print_color "$BLUE" "Detected distribution: $DISTRO"
}

install_via_package_manager() {
    print_color "$BLUE" "Attempting to install nwipe via package manager..."

    case $DISTRO in
        ubuntu|debian|linuxmint|pop)
            apt-get update
            apt-get install -y nwipe
            ;;
        fedora)
            dnf install -y nwipe
            ;;
        centos|rhel|rocky|almalinux)
            # nwipe might be in EPEL
            yum install -y epel-release 2>/dev/null || true
            yum install -y nwipe
            ;;
        arch|manjaro)
            pacman -Sy --noconfirm nwipe
            ;;
        opensuse*|suse*)
            zypper install -y nwipe
            ;;
        alpine)
            apk add nwipe
            ;;
        *)
            print_color "$YELLOW" "Unknown distribution. Will try to build from source."
            return 1
            ;;
    esac

    return 0
}

install_build_deps() {
    print_color "$BLUE" "Installing build dependencies..."

    case $DISTRO in
        ubuntu|debian|linuxmint|pop)
            apt-get update
            apt-get install -y build-essential automake autoconf pkg-config \
                libncurses5-dev libparted-dev libconfig-dev \
                git
            ;;
        fedora)
            dnf install -y gcc make automake autoconf pkgconfig \
                ncurses-devel parted-devel libconfig-devel \
                git
            ;;
        centos|rhel|rocky|almalinux)
            yum install -y gcc make automake autoconf pkgconfig \
                ncurses-devel parted-devel libconfig-devel \
                git
            ;;
        arch|manjaro)
            pacman -Sy --noconfirm base-devel ncurses parted libconfig git
            ;;
        *)
            print_color "$RED" "Cannot install build dependencies for $DISTRO"
            return 1
            ;;
    esac
}

build_from_source() {
    print_color "$BLUE" "Building nwipe from source..."

    local build_dir="/tmp/nwipe-build-$$"
    mkdir -p "$build_dir"
    cd "$build_dir"

    # Clone the repository
    print_color "$BLUE" "Cloning nwipe repository..."
    git clone https://github.com/martijnvanbrummelen/nwipe.git
    cd nwipe

    # Build
    print_color "$BLUE" "Configuring..."
    ./autogen.sh
    ./configure --prefix=/usr/local

    print_color "$BLUE" "Building..."
    make -j"$(nproc)"

    print_color "$BLUE" "Installing..."
    make install

    # Cleanup
    cd /
    rm -rf "$build_dir"

    print_color "$GREEN" "nwipe built and installed successfully!"
}

download_static_binary() {
    print_color "$BLUE" "Attempting to download pre-built nwipe binary..."

    mkdir -p "$BIN_DIR"

    # Try to get the latest release
    local arch
    arch=$(uname -m)

    case $arch in
        x86_64)
            arch="amd64"
            ;;
        aarch64)
            arch="arm64"
            ;;
        armv7l)
            arch="armhf"
            ;;
    esac

    # Check if we can get a static build from GitHub releases
    local latest_url="https://api.github.com/repos/martijnvanbrummelen/nwipe/releases/latest"

    if command -v curl &> /dev/null; then
        print_color "$YELLOW" "Note: nwipe doesn't provide static binaries."
        print_color "$YELLOW" "Will need to install via package manager or build from source."
        return 1
    fi

    return 1
}

install_shred_alternative() {
    print_color "$BLUE" "Installing shred as an alternative..."

    # shred is part of coreutils, should already be installed
    if command -v shred &> /dev/null; then
        print_color "$GREEN" "shred is already available."
    else
        case $DISTRO in
            ubuntu|debian|linuxmint|pop)
                apt-get install -y coreutils
                ;;
            fedora|centos|rhel)
                yum install -y coreutils
                ;;
            arch|manjaro)
                pacman -Sy --noconfirm coreutils
                ;;
        esac
    fi
}

install_hdparm() {
    print_color "$BLUE" "Installing hdparm for ATA Secure Erase..."

    case $DISTRO in
        ubuntu|debian|linuxmint|pop)
            apt-get install -y hdparm
            ;;
        fedora)
            dnf install -y hdparm
            ;;
        centos|rhel|rocky|almalinux)
            yum install -y hdparm
            ;;
        arch|manjaro)
            pacman -Sy --noconfirm hdparm
            ;;
        opensuse*|suse*)
            zypper install -y hdparm
            ;;
        alpine)
            apk add hdparm
            ;;
    esac
}

create_wrapper_script() {
    print_color "$BLUE" "Creating nwipe wrapper script..."

    cat > "$BIN_DIR/nwipe-wrapper.sh" << 'WRAPPER'
#!/bin/bash
#
# nwipe wrapper script
# Provides a simple interface to nwipe
#

# Check if nwipe is available
if ! command -v nwipe &> /dev/null; then
    echo "ERROR: nwipe is not installed."
    echo "Please run setup-nwipe.sh first."
    exit 1
fi

# Default options for safe operation
# --autonuke: Start immediately without user intervention
# --nogui: Run without ncurses interface (for scripting)
# --method: Wipe method (dodshort, dod522022m, gutmann, ops2, random, zero)

show_help() {
    echo "nwipe-wrapper.sh - Simple interface to nwipe"
    echo ""
    echo "Usage: nwipe-wrapper.sh [OPTIONS] [DEVICE...]"
    echo ""
    echo "Methods:"
    echo "  -z, --zero       Quick zero fill (single pass)"
    echo "  -r, --random     Random fill (single pass)"
    echo "  -d, --dod        DoD 5220.22-M (3 pass)"
    echo "  -D, --dod7       DoD 5220.22-M ECE (7 pass)"
    echo "  -g, --gutmann    Gutmann method (35 pass)"
    echo ""
    echo "Options:"
    echo "  -i, --interactive  Run nwipe in interactive mode"
    echo "  -h, --help         Show this help"
    echo ""
    echo "Examples:"
    echo "  nwipe-wrapper.sh -z /dev/sda        # Zero fill /dev/sda"
    echo "  nwipe-wrapper.sh -d /dev/sdb        # DoD wipe /dev/sdb"
    echo "  nwipe-wrapper.sh -i                 # Interactive mode"
}

METHOD="zero"
INTERACTIVE=false
DEVICES=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -z|--zero)
            METHOD="zero"
            shift
            ;;
        -r|--random)
            METHOD="random"
            shift
            ;;
        -d|--dod)
            METHOD="dodshort"
            shift
            ;;
        -D|--dod7)
            METHOD="dod522022m"
            shift
            ;;
        -g|--gutmann)
            METHOD="gutmann"
            shift
            ;;
        -i|--interactive)
            INTERACTIVE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        /dev/*)
            DEVICES+=("$1")
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

if [[ "$INTERACTIVE" == "true" ]]; then
    exec nwipe
else
    if [[ ${#DEVICES[@]} -eq 0 ]]; then
        echo "ERROR: No devices specified."
        show_help
        exit 1
    fi

    echo "Starting nwipe with method: $METHOD"
    echo "Devices: ${DEVICES[*]}"
    echo ""
    echo "WARNING: This will PERMANENTLY DESTROY all data!"
    echo "Press Ctrl+C within 5 seconds to cancel..."
    sleep 5

    exec nwipe --autonuke --method="$METHOD" "${DEVICES[@]}"
fi
WRAPPER

    chmod +x "$BIN_DIR/nwipe-wrapper.sh"
}

main() {
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║               NWIPE SETUP SCRIPT                               ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    check_root
    detect_distro

    # Try package manager first
    if install_via_package_manager 2>/dev/null; then
        print_color "$GREEN" "nwipe installed successfully via package manager!"
    else
        print_color "$YELLOW" "Package manager installation failed. Trying to build from source..."

        if install_build_deps 2>/dev/null; then
            if build_from_source 2>/dev/null; then
                print_color "$GREEN" "nwipe built and installed successfully!"
            else
                print_color "$RED" "Failed to build nwipe from source."
                print_color "$YELLOW" "The disk wipe utility will use dd and shred as fallbacks."
            fi
        else
            print_color "$RED" "Failed to install build dependencies."
            print_color "$YELLOW" "The disk wipe utility will use dd and shred as fallbacks."
        fi
    fi

    # Install additional tools
    install_shred_alternative 2>/dev/null || true
    install_hdparm 2>/dev/null || true

    # Create wrapper script
    create_wrapper_script

    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                  SETUP COMPLETE                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    print_color "$WHITE" "Tool availability:"

    for tool in nwipe shred hdparm dd; do
        if command -v "$tool" &> /dev/null; then
            print_color "$GREEN" "  ✓ $tool"
        else
            print_color "$RED" "  ✗ $tool"
        fi
    done

    echo ""
    print_color "$WHITE" "Run './wipe-disk.sh' to start the disk wipe utility."
}

main "$@"
