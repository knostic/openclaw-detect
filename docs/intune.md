# Microsoft Intune Integration

Intune Remediations allow you to deploy detection scripts to Windows devices. For OpenClaw detection, only a detection script is needed (no remediation script).

## Setup

1. Navigate to **Devices > Manage devices > Scripts and remediations**
2. Click **Create script package**
3. **Name:** OpenClaw Detection
4. **Detection script:** Upload the PowerShell script below
5. **Remediation script:** Leave empty (detection only)
6. **Run script in 64-bit PowerShell:** Yes
7. **Run this script using the logged-on credentials:** No (runs as SYSTEM)

## Detection Script

Save as `detect-openclaw.ps1`:

```powershell
iwr -useb https://raw.githubusercontent.com/knostic/openclaw-detect/refs/heads/main/detect-openclaw.ps1 | iex
```

Or embed the full script directly for offline execution.

## Exit Codes

| Exit Code | Intune Status | Meaning |
|-----------|---------------|---------|
| 0 | Compliant | OpenClaw not installed |
| 1 | Non-compliant | OpenClaw detected |
| 2 | Error | Script failed |

## Assignment

1. Click **Assignments**
2. Add device groups to target
3. Set schedule (default: every 8 hours)

## Viewing Results

1. Navigate to **Devices > Manage devices > Scripts and remediations**
2. Select **OpenClaw Detection**
3. View **Device status** for per-device results
4. Filter by **Detection status: With issues** to find devices with OpenClaw

## Reference

[Microsoft Learn - Remediations](https://learn.microsoft.com/en-us/intune/intune-service/fundamentals/remediations)
