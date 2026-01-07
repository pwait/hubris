# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository ("hubris") is a personal project collection containing:
1. **Wait & Co. Landing Page** - A consulting/AI integration landing page (`index.html`)
2. **Disk Wipe Toolkit** - Comprehensive disk wiping utilities for secure data destruction (`disk-wipe/`)

## Architecture

### Wait & Co. Landing Page (index.html)

A single-page static website with no build process required. Architecture:
- **Self-contained HTML file** - All CSS and JavaScript inline
- **No dependencies** - Uses Google Fonts CDN only
- **Design system** - CSS custom properties for theming (see `:root` variables)
- **Font stack**: EB Garamond (body), JetBrains Mono (code/accents)
- **Easter eggs** - Hidden interactive elements (see AGENTS.md for patterns)

**Key architectural patterns:**
- Atmospheric effects via fixed-position pseudo-elements and SVG filters
- z-index layering: atmosphere (0), content (1), noise overlay (1000), easter eggs (999-9999)
- Animation cleanup pattern: dynamically created elements must be removed via `setTimeout()` to prevent DOM bloat
- Scroll-reveal pattern for progressive content display

**Deployment:**
- GitHub Pages auto-deploys from `main` branch (see `.github/workflows/static.yml`)
- No build step - changes to `index.html` deploy directly

### Disk Wipe Toolkit (disk-wipe/)

Shell script collection for secure disk erasure. Structure:
```
disk-wipe/
├── wipe-disk.sh           # Interactive menu-driven utility (main entry point)
├── quick-wipe.sh          # Command-line automation script
├── setup-nwipe.sh         # Dependency installer
├── create-bootable-usb.sh # Bootable USB creator
└── lib/
    └── disk-utils.sh      # Shared utility functions
```

**Architecture principles:**
- **Safety-first design** - Multiple confirmation prompts, boot device protection
- **Modular functions** - Shared logic in `lib/disk-utils.sh`
- **Error handling** - Scripts use `set -euo pipefail` for fail-fast behavior
- **Tool abstraction** - Wrapper around `nwipe`, `dd`, `shred` with unified interface

**Common wipe methods:**
- Zero Fill (1 pass) - SSDs, quick disposal
- DoD 5220.22-M (3 pass) - Government/corporate compliance
- Gutmann (35 pass) - Paranoid level security
- ATA Secure Erase - SSD-optimized built-in erase

## Development Workflow

### Landing Page Development

**Testing locally:**
```bash
# Serve locally (Python 3)
python3 -m http.server 8000

# Or Python 2
python -m SimpleHTTPServer 8000

# Then visit http://localhost:8000
```

**Making changes:**
1. Edit `index.html` directly
2. Test locally
3. Commit and push to `main` - auto-deploys to GitHub Pages

**Easter egg patterns:**
- Document new easter eggs in `AGENTS.md` with implementation details
- Follow z-index conventions: trigger (999), supporting effects (9998), main effects (9999)
- Always implement cleanup via `setTimeout(() => element.remove(), duration)`

### Disk Wipe Scripts Development

**Testing disk scripts:**
```bash
# NEVER test on real disks during development
# Use loop devices or VMs with disposable disks

# Create test loop device (Linux)
sudo dd if=/dev/zero of=test-disk.img bs=1M count=100
sudo losetup /dev/loop0 test-disk.img

# Test with loop device
sudo ./disk-wipe/wipe-disk.sh  # Select /dev/loop0

# Cleanup
sudo losetup -d /dev/loop0
rm test-disk.img
```

**Script modification guidelines:**
- Maintain safety checks (boot device detection, multiple confirmations)
- Update both `wipe-disk.sh` (interactive) and `quick-wipe.sh` (CLI) for feature parity
- Add new shared functions to `lib/disk-utils.sh`
- Test all wipe methods: zero, random, DoD, Gutmann

## Git Workflow

**Branch naming:**
- Feature branches: `<name>/feature` (e.g., `ralph/feature`)
- Bug fixes: `<name>/fix-<issue>`

**Main branch:** `main`

**Deployment:**
- GitHub Pages deploys automatically from `main` branch
- Static content workflow configured in `.github/workflows/static.yml`

## Agent Learnings (AGENTS.md)

This file documents patterns and gotchas from previous agent implementations. When implementing new features:
1. Check `AGENTS.md` for relevant patterns
2. Document new patterns after successful implementation
3. Include: patterns used, gotchas encountered, technical details
