# OpenClaw Detection Scripts

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

| Exit Code | Meaning | JumpCloud Status |
|-----------|---------|------------------|
| 0 | NOT installed | Success (clean) |
| 1 | Installed (running or not) | Error (found) |
| 2 | Script error | Error (investigate) |

## Usage

### macOS/Linux

```bash
curl -sL https://knostic.ai/detect-openclaw.sh | bash
```

### Windows (PowerShell)

```powershell
iwr -useb https://knostic.ai/detect-openclaw.ps1 | iex
```

### Run as root/admin

Running with elevated privileges scans all user directories:

```bash
curl -sL https://knostic.ai/detect-openclaw.sh | sudo bash
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

## JumpCloud Integration

JumpCloud Commands run scripts via the agent on managed devices, capturing stdout, stderr, and exit codes. Results are stored for 30 days.

### Setup via UI

1. Go to **DEVICE MANAGEMENT > Commands > +**
2. **Name:** OpenClaw Detection
3. **Command Type:** Shell (macOS/Linux) or PowerShell (Windows)
4. **Command:**
   ```bash
   curl -sL https://knostic.ai/detect-openclaw.sh | bash
   ```
5. **Run as:** root (to scan all users) or current user
6. **Schedule:** Manual, scheduled, or triggered

### Setup via API

```bash
# macOS/Linux
curl -X POST https://console.jumpcloud.com/api/commands/ \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/json' \
  -H 'x-api-key: YOUR_API_KEY' \
  -d '{
    "name": "OpenClaw Detection",
    "command": "curl -sL https://knostic.ai/detect-openclaw.sh | bash",
    "commandType": "mac",
    "sudo": true,
    "timeout": "120"
  }'

# Windows
curl -X POST https://console.jumpcloud.com/api/commands/ \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/json' \
  -H 'x-api-key: YOUR_API_KEY' \
  -d '{
    "name": "OpenClaw Detection (Windows)",
    "command": "iwr -useb https://knostic.ai/detect-openclaw.ps1 | iex",
    "commandType": "windows",
    "shell": "powershell",
    "timeout": "120"
  }'
```

### Viewing Results

1. Go to **DEVICE MANAGEMENT > Commands**
2. Select the command
3. Click **Results** tab
4. Filter by exit code:
   - Exit 0 = Clean (OpenClaw not installed)
   - Exit 1 = Found (OpenClaw detected - review needed)
   - Exit 2 = Error (script failed - investigate)

### Compliance Alerts

Configure JumpCloud alerts to trigger on exit code 1 (OpenClaw detected) for shadow IT monitoring.
