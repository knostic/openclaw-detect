# Kandji Integration

Kandji supports custom scripts through the Custom Scripts library item.

## Add the Script

1. Navigate to **Library > Add New > Custom Scripts**
2. **Name:** OpenClaw Detection
3. **Audit Script:** Paste the script below
4. **Remediation Script:** Leave empty (detection only)
5. Click **Save**

## Audit Script

```bash
#!/bin/bash
curl -sL https://raw.githubusercontent.com/knostic/openclaw-detect/refs/heads/main/detect-openclaw.sh | bash
```

Or embed the full script directly for offline execution.

## Exit Codes

| Exit Code | Kandji Status | Meaning |
|-----------|---------------|---------|
| 0 | Pass | OpenClaw not installed |
| Non-zero | Fail | OpenClaw detected or error |

## Assignment

1. Navigate to **Blueprints**
2. Select the target Blueprint
3. Click **Add Library Item**
4. Select **OpenClaw Detection**
5. Click **Save**

## Viewing Results

1. Navigate to **Devices**
2. Select a device
3. View **Library Items** tab
4. Check status of **OpenClaw Detection**:
   - Pass = OpenClaw not installed
   - Fail = OpenClaw detected

## Device List with OpenClaw

1. Navigate to **Devices**
2. Filter by **Library Item Status: Fail**
3. Select **OpenClaw Detection** from the library item dropdown

## Reference

[Kandji Support - Custom Scripts Overview](https://support.kandji.io/kb/custom-scripts-overview)
