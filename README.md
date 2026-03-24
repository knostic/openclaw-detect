```
██╗  ██╗███╗   ██╗ ██████╗ ███████╗████████╗██╗ ██████╗
██║ ██╔╝████╗  ██║██╔═══██╗██╔════╝╚══██╔══╝██║██╔════╝
█████╔╝ ██╔██╗ ██║██║   ██║███████╗   ██║   ██║██║     
██╔═██╗ ██║╚██╗██║██║   ██║╚════██║   ██║   ██║██║     
██║  ██╗██║ ╚████║╚██████╔╝███████║   ██║   ██║╚██████╗
╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚══════╝   ╚═╝   ╚═╝ ╚═════╝
```

# OpenClaw Detection Scripts

**By [Knostic](https://knostic.ai/)**

> **Find OpenClaw on managed devices.** Lightweight detection scripts for macOS, Linux, and Windows that check for CLI binaries, app bundles, config files, gateway services, and Docker artifacts. Designed for MDM deployment via Jamf, Intune, JumpCloud, and more.

Also check out:
- **openclaw-telemetry:** https://github.com/knostic/openclaw-telemetry
- **Like what we do?** Knostic helps you with visibility and control of your coding agents and MCP/extensions, from Cursor and Claude Code, to Copilot.

---

# OpenClaw Detection & Removal Scripts - TL;DR

Detection scripts for MDM deployment to identify OpenClaw installations on managed devices, plus removal scripts to uninstall them.

## What It Detects

| Check | macOS | Linux | Windows |
|-------|-------|-------|---------|
| CLI binary (`openclaw`) | Yes | Yes | Yes |
| CLI version | Yes | Yes | Yes |
| macOS app (`/Applications/OpenClaw.app`) | Yes | - | - |
| State directory (`~/.openclaw`) | Yes | Yes | Yes |
| Config file (`~/.openclaw/openclaw.json`) | Yes | Yes | Yes |
| Gateway service (launchd/systemd/schtasks) | Yes | Yes | Yes |
| Gateway port (default 18789) | Yes | Yes | Yes |
| Docker containers | Yes | Yes | Yes |
| Docker images | Yes | Yes | Yes |

## Exit Codes

| Exit Code | Meaning | MDM Status |
|-----------|---------|------------|
| 0 | NOT installed | Success (clean) |
| 1 | Installed (running or not) | Error (found) |
| 2 | Script error | Error (investigate) |

## Usage

### Detection

#### macOS/Linux

```bash
curl -sL https://raw.githubusercontent.com/knostic/openclaw-detect/refs/heads/main/detect-openclaw.sh | bash
```

#### Windows (PowerShell)

```powershell
iwr -useb https://raw.githubusercontent.com/knostic/openclaw-detect/refs/heads/main/detect-openclaw.ps1 | iex
```

#### Without curl

Copy [`detect-openclaw.sh`](detect-openclaw.sh) (macOS/Linux) or [`detect-openclaw.ps1`](detect-openclaw.ps1) (Windows) and run directly.

### Removal

#### macOS/Linux

```bash
curl -sL https://raw.githubusercontent.com/knostic/openclaw-detect/refs/heads/main/remove-openclaw.sh | sudo bash
```

#### Windows (PowerShell, as Administrator)

```powershell
iwr -useb https://raw.githubusercontent.com/knostic/openclaw-detect/refs/heads/main/remove-openclaw.ps1 | iex
```

#### Without curl

Copy [`remove-openclaw.sh`](remove-openclaw.sh) (macOS/Linux) or [`remove-openclaw.ps1`](remove-openclaw.ps1) (Windows) and run directly.

### Run as root/admin

Running with elevated privileges scans and acts on all user directories:

```bash
# Detection
curl -sL https://raw.githubusercontent.com/knostic/openclaw-detect/refs/heads/main/detect-openclaw.sh | sudo bash

# Removal
curl -sL https://raw.githubusercontent.com/knostic/openclaw-detect/refs/heads/main/remove-openclaw.sh | sudo bash
```

## What It Removes

The removal scripts perform a phased cleanup in this order:

1. **Stop services** — launchd (macOS), systemd (Linux), scheduled tasks (Windows)
2. **Kill gateway processes** — on default and configured ports
3. **Docker** — stop/remove containers and images matching `openclaw`
4. **Package managers** — brew, npm, volta (macOS/Linux); scoop, npm, winget (Windows)
5. **CLI binaries** — global and per-user install locations
6. **macOS app bundle** — `/Applications/OpenClaw.app`
7. **State directories** — `~/.openclaw` (or profile variant) unless `OPENCLAW_KEEP_DATA=1`
8. **WSL** (Windows only) — openclaw binary inside WSL

### Removal Exit Codes

| Exit Code | Meaning | MDM Status |
|-----------|---------|------------|
| 0 | All removed (or nothing to remove) | Success (clean) |
| 1 | Partial removal (some items failed) | Error (investigate) |
| 2 | Script error | Error (investigate) |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENCLAW_PROFILE` | (none) | Profile name for multi-instance setups |
| `OPENCLAW_GATEWAY_PORT` | 18789 | Gateway port to check |
| `OPENCLAW_KEEP_DATA` | 0 | Set to `1` to preserve state directories during removal |
| `OPENCLAW_DRY_RUN` | 0 | Set to `1` to log removal actions without performing them |

## Example Output

### Detection

```
summary: installed-and-running
platform: darwin
cli: /usr/local/bin/openclaw
cli-version: 2026.1.15
app: /Applications/OpenClaw.app
state-dir: /Users/alice/.openclaw
config: /Users/alice/.openclaw/openclaw.json
gateway-service: gui/501/bot.molt.gateway
gateway-port: 18789
docker-container: not-found
docker-image: not-found
```

### Removal

```
result: all-removed
platform: darwin
removed: launchd service gui/501/bot.molt.gateway
removed: kill gateway process pid=12345 on port 18789
removed: brew uninstall openclaw
removed: binary /usr/local/bin/openclaw
removed: macOS app bundle /Applications/OpenClaw.app
removed: state-dir /Users/alice/.openclaw
```

### Removal (dry run)

```
result: nothing-to-remove
platform: darwin
mode: dry-run
dry-run: launchd service gui/501/bot.molt.gateway
dry-run: brew uninstall openclaw
dry-run: binary /usr/local/bin/openclaw
dry-run: state-dir /Users/alice/.openclaw
```

---

## MDM Integration

| Platform | Guide |
|----------|-------|
| Addigy | [docs/addigy.md](docs/addigy.md) |
| CrowdStrike Falcon | [docs/crowdstrike.md](docs/crowdstrike.md) |
| JumpCloud | [docs/jumpcloud.md](docs/jumpcloud.md) |
| Microsoft Intune | [docs/intune.md](docs/intune.md) |
| Jamf Pro | [docs/jamf.md](docs/jamf.md) |
| VMware Workspace ONE | [docs/workspace-one.md](docs/workspace-one.md) |
| Kandji | [docs/kandji.md](docs/kandji.md) |

---

- ## License

Apache 2.0 — see LICENSE for details.

