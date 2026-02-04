# VMware Workspace ONE UEM Integration

Workspace ONE UEM supports custom scripts for macOS devices through the Scripts feature.

## Add the Script

1. Navigate to **Resources > Scripts**
2. Click **Add > macOS**
3. **Name:** OpenClaw Detection
4. **Language:** Bash
5. **Script:**
   ```bash
   #!/bin/bash
   curl -sL https://raw.githubusercontent.com/knostic/openclaw-detect/refs/heads/main/detect-openclaw.sh | bash
   ```
6. **Execution Context:** System (to scan all users)
7. **Timeout:** 120 seconds
8. Click **Save**

## Supported Languages

- Bash
- Python 3
- Zsh

## Exit Codes

| Exit Code | Workspace ONE Status | Meaning |
|-----------|---------------------|---------|
| 0 | Success | OpenClaw not installed |
| Non-zero | Failed | OpenClaw detected or error |

## Assignment

1. Navigate to **Resources > Scripts**
2. Select **OpenClaw Detection**
3. Click **Assignment**
4. Add Smart Groups to target
5. Configure execution schedule
6. Click **Save**

## Viewing Results

1. Navigate to **Resources > Scripts**
2. Select **OpenClaw Detection**
3. Click **Devices** tab
4. Review execution status and output per device
5. Filter by **Status: Failed** to find devices with OpenClaw

## Smart Group for Compliance

Create a Smart Group based on script execution status to track devices where OpenClaw was detected.

## Reference

[VMware Docs - Automate Scripts on macOS Devices](https://docs.vmware.com/en/VMware-Workspace-ONE-UEM/2206/macOS_Platform/GUID-AutomateScriptsmacOSDevices.html)
