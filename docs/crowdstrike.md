# CrowdStrike Falcon Integration

CrowdStrike Falcon Real Time Response (RTR) allows you to run custom scripts on managed endpoints. You can execute scripts on-demand via RTR sessions or automate detection using Falcon Fusion workflows.

## Add a Custom Script

1. Navigate to **Host setup and management > Response scripts and files > Scripts**
2. Click **+ Add script**
3. Fill out the fields:
   - **Name:** OpenClaw Detection
   - **Description:** Detects OpenClaw installations on endpoints
   - **Permission:** Select appropriate RTR role (Responder, Active Responder, or Administrator)
   - **Script type:** Choose based on target OS:
     - **Bash** for Linux
     - **Zsh** for macOS
     - **PowerShell** for Windows
4. Paste the script content:

**macOS/Linux (Bash/Zsh):**
```bash
curl -sL https://raw.githubusercontent.com/knostic/openclaw-detect/refs/heads/main/detect-openclaw.sh | bash
```

**Windows (PowerShell):**
```powershell
iwr -useb https://raw.githubusercontent.com/knostic/openclaw-detect/refs/heads/main/detect-openclaw.ps1 | iex
```

5. Click **Save**

## Run Script via RTR Session

1. Navigate to **Hosts > Host management**
2. Select the target host(s)
3. Click **Connect** to start an RTR session
4. Run the script:
   ```
   runscript -CloudFile="OpenClaw Detection"
   ```
5. View the output in the session terminal

## Run Script via API

Using [PSFalcon](https://github.com/CrowdStrike/psfalcon) (PowerShell):

```powershell
# Authenticate
Request-FalconToken -ClientId 'YOUR_CLIENT_ID' -ClientSecret 'YOUR_CLIENT_SECRET'

# Run on specific hosts
Invoke-FalconRtr -Command runscript -Argument '-CloudFile="OpenClaw Detection"' -HostId @('host_id_1', 'host_id_2')

# Run on a host group
$hosts = Get-FalconHost -Filter "groups:['group_id']"
Invoke-FalconRtr -Command runscript -Argument '-CloudFile="OpenClaw Detection"' -HostId $hosts.device_id
```

Using [FalconPy](https://github.com/CrowdStrike/falconpy) (Python):

```python
from falconpy import RealTimeResponse, RealTimeResponseAdmin

falcon = RealTimeResponseAdmin(client_id="YOUR_CLIENT_ID", client_secret="YOUR_CLIENT_SECRET")

# Initialize RTR session
session = falcon.init_session(device_id="host_id")
session_id = session["body"]["resources"][0]["session_id"]

# Execute the script
response = falcon.execute_admin_command(
    base_command="runscript",
    command_string='runscript -CloudFile="OpenClaw Detection"',
    session_id=session_id
)
```

## Automate with Falcon Fusion

Create a Fusion workflow to run the detection script on a schedule or in response to events:

1. Navigate to **Endpoint security > Fusion SOAR > Workflows**
2. Click **Create workflow**
3. Add a trigger (scheduled or event-based)
4. Add action: **Real Time Response > Run script**
5. Select **OpenClaw Detection** script
6. Configure target hosts or groups
7. Save and enable the workflow

## Exit Codes

| Exit Code | Meaning | Action |
|-----------|---------|--------|
| 0 | OpenClaw NOT installed | No action needed |
| 1 | OpenClaw detected | Review host, consider remediation |
| 2 | Script error | Investigate RTR connectivity |

## Viewing Results

- **RTR Sessions:** View output directly in the session terminal
- **Audit logs:** Navigate to **Activity > Audit logs** to review script executions
- **Fusion workflows:** Check workflow execution history for automated runs

## Reference

- [Real Time Response](https://falcon.crowdstrike.com/documentation/page/c4c1e3b8/real-time-response)
- [Falcon Fusion](https://falcon.crowdstrike.com/documentation/page/d4d1e3b8/falcon-fusion)
- [PSFalcon](https://github.com/CrowdStrike/psfalcon)
- [FalconPy](https://github.com/CrowdStrike/falconpy)
