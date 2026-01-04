#!/bin/bash
#
# FILE ENCRYPTION UTILITY
# Encrypt/decrypt files using standard tools (GPG, OpenSSL)
# No internet required - works completely offline
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

check_tools() {
    if command -v gpg &>/dev/null; then
        GPG_AVAILABLE=true
    else
        GPG_AVAILABLE=false
    fi

    if command -v openssl &>/dev/null; then
        OPENSSL_AVAILABLE=true
    else
        OPENSSL_AVAILABLE=false
    fi

    if [[ "$GPG_AVAILABLE" != "true" && "$OPENSSL_AVAILABLE" != "true" ]]; then
        print_color "$RED" "Neither GPG nor OpenSSL found!"
        print_color "$YELLOW" "Install with: sudo apt install gnupg openssl"
        exit 1
    fi
}

# GPG symmetric encryption (password-based)
encrypt_gpg() {
    local input="$1"
    local output="${2:-${input}.gpg}"

    print_color "$BLUE" "Encrypting with GPG..."
    gpg --symmetric --cipher-algo AES256 -o "$output" "$input"
    print_color "$GREEN" "Encrypted: $output"
}

decrypt_gpg() {
    local input="$1"
    local output="${2:-${input%.gpg}}"

    if [[ "$output" == "$input" ]]; then
        output="${input}.decrypted"
    fi

    print_color "$BLUE" "Decrypting with GPG..."
    gpg -d -o "$output" "$input"
    print_color "$GREEN" "Decrypted: $output"
}

# OpenSSL encryption
encrypt_openssl() {
    local input="$1"
    local output="${2:-${input}.enc}"

    print_color "$BLUE" "Encrypting with OpenSSL (AES-256-CBC)..."
    openssl enc -aes-256-cbc -salt -pbkdf2 -in "$input" -out "$output"
    print_color "$GREEN" "Encrypted: $output"
}

decrypt_openssl() {
    local input="$1"
    local output="${2:-${input%.enc}}"

    if [[ "$output" == "$input" ]]; then
        output="${input}.decrypted"
    fi

    print_color "$BLUE" "Decrypting with OpenSSL..."
    openssl enc -aes-256-cbc -d -pbkdf2 -in "$input" -out "$output"
    print_color "$GREEN" "Decrypted: $output"
}

# Encrypt a directory (create encrypted archive)
encrypt_directory() {
    local dir="$1"
    local output="${2:-${dir}.tar.gpg}"

    if [[ ! -d "$dir" ]]; then
        print_color "$RED" "Directory not found: $dir"
        exit 1
    fi

    print_color "$BLUE" "Creating encrypted archive of: $dir"

    tar -cf - "$dir" | gpg --symmetric --cipher-algo AES256 -o "$output"

    print_color "$GREEN" "Encrypted archive: $output"
}

decrypt_directory() {
    local input="$1"
    local output_dir="${2:-.}"

    print_color "$BLUE" "Decrypting and extracting archive..."

    gpg -d "$input" | tar -xf - -C "$output_dir"

    print_color "$GREEN" "Extracted to: $output_dir"
}

# Secure file deletion
secure_delete() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        print_color "$RED" "File not found: $file"
        exit 1
    fi

    print_color "$YELLOW" "Securely deleting: $file"
    print_color "$RED" "This cannot be undone! Continue? [y/N]: "
    read -r confirm

    if [[ ! "$confirm" =~ ^[Yy] ]]; then
        print_color "$GREEN" "Cancelled."
        return
    fi

    if command -v shred &>/dev/null; then
        shred -vfz -n 3 "$file"
        rm -f "$file"
    else
        # Fallback: overwrite with random data
        local size
        size=$(stat -c%s "$file")
        dd if=/dev/urandom of="$file" bs=1 count="$size" conv=notrunc 2>/dev/null
        dd if=/dev/zero of="$file" bs=1 count="$size" conv=notrunc 2>/dev/null
        rm -f "$file"
    fi

    print_color "$GREEN" "Securely deleted: $file"
}

# Generate a strong random password
generate_password() {
    local length="${1:-32}"

    print_color "$CYAN" "Generated passwords:"
    echo ""

    # Method 1: /dev/urandom
    echo -n "Alphanumeric ($length chars): "
    tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length"
    echo ""

    # Method 2: Full printable
    echo -n "With symbols ($length chars):  "
    tr -dc 'A-Za-z0-9!@#$%^&*()_+-=' < /dev/urandom | head -c "$length"
    echo ""

    # Method 3: Passphrase (word-based)
    if [[ -f /usr/share/dict/words ]]; then
        echo -n "Passphrase (6 words):          "
        shuf -n 6 /usr/share/dict/words | tr '\n' '-' | sed 's/-$//'
        echo ""
    fi

    echo ""
}

# Create encrypted container (like VeraCrypt)
create_container() {
    local container="$1"
    local size_mb="${2:-100}"

    print_color "$BLUE" "Creating encrypted container: $container (${size_mb}MB)"

    # Create empty file
    dd if=/dev/zero of="$container" bs=1M count="$size_mb" 2>/dev/null

    # Setup LUKS encryption
    if command -v cryptsetup &>/dev/null; then
        print_color "$YELLOW" "Setting up LUKS encryption..."
        sudo cryptsetup luksFormat "$container"

        print_color "$BLUE" "Container created. To use:"
        echo "  1. Open: sudo cryptsetup open $container mycontainer"
        echo "  2. Format: sudo mkfs.ext4 /dev/mapper/mycontainer"
        echo "  3. Mount: sudo mount /dev/mapper/mycontainer /mnt"
        echo "  4. Close: sudo cryptsetup close mycontainer"
    else
        print_color "$YELLOW" "cryptsetup not available. Using GPG encryption instead."
        rm "$container"
        print_color "$WHITE" "Use 'encrypt-dir' to create encrypted archives."
    fi
}

show_help() {
    echo "File Encryption Utility"
    echo ""
    echo "Usage: $0 [command] [args]"
    echo ""
    echo "Commands:"
    echo "  encrypt <file> [output]     - Encrypt a file"
    echo "  decrypt <file> [output]     - Decrypt a file"
    echo "  encrypt-dir <dir> [output]  - Encrypt a directory"
    echo "  decrypt-dir <file> [dir]    - Decrypt directory archive"
    echo "  delete <file>               - Securely delete a file"
    echo "  password [length]           - Generate strong password"
    echo "  container <file> <size_mb>  - Create encrypted container"
    echo ""
    echo "Examples:"
    echo "  $0 encrypt secret.txt"
    echo "  $0 decrypt secret.txt.gpg"
    echo "  $0 encrypt-dir documents/"
    echo "  $0 password 24"
    echo "  $0 delete old-secret.txt"
    echo ""
    echo "Notes:"
    echo "  - Uses GPG with AES-256 (falls back to OpenSSL)"
    echo "  - Passwords are never stored"
    echo "  - Works completely offline"
}

# Main
check_tools

case "${1:-help}" in
    encrypt)
        [[ $# -lt 2 ]] && { echo "Usage: $0 encrypt <file>"; exit 1; }
        if [[ "$GPG_AVAILABLE" == "true" ]]; then
            encrypt_gpg "$2" "${3:-}"
        else
            encrypt_openssl "$2" "${3:-}"
        fi
        ;;
    decrypt)
        [[ $# -lt 2 ]] && { echo "Usage: $0 decrypt <file>"; exit 1; }
        if [[ "$2" == *.gpg ]]; then
            decrypt_gpg "$2" "${3:-}"
        elif [[ "$2" == *.enc ]]; then
            decrypt_openssl "$2" "${3:-}"
        else
            # Try GPG first
            decrypt_gpg "$2" "${3:-}" 2>/dev/null || decrypt_openssl "$2" "${3:-}"
        fi
        ;;
    encrypt-dir)
        [[ $# -lt 2 ]] && { echo "Usage: $0 encrypt-dir <dir>"; exit 1; }
        encrypt_directory "$2" "${3:-}"
        ;;
    decrypt-dir)
        [[ $# -lt 2 ]] && { echo "Usage: $0 decrypt-dir <file>"; exit 1; }
        decrypt_directory "$2" "${3:-.}"
        ;;
    delete|shred)
        [[ $# -lt 2 ]] && { echo "Usage: $0 delete <file>"; exit 1; }
        secure_delete "$2"
        ;;
    password|passwd|pw)
        generate_password "${2:-32}"
        ;;
    container)
        [[ $# -lt 2 ]] && { echo "Usage: $0 container <file> [size_mb]"; exit 1; }
        create_container "$2" "${3:-100}"
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
