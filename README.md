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

# OpenClaw Detection Scripts - TL;DR

Detection scripts for MDM deployment to identify OpenClaw installations on managed devices.

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

### macOS/Linux

```bash
curl -sL https://raw.githubusercontent.com/knostic/openclaw-detect/refs/heads/main/detect-openclaw.sh | bash
```

### Windows (PowerShell)

```powershell
iwr -useb https://raw.githubusercontent.com/knostic/openclaw-detect/refs/heads/main/detect-openclaw.ps1 | iex
```

### Run as root/admin

Running with elevated privileges scans all user directories:

```bash
curl -sL https://raw.githubusercontent.com/knostic/openclaw-detect/refs/heads/main/detect-openclaw.sh | sudo bash
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENCLAW_PROFILE` | (none) | Profile name for multi-instance setups |
| `OPENCLAW_GATEWAY_PORT` | 18789 | Gateway port to check |

## Example Output

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

---

## MDM Integration

| Platform | Guide |
|----------|-------|
| Addigy | [docs/addigy.md](docs/addigy.md) |
| JumpCloud | [docs/jumpcloud.md](docs/jumpcloud.md) |
| Microsoft Intune | [docs/intune.md](docs/intune.md) |
| Jamf Pro | [docs/jamf.md](docs/jamf.md) |
| VMware Workspace ONE | [docs/workspace-one.md](docs/workspace-one.md) |
| Kandji | [docs/kandji.md](docs/kandji.md) |

---

- ## License

Apache 2.0 — see LICENSE for details.

