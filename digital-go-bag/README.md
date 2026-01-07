# Digital Go Bag

A collection of scripts and tools for digital resilience when internet infrastructure is unavailable. Everything here works **offline** and is designed for scenarios where normal communications and internet are down.

## Quick Start

```bash
# Make all scripts executable
chmod +x **/*.sh

# Set up offline Wikipedia & knowledge
./offline-knowledge/setup-kiwix.sh install
./offline-knowledge/setup-kiwix.sh essential

# Create a local mesh network
sudo ./mesh-network/setup-batman-mesh.sh start

# Create an encrypted knowledge vault
./offline-knowledge/create-obsidian-vault.sh ~/my-vault
```

## Contents

```
digital-go-bag/
├── mesh-network/          # Local network without internet
├── offline-knowledge/     # Wikipedia, docs, knowledge bases
├── communication/         # Radio, chat, file sharing
├── documentation/         # Downloadable offline docs
├── utilities/             # Power, hardware, encryption
└── bin/                   # Helper binaries
```

## Mesh Networking

Create local networks when internet is down. Connect devices directly without routers or ISPs.

| Script | Description |
|--------|-------------|
| `setup-batman-mesh.sh` | Full mesh network using BATMAN-adv protocol |
| `setup-adhoc-wifi.sh` | Simple peer-to-peer WiFi network |
| `setup-meshtastic.sh` | Long-range LoRa mesh (1-10+ km) |
| `mesh-file-share.sh` | Share files over mesh network |

### Mesh Network Quick Start

```bash
# On each computer, run (with different IPs):
sudo ./mesh-network/setup-batman-mesh.sh start

# Edit the script first to set unique IP for each node:
# Node 1: MESH_IP="10.99.0.1"
# Node 2: MESH_IP="10.99.0.2"
# etc.

# Check mesh status
sudo batctl n           # Show neighbors
sudo batctl o           # Show all nodes
```

### Meshtastic (Long Range)

For communication over kilometers, Meshtastic uses cheap LoRa radio modules (~$25).

```bash
./mesh-network/setup-meshtastic.sh install
./mesh-network/setup-meshtastic.sh configure
./mesh-network/setup-meshtastic.sh send "Hello mesh!"
```

## Offline Knowledge

Access Wikipedia, medical guides, and reference materials without internet.

| Script | Description |
|--------|-------------|
| `setup-kiwix.sh` | Download and serve Wikipedia offline |
| `create-obsidian-vault.sh` | Create structured knowledge vault |

### Kiwix (Offline Wikipedia)

```bash
# Install Kiwix
./offline-knowledge/setup-kiwix.sh install

# Download essential content (~12GB total)
./offline-knowledge/setup-kiwix.sh essential
# Downloads: Simple Wikipedia, Medical Encyclopedia, Wikibooks

# Start web server
./offline-knowledge/setup-kiwix.sh serve
# Open http://localhost:8888 in browser
```

### Content Available

| Content | Size | Description |
|---------|------|-------------|
| Wikipedia Simple English | 1.5GB | Simplified articles |
| Wikipedia English (no images) | 10GB | Full text articles |
| Wikipedia English (full) | 90GB | Complete with images |
| WikiMed Medical | 700MB | Medical encyclopedia |
| Wikibooks | 1GB | How-to guides |
| iFixit | 3GB | Repair guides |
| Stack Overflow | 50GB | Programming Q&A |

### Obsidian Vault

Create a personal knowledge base that works 100% offline.

```bash
./offline-knowledge/create-obsidian-vault.sh ~/survival-vault
```

Includes templates for:
- Daily journal entries
- Resource tracking
- Contact management
- Location documentation
- Medical incidents
- Skills/procedures

## Communication

### Local Chat

```bash
# Start chat server
NICK=alice ./communication/local-chat.sh server

# Connect from another machine
NICK=bob ./communication/local-chat.sh connect 10.99.0.1
```

### SDR Radio Scanner

Listen to radio frequencies with cheap RTL-SDR dongles (~$25).

```bash
# Install software
./communication/sdr-scanner.sh install

# Listen to FM radio
./communication/sdr-scanner.sh fm 98.5

# Scan NOAA weather
./communication/sdr-scanner.sh noaa

# Show frequency guide
./communication/sdr-scanner.sh frequencies
```

## Documentation

Download technical references for offline use.

```bash
# Interactive download menu
./documentation/download-docs.sh

# Download bundles
./documentation/download-docs.sh survival     # Survival guides
./documentation/download-docs.sh linux        # Linux admin docs
./documentation/download-docs.sh electronics  # Arduino, RasPi

# Download everything
./documentation/download-docs.sh all
```

### Available Documentation

**Survival & Medical:**
- US Army Survival Manual FM 21-76
- Where There Is No Doctor
- Where There Is No Dentist
- FEMA Emergency Guides

**Technical:**
- Linux man pages & cheatsheets
- Git documentation
- Python reference
- Bash manual

**Electronics:**
- Arduino reference
- Raspberry Pi GPIO guide
- Radio frequency guide

## Utilities

### Power Management

```bash
# Show battery status
./utilities/power-management.sh status

# Enable power-saving mode (extend battery)
sudo ./utilities/power-management.sh powersave

# Estimate runtime
./utilities/power-management.sh estimate
```

### Hardware Info

```bash
# Complete hardware report
./utilities/hardware-info.sh all

# Specific sections
./utilities/hardware-info.sh cpu
./utilities/hardware-info.sh storage
./utilities/hardware-info.sh network
./utilities/hardware-info.sh battery

# Save report to file
./utilities/hardware-info.sh save
```

### File Encryption

```bash
# Encrypt a file
./utilities/encrypt-files.sh encrypt secret.txt

# Decrypt
./utilities/encrypt-files.sh decrypt secret.txt.gpg

# Encrypt entire directory
./utilities/encrypt-files.sh encrypt-dir documents/

# Generate strong password
./utilities/encrypt-files.sh password 32

# Securely delete a file
./utilities/encrypt-files.sh delete old-secret.txt
```

## Hardware Recommendations

### Essential USB Kit

| Item | Purpose | Cost |
|------|---------|------|
| USB Drive (128GB+) | Store all tools & docs | $15 |
| RTL-SDR Dongle | Radio receiver | $25 |
| Meshtastic Device | Long-range mesh | $35 |
| USB WiFi Adapter | Mesh networking | $15 |
| USB Power Bank | Power laptops/devices | $50 |

### Meshtastic Devices

Best options for LoRa mesh networking:
- **LILYGO T-Beam** (~$35) - Built-in GPS, 18650 battery
- **Heltec LoRa 32** (~$20) - Compact, OLED display
- **RAK WisBlock** (~$30) - Modular, solar-ready

## Network Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     MESH NETWORK                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   ┌──────────┐     BATMAN-adv      ┌──────────┐            │
│   │ Laptop 1 │◄──────────────────►│ Laptop 2 │            │
│   │ 10.99.0.1│     WiFi Mesh      │ 10.99.0.2│            │
│   └────┬─────┘                    └────┬─────┘            │
│        │                               │                   │
│        │     ┌──────────┐              │                   │
│        └────►│ Laptop 3 │◄─────────────┘                   │
│              │ 10.99.0.3│                                  │
│              └──────────┘                                  │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                     LONG RANGE (LoRa)                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   ┌────────────┐  1-10 km   ┌────────────┐                 │
│   │ Meshtastic │◄──────────►│ Meshtastic │                 │
│   │   Node 1   │   LoRa     │   Node 2   │                 │
│   └────────────┘            └────────────┘                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Security Notes

- All encryption uses AES-256
- No data is sent to the internet
- Mesh networks are local only
- Use encryption for sensitive data
- Secure delete files after use

## Dependencies

Most scripts will check for dependencies and offer to install them. Common requirements:

```bash
# Debian/Ubuntu
sudo apt install batctl wireless-tools iw netcat-openbsd \
    gnupg openssl rtl-sdr python3 python3-pip

# Fedora
sudo dnf install batctl wireless-tools iw nmap-ncat \
    gnupg openssl rtl-sdr python3 python3-pip
```

## Offline Use

This entire toolkit is designed for offline use:

1. **No internet required** - All tools work locally
2. **No cloud services** - Data stays on your device
3. **No accounts needed** - No logins or registrations
4. **Plain text storage** - Obsidian uses Markdown files
5. **Standard tools** - Uses common Linux utilities

## Tips for Preparedness

1. **Download content NOW** - Wikipedia, docs, medical guides
2. **Test your mesh** - Practice setting up before you need it
3. **Charge devices** - Keep power banks ready
4. **Print key info** - Some references should be on paper
5. **Learn the tools** - Familiarity matters in emergencies

## License

Public domain / CC0. Use freely.

## Contributing

This is a personal preparedness toolkit. Fork and customize for your needs.
