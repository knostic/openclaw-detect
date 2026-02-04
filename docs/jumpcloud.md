# JumpCloud Integration

JumpCloud Commands run scripts via the agent on managed devices, capturing stdout, stderr, and exit codes. Results are stored for 30 days.

## Setup via UI

1. Go to **DEVICE MANAGEMENT > Commands > +**
2. **Name:** OpenClaw Detection
3. **Command Type:** Shell (macOS/Linux) or PowerShell (Windows)
4. **Command:**
   ```bash
   curl -sL https://raw.githubusercontent.com/knostic/openclaw-detect/refs/heads/main/detect-openclaw.sh | bash
   ```
5. **Run as:** root (to scan all users) or current user
6. **Schedule:** Manual, scheduled, or triggered

## Setup via API

```bash
# macOS/Linux
curl -X POST https://console.jumpcloud.com/api/commands/ \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/json' \
  -H 'x-api-key: YOUR_API_KEY' \
  -d '{
    "name": "OpenClaw Detection",
    "command": "curl -sL https://raw.githubusercontent.com/knostic/openclaw-detect/refs/heads/main/detect-openclaw.sh | bash",
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
    "command": "iwr -useb https://raw.githubusercontent.com/knostic/openclaw-detect/refs/heads/main/detect-openclaw.ps1 | iex",
    "commandType": "windows",
    "shell": "powershell",
    "timeout": "120"
  }'
```

## Viewing Results

1. Go to **DEVICE MANAGEMENT > Commands**
2. Select the command
3. Click **Results** tab
4. Filter by exit code:
   - Exit 0 = Clean (OpenClaw not installed)
   - Exit 1 = Found (OpenClaw detected - review needed)
   - Exit 2 = Error (script failed - investigate)

## Compliance Alerts

Configure JumpCloud alerts to trigger on exit code 1 (OpenClaw detected) for shadow IT monitoring.
