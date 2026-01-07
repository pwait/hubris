# Hubris

A dual-purpose repository containing a consulting landing page and a comprehensive disk wipe toolkit.

## 📂 Repository Contents

### 1. Wait & Co. Landing Page

A bespoke consulting website for AI integration services, featuring an elegant, atmospheric design.

- **Live Site**: Deployed via GitHub Pages
- **Technology**: Single-page HTML with inline CSS/JavaScript
- **Design**: EB Garamond typography, atmospheric effects, hidden easter eggs
- **File**: `index.html`

**Features:**
- Self-contained static website (no build process)
- Responsive design with atmospheric visual effects
- Hidden interactive elements (discover the π!)
- Optimized for GitHub Pages deployment

### 2. Disk Wipe Toolkit

A modern replacement for DBAN (Darik's Boot and Nuke) — comprehensive disk wiping utilities for secure data destruction.

- **Location**: `disk-wipe/` directory
- **Purpose**: Securely erase data from hard drives and SSDs
- **Documentation**: See [disk-wipe/README.md](disk-wipe/README.md)

**Tools included:**
- `wipe-disk.sh` — Interactive menu-driven wipe utility
- `quick-wipe.sh` — Command-line automation script
- `setup-nwipe.sh` — Dependency installer
- `create-bootable-usb.sh` — Bootable USB creator

**Wipe methods:** Zero Fill, Random Fill, DoD 5220.22-M (3-pass), Gutmann (35-pass)

## 🚀 Quick Start

### Landing Page Development

```bash
# Serve locally for testing
python3 -m http.server 8000

# Visit http://localhost:8000
```

Changes to `index.html` pushed to `main` branch auto-deploy to GitHub Pages.

### Disk Wipe Usage

```bash
# Boot from Linux Live USB, then:
cd disk-wipe
sudo ./setup-nwipe.sh  # First time only
sudo ./wipe-disk.sh     # Interactive wipe utility
```

For detailed instructions, see [disk-wipe/README.md](disk-wipe/README.md).

## 📖 Documentation

### For Developers & AI Agents

- **[CLAUDE.md](CLAUDE.md)** — Architecture overview, development workflows, deployment process
- **[AGENTS.md](AGENTS.md)** — Implementation patterns and lessons learned from previous agent work

### For Users

- **[disk-wipe/README.md](disk-wipe/README.md)** — Complete disk wipe toolkit documentation

## 🏗️ Architecture

### Landing Page Architecture

- **Single HTML file** — No build step, direct deployment
- **Design system** — CSS custom properties for theming
- **Font stack** — EB Garamond (body), JetBrains Mono (code/accents)
- **Easter eggs** — Hidden interactive elements with cleanup patterns
- **Deployment** — GitHub Actions workflow (`.github/workflows/static.yml`)

### Disk Wipe Toolkit Architecture

- **Safety-first design** — Multiple confirmations, boot device protection
- **Modular functions** — Shared logic in `lib/disk-utils.sh`
- **Error handling** — Fail-fast with `set -euo pipefail`
- **Tool abstraction** — Unified interface for `nwipe`, `dd`, `shred`

## 🔒 Security Notes

### Disk Wipe Scripts

⚠️ **WARNING**: These tools permanently destroy data. Use with extreme caution.

- Always verify target disk before wiping
- Scripts include boot device detection and multiple confirmation prompts
- Test on disposable media or loop devices before production use

### Landing Page

- Static HTML only — no server-side code, no dependencies
- Served via GitHub Pages with HTTPS
- No user data collection or external API calls (except Google Fonts CDN)

## 🌿 Development Workflow

### Git Conventions

- **Main branch**: `main`
- **Feature branches**: `<name>/feature` (e.g., `ralph/feature`)
- **Bug fixes**: `<name>/fix-<issue>`

### Deployment

- **GitHub Pages**: Auto-deploys from `main` branch on push
- **Deployed files**: Only `index.html` (disk-wipe tools excluded from Pages)
- **Workflow**: `.github/workflows/static.yml`

## 🤝 Contributing

This is a personal project, but contributions are welcome:

1. Fork the repository
2. Create a feature branch (`<yourname>/feature`)
3. Make your changes
4. Submit a pull request

For AI agents working on this repo: Please read [CLAUDE.md](CLAUDE.md) for architecture details and [AGENTS.md](AGENTS.md) for implementation patterns.

## 📜 License

This project is provided as-is for educational and personal use.

### Disk Wipe Toolkit

The disk wipe utilities are wrappers around existing open-source tools:
- `nwipe` (GPL-2.0)
- `dd` (GPL-3.0)
- `shred` (GPL-3.0)

Use responsibly and in accordance with applicable laws and regulations.

---

**Note**: The name "hubris" reflects the excessive confidence required to build both a consulting landing page and a disk destruction toolkit in the same repository. 😄
