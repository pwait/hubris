#!/bin/bash
#
# OFFLINE DOCUMENTATION DOWNLOADER
# Downloads technical documentation for offline use
#
# Downloads manuals, guides, and references that will be useful
# when internet is not available.
#

set -euo pipefail

DOCS_DIR="${HOME}/offline-docs"

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

check_deps() {
    local missing=()
    for cmd in wget curl; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_color "$RED" "Missing: ${missing[*]}"
        exit 1
    fi
}

show_menu() {
    print_color "$CYAN" "╔════════════════════════════════════════════════════════════════╗"
    print_color "$CYAN" "║           OFFLINE DOCUMENTATION DOWNLOADER                     ║"
    print_color "$CYAN" "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    print_color "$WHITE" "Available Documentation:"
    echo ""
    print_color "$GREEN" "=== Survival & Practical ==="
    echo "  [1]  US Army Survival Manual FM 21-76"
    echo "  [2]  Where There Is No Doctor (Medical Guide)"
    echo "  [3]  Where There Is No Dentist"
    echo "  [4]  FEMA Emergency Preparedness Guides"
    echo ""
    print_color "$GREEN" "=== Technical References ==="
    echo "  [10] Linux Man Pages (complete)"
    echo "  [11] Arch Wiki (offline)"
    echo "  [12] Git Documentation"
    echo "  [13] Python Documentation"
    echo "  [14] Bash Reference Manual"
    echo ""
    print_color "$GREEN" "=== Electronics & Repair ==="
    echo "  [20] Electronics Basics PDF Collection"
    echo "  [21] Arduino Documentation"
    echo "  [22] Raspberry Pi Documentation"
    echo ""
    print_color "$GREEN" "=== Radio Communications ==="
    echo "  [30] ARRL Ham Radio Handbook (requires purchase)"
    echo "  [31] Emergency Radio Frequencies Guide"
    echo ""
    print_color "$GREEN" "=== Bundles ==="
    echo "  [90] Essential Survival Bundle (1-4)"
    echo "  [91] Linux Admin Bundle (10-14)"
    echo "  [92] Maker/Electronics Bundle (20-22)"
    echo ""
    echo "  [99] Download ALL"
    echo ""
}

download_file() {
    local url="$1"
    local output="$2"
    local description="$3"

    mkdir -p "$(dirname "$output")"

    print_color "$BLUE" "Downloading: $description"

    if wget -q --show-progress -O "$output" "$url" 2>/dev/null; then
        print_color "$GREEN" "  Saved: $output"
        return 0
    else
        print_color "$RED" "  Failed: $url"
        return 1
    fi
}

download_survival_manual() {
    local dir="$DOCS_DIR/survival"
    mkdir -p "$dir"

    print_color "$BLUE" "Downloading US Army Survival Manual..."

    # FM 21-76 is public domain
    local url="https://www.survivalschool.us/wp-content/uploads/2019/09/FM-21-76-US-ARMY-SURVIVAL-MANUAL.pdf"
    wget -q --show-progress -O "$dir/FM-21-76-Survival-Manual.pdf" "$url" 2>/dev/null || \
        print_color "$YELLOW" "Primary source unavailable, try archive.org"

    print_color "$GREEN" "Done: $dir"
}

download_where_no_doctor() {
    local dir="$DOCS_DIR/medical"
    mkdir -p "$dir"

    print_color "$BLUE" "Downloading 'Where There Is No Doctor'..."

    # Hesperian Health Guides offers free downloads
    cat > "$dir/README.txt" << 'EOF'
Where There Is No Doctor
========================

This essential medical guide is available free from Hesperian:
https://hesperian.org/books-and-resources/

Download directly:
https://hesperian.org/wp-content/uploads/pdf/en_wtnd_2017/en_wtnd_2017_full.pdf

The book covers:
- Sicknesses and treatments
- Prevention and health education
- Medicines and their use
- First aid
- Maternal and child health
- Nutrition

Hesperian offers versions in many languages.
EOF

    # Attempt download
    wget -q --show-progress -O "$dir/Where-There-Is-No-Doctor.pdf" \
        "https://hesperian.org/wp-content/uploads/pdf/en_wtnd_2017/en_wtnd_2017_full.pdf" 2>/dev/null || \
        print_color "$YELLOW" "Download from: https://hesperian.org/books-and-resources/"

    print_color "$GREEN" "Done: $dir"
}

download_where_no_dentist() {
    local dir="$DOCS_DIR/medical"
    mkdir -p "$dir"

    print_color "$BLUE" "Downloading 'Where There Is No Dentist'..."

    wget -q --show-progress -O "$dir/Where-There-Is-No-Dentist.pdf" \
        "https://hesperian.org/wp-content/uploads/pdf/en_wtnd_dental_2017.pdf" 2>/dev/null || \
        print_color "$YELLOW" "Download from: https://hesperian.org/books-and-resources/"

    print_color "$GREEN" "Done: $dir"
}

download_fema_guides() {
    local dir="$DOCS_DIR/emergency"
    mkdir -p "$dir"

    print_color "$BLUE" "Downloading FEMA emergency guides..."

    # ARE YOU READY? - FEMA guide
    wget -q --show-progress -O "$dir/FEMA-Are-You-Ready.pdf" \
        "https://www.fema.gov/pdf/areyouready/areyouready_full.pdf" 2>/dev/null || true

    # Create info file
    cat > "$dir/FEMA-Resources.txt" << 'EOF'
FEMA Emergency Preparedness Resources
=====================================

Ready.gov Publications:
https://www.ready.gov/publications

Key Guides:
- Are You Ready? - Comprehensive preparedness guide
- Community Emergency Response Team (CERT) Manual
- Emergency Financial First Aid Kit
- Pet Preparedness

All available free from FEMA at ready.gov
EOF

    print_color "$GREEN" "Done: $dir"
}

download_linux_docs() {
    local dir="$DOCS_DIR/linux"
    mkdir -p "$dir"

    print_color "$BLUE" "Downloading Linux documentation..."

    # Man pages - create a script to dump them
    cat > "$dir/dump-man-pages.sh" << 'SCRIPT'
#!/bin/bash
# Run this to create offline man page archive
mkdir -p man-pages
for section in 1 2 3 4 5 6 7 8; do
    for cmd in $(man -k . 2>/dev/null | grep "($section)" | awk '{print $1}' | head -100); do
        man "$cmd" 2>/dev/null | col -b > "man-pages/${cmd}.${section}.txt" 2>/dev/null || true
    done
done
tar -czf man-pages.tar.gz man-pages/
rm -rf man-pages/
echo "Created: man-pages.tar.gz"
SCRIPT
    chmod +x "$dir/dump-man-pages.sh"

    # Bash reference
    wget -q --show-progress -O "$dir/bash-reference.html" \
        "https://www.gnu.org/software/bash/manual/bash.html" 2>/dev/null || true

    # Common commands cheatsheet
    cat > "$dir/linux-cheatsheet.md" << 'EOF'
# Linux Command Cheatsheet

## File Operations
```
ls -la          # List all files with details
cp src dst      # Copy file
mv src dst      # Move/rename
rm file         # Delete file
rm -rf dir      # Delete directory (careful!)
mkdir -p dir    # Create directory tree
chmod 755 file  # Change permissions
chown user file # Change owner
```

## Text Processing
```
cat file        # Display file
less file       # Page through file
head -n 10      # First 10 lines
tail -f file    # Follow file updates
grep pattern    # Search for pattern
sed 's/a/b/g'   # Replace text
awk '{print $1}'# Print first column
```

## System Info
```
uname -a        # System info
df -h           # Disk usage
free -m         # Memory usage
top / htop      # Process monitor
ps aux          # List processes
lsblk           # List block devices
ip addr         # Network interfaces
```

## Network
```
ping host       # Test connectivity
curl url        # Fetch URL
wget url        # Download file
ss -tulpn       # Open ports
ip route        # Routing table
iptables -L     # Firewall rules
```

## Archives
```
tar -czf a.tar.gz dir/  # Create .tar.gz
tar -xzf a.tar.gz       # Extract .tar.gz
zip -r a.zip dir/       # Create zip
unzip a.zip             # Extract zip
```

## Disk Operations
```
fdisk -l        # List disks
mount /dev/sda1 /mnt    # Mount
umount /mnt     # Unmount
dd if=x of=y bs=4M      # Copy raw
mkfs.ext4 /dev/sda1     # Format
```
EOF

    print_color "$GREEN" "Done: $dir"
}

download_arch_wiki() {
    local dir="$DOCS_DIR/arch-wiki"
    mkdir -p "$dir"

    print_color "$BLUE" "Setting up Arch Wiki offline access..."

    cat > "$dir/README.txt" << 'EOF'
Arch Wiki Offline
=================

The Arch Wiki is an excellent Linux resource. To access offline:

Option 1: Kiwix ZIM file
------------------------
Download from: https://download.kiwix.org/zim/archlinux/
Use with kiwix-serve (see ../kiwix setup)

Option 2: arch-wiki-docs package
--------------------------------
Arch Linux: pacman -S arch-wiki-docs
Access at: file:///usr/share/doc/arch-wiki/html/en/

Option 3: Clone the wiki
------------------------
git clone --depth 1 https://github.com/lahwaacz/arch-wiki-docs.git

The Arch Wiki covers:
- Installation guides
- Hardware configuration
- Network setup
- Security
- System administration
- Troubleshooting
EOF

    print_color "$GREEN" "Done: $dir"
}

download_git_docs() {
    local dir="$DOCS_DIR/git"
    mkdir -p "$dir"

    print_color "$BLUE" "Downloading Git documentation..."

    wget -q --show-progress -O "$dir/git-user-manual.html" \
        "https://git-scm.com/docs/user-manual.html" 2>/dev/null || true

    cat > "$dir/git-cheatsheet.md" << 'EOF'
# Git Cheatsheet

## Setup
```
git init                    # Initialize repo
git clone url               # Clone remote repo
git config user.name "x"    # Set username
git config user.email "x"   # Set email
```

## Basic Workflow
```
git status                  # Show status
git add file               # Stage file
git add .                   # Stage all changes
git commit -m "message"     # Commit
git push origin branch      # Push to remote
git pull origin branch      # Pull from remote
```

## Branches
```
git branch                  # List branches
git branch name             # Create branch
git checkout branch         # Switch branch
git checkout -b branch      # Create and switch
git merge branch            # Merge branch
git branch -d branch        # Delete branch
```

## History
```
git log                     # Show history
git log --oneline           # Compact history
git diff                    # Show changes
git diff --staged           # Staged changes
git show commit             # Show commit
```

## Undo
```
git checkout -- file        # Discard changes
git reset HEAD file         # Unstage
git reset --hard HEAD       # Reset to HEAD
git revert commit           # Revert commit
```

## Remote
```
git remote -v               # List remotes
git remote add name url     # Add remote
git fetch origin            # Fetch changes
```
EOF

    print_color "$GREEN" "Done: $dir"
}

download_python_docs() {
    local dir="$DOCS_DIR/python"
    mkdir -p "$dir"

    print_color "$BLUE" "Downloading Python documentation..."

    # Python docs are available as downloadable archive
    cat > "$dir/README.txt" << 'EOF'
Python Documentation
====================

Official downloads available at:
https://docs.python.org/3/download.html

Formats available:
- HTML (zip) - Best for offline browsing
- PDF - Single document
- EPUB - For e-readers

To download HTML version:
wget https://docs.python.org/3/archives/python-3.11-docs-html.zip
unzip python-3.11-docs-html.zip

Then open: python-3.11-docs-html/index.html
EOF

    # Quick reference
    cat > "$dir/python-cheatsheet.md" << 'EOF'
# Python Quick Reference

## Basics
```python
# Variables
x = 10
name = "text"
items = [1, 2, 3]
data = {"key": "value"}

# Print
print(f"Value: {x}")

# Input
text = input("Enter: ")

# Conditionals
if x > 5:
    print("big")
elif x > 0:
    print("small")
else:
    print("zero or negative")

# Loops
for item in items:
    print(item)

for i in range(10):
    print(i)

while x > 0:
    x -= 1
```

## Functions
```python
def greet(name, greeting="Hello"):
    return f"{greeting}, {name}!"

result = greet("World")
```

## Files
```python
# Read file
with open("file.txt", "r") as f:
    content = f.read()

# Write file
with open("file.txt", "w") as f:
    f.write("content")

# Read lines
with open("file.txt") as f:
    for line in f:
        print(line.strip())
```

## Common Operations
```python
# String operations
s = "hello world"
s.upper()           # HELLO WORLD
s.split()           # ['hello', 'world']
s.replace("o", "0") # hell0 w0rld

# List operations
items.append(4)     # Add item
items.pop()         # Remove last
len(items)          # Length
sorted(items)       # Sort

# Dictionary
data["new_key"] = "value"
data.get("key", "default")
data.keys()
data.values()
```

## Modules
```python
import os
import sys
import json
import datetime
from pathlib import Path
```
EOF

    print_color "$GREEN" "Done: $dir"
}

download_arduino_docs() {
    local dir="$DOCS_DIR/arduino"
    mkdir -p "$dir"

    print_color "$BLUE" "Downloading Arduino documentation..."

    cat > "$dir/README.txt" << 'EOF'
Arduino Documentation
=====================

Official reference available at:
https://www.arduino.cc/reference/en/

For offline access:
1. Clone the reference: git clone https://github.com/arduino/reference-en
2. Or use Kiwix with Arduino ZIM file

Arduino IDE includes built-in examples accessible via:
File → Examples
EOF

    cat > "$dir/arduino-cheatsheet.md" << 'EOF'
# Arduino Cheatsheet

## Basic Structure
```cpp
void setup() {
    // Runs once at startup
    pinMode(13, OUTPUT);
    Serial.begin(9600);
}

void loop() {
    // Runs repeatedly
    digitalWrite(13, HIGH);
    delay(1000);
    digitalWrite(13, LOW);
    delay(1000);
}
```

## Digital I/O
```cpp
pinMode(pin, INPUT);        // Set as input
pinMode(pin, OUTPUT);       // Set as output
pinMode(pin, INPUT_PULLUP); // Input with pullup

digitalWrite(pin, HIGH);    // Set high (5V/3.3V)
digitalWrite(pin, LOW);     // Set low (0V)

int state = digitalRead(pin); // Read state
```

## Analog I/O
```cpp
int value = analogRead(A0);  // Read 0-1023
analogWrite(pin, 127);       // PWM 0-255
```

## Serial Communication
```cpp
Serial.begin(9600);          // Start serial
Serial.println("text");      // Print line
Serial.print(value);         // Print value
if (Serial.available()) {
    char c = Serial.read();  // Read byte
}
```

## Timing
```cpp
delay(1000);                 // Wait 1000ms
unsigned long t = millis();  // Time since start
delayMicroseconds(100);      // Microsecond delay
```

## Common Pins
```
LED_BUILTIN - Built-in LED (usually 13)
A0-A5       - Analog inputs
0-13        - Digital pins
3,5,6,9,10,11 - PWM capable (Uno)
```
EOF

    print_color "$GREEN" "Done: $dir"
}

download_rpi_docs() {
    local dir="$DOCS_DIR/raspberry-pi"
    mkdir -p "$dir"

    print_color "$BLUE" "Downloading Raspberry Pi documentation..."

    cat > "$dir/README.txt" << 'EOF'
Raspberry Pi Documentation
==========================

Official docs: https://www.raspberrypi.com/documentation/

For offline, clone:
git clone https://github.com/raspberrypi/documentation

Key topics:
- Getting started
- Configuration
- GPIO programming
- Camera usage
- Networking
EOF

    cat > "$dir/rpi-gpio-cheatsheet.md" << 'EOF'
# Raspberry Pi GPIO Cheatsheet

## Pin Numbering
```
           3.3V  1  2  5V
  GPIO2 (SDA)  3  4  5V
  GPIO3 (SCL)  5  6  GND
        GPIO4  7  8  GPIO14 (TXD)
          GND  9  10 GPIO15 (RXD)
       GPIO17 11  12 GPIO18 (PWM0)
       GPIO27 13  14 GND
       GPIO22 15  16 GPIO23
          3.3V 17  18 GPIO24
GPIO10 (MOSI) 19  20 GND
 GPIO9 (MISO) 21  22 GPIO25
GPIO11 (SCLK) 23  24 GPIO8 (CE0)
          GND 25  26 GPIO7 (CE1)
        GPIO0 27  28 GPIO1
        GPIO5 29  30 GND
        GPIO6 31  32 GPIO12 (PWM0)
GPIO13 (PWM1) 33  34 GND
GPIO19 (MISO) 35  36 GPIO16
       GPIO26 37  38 GPIO20 (MOSI)
          GND 39  40 GPIO21 (SCLK)
```

## Python GPIO
```python
import RPi.GPIO as GPIO
import time

GPIO.setmode(GPIO.BCM)  # Use GPIO numbers
GPIO.setup(17, GPIO.OUT)
GPIO.setup(18, GPIO.IN, pull_up_down=GPIO.PUD_UP)

GPIO.output(17, GPIO.HIGH)
state = GPIO.input(18)

GPIO.cleanup()
```

## gpiozero (simpler)
```python
from gpiozero import LED, Button
from time import sleep

led = LED(17)
button = Button(18)

led.on()
led.off()
led.blink()

button.when_pressed = lambda: print("Pressed!")
```
EOF

    print_color "$GREEN" "Done: $dir"
}

download_radio_guide() {
    local dir="$DOCS_DIR/radio"
    mkdir -p "$dir"

    print_color "$BLUE" "Creating radio frequency guide..."

    cat > "$dir/emergency-frequencies.md" << 'EOF'
# Emergency Radio Frequencies

## CB Radio (Citizens Band)
- **Channel 9** - Emergency/distress (27.065 MHz)
- **Channel 19** - Highway/truckers (27.185 MHz)

## FRS/GMRS (Walkie-Talkies)
- **Channel 1** (462.5625 MHz) - Common emergency
- **Channel 20** (462.6750 MHz) - GMRS emergency

## Marine VHF
- **Channel 16** (156.800 MHz) - Distress & calling
- **Channel 9** (156.450 MHz) - Secondary calling

## Amateur (Ham) Radio
### 2 Meter Band (144-148 MHz)
- **146.520 MHz** - National calling frequency
- **146.550 MHz** - Common simplex
- **147.555 MHz** - Common simplex

### 70cm Band (420-450 MHz)
- **446.000 MHz** - National calling frequency
- **446.500 MHz** - Common simplex

### HF (Long Distance)
- **7.260 MHz** - 40m emergency net
- **14.300 MHz** - 20m emergency net
- **3.860 MHz** - 80m emergency net

## NOAA Weather Radio
- 162.400 MHz
- 162.425 MHz
- 162.450 MHz
- 162.475 MHz
- 162.500 MHz
- 162.525 MHz
- 162.550 MHz

## MURS (Multi-Use Radio Service)
- 151.820 MHz
- 151.880 MHz
- 151.940 MHz
- 154.570 MHz
- 154.600 MHz

## Notes
- In true emergencies, use ANY frequency to call for help
- Repeaters extend range but may not work without power
- Simplex (direct) communication works without infrastructure
- FRS/GMRS radios are most common and affordable
EOF

    print_color "$GREEN" "Done: $dir"
}

download_bundle() {
    local bundle="$1"

    case $bundle in
        90) # Essential survival
            download_survival_manual
            download_where_no_doctor
            download_where_no_dentist
            download_fema_guides
            ;;
        91) # Linux admin
            download_linux_docs
            download_arch_wiki
            download_git_docs
            download_python_docs
            ;;
        92) # Maker/Electronics
            download_arduino_docs
            download_rpi_docs
            ;;
        99) # All
            download_survival_manual
            download_where_no_doctor
            download_where_no_dentist
            download_fema_guides
            download_linux_docs
            download_arch_wiki
            download_git_docs
            download_python_docs
            download_arduino_docs
            download_rpi_docs
            download_radio_guide
            ;;
    esac
}

interactive_menu() {
    show_menu

    print_color "$WHITE" "Enter choices (comma-separated, or 'q' to quit): "
    read -r choices

    [[ "$choices" == "q" ]] && exit 0

    IFS=',' read -ra nums <<< "$choices"
    for num in "${nums[@]}"; do
        num=$(echo "$num" | tr -d ' ')
        case $num in
            1) download_survival_manual ;;
            2) download_where_no_doctor ;;
            3) download_where_no_dentist ;;
            4) download_fema_guides ;;
            10) download_linux_docs ;;
            11) download_arch_wiki ;;
            12) download_git_docs ;;
            13) download_python_docs ;;
            14) download_linux_docs ;; # Bash included in linux
            20) print_color "$YELLOW" "Electronics PDFs - search online for specific needs" ;;
            21) download_arduino_docs ;;
            22) download_rpi_docs ;;
            31) download_radio_guide ;;
            90|91|92|99) download_bundle "$num" ;;
            *) print_color "$RED" "Unknown option: $num" ;;
        esac
    done
}

# Main
check_deps
mkdir -p "$DOCS_DIR"

case "${1:-menu}" in
    menu|"")
        interactive_menu
        ;;
    all)
        download_bundle 99
        ;;
    survival)
        download_bundle 90
        ;;
    linux)
        download_bundle 91
        ;;
    electronics)
        download_bundle 92
        ;;
    *)
        echo "Usage: $0 [menu|all|survival|linux|electronics]"
        exit 1
        ;;
esac

echo ""
print_color "$GREEN" "Documentation saved to: $DOCS_DIR"
print_color "$WHITE" "Contents:"
du -sh "$DOCS_DIR"/* 2>/dev/null | head -20
