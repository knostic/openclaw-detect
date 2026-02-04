# Jamf Pro Integration

Jamf Pro allows you to deploy scripts to macOS devices via Policies.

## Add the Script

1. Navigate to **Settings > Computer Management > Scripts**
2. Click **New**
3. **Display Name:** OpenClaw Detection
4. **Script:**
   ```bash
   #!/bin/bash
   curl -sL https://raw.githubusercontent.com/knostic/openclaw-detect/refs/heads/main/detect-openclaw.sh | bash
   ```
5. Click **Save**

## Create a Policy

1. Navigate to **Computers > Policies**
2. Click **New**
3. **Display Name:** OpenClaw Detection
4. **Trigger:** Recurring Check-in (or custom trigger)
5. **Execution Frequency:** Once per day / Once per week
6. Go to **Scripts** payload
7. Click **Configure**
8. Add **OpenClaw Detection** script
9. Go to **Scope**
10. Add target computers or groups
11. Click **Save**

## Exit Codes

| Exit Code | Meaning |
|-----------|---------|
| 0 | OpenClaw not installed |
| 1 | OpenClaw detected |
| 2 | Script failed |

## Viewing Results

1. Navigate to **Computers > Policies**
2. Select **OpenClaw Detection**
3. Click **Logs** tab
4. Review script output and exit codes per device

## Smart Group for Detection

Create a Smart Group to identify devices where OpenClaw was found:

1. Navigate to **Computers > Smart Computer Groups**
2. Click **New**
3. **Display Name:** OpenClaw Detected
4. Add criteria: **Policy Failed** is **OpenClaw Detection**

## Reference

[Jamf Pro Documentation - Scripts](https://docs.jamf.com/10.27.0/jamf-pro/administrator-guide/Scripts.html)
