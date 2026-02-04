# Addigy Integration

Addigy allows you to monitor for OpenClaw installations using Custom Facts and Monitoring items.

## Create a Custom Fact

1. Navigate to **Catalog > Custom Facts**
2. Click **New**
3. Fill out the fields:
   - **Name:** OpenClaw Status
   - **Return Type:** String
   - **Description:** Detects OpenClaw installations. Returns `not-installed`, `installed-and-running`, or `installed-not-running`.
   - **Language of Script:** Bash (default hashbang)
   - **Script:**
     ```bash
     OUTPUT=$(curl -sL https://raw.githubusercontent.com/knostic/openclaw-detect/refs/heads/main/detect-openclaw.sh | bash 2>&1)
     echo "$OUTPUT" | head -1 | cut -d: -f2 | tr -d ' '
     ```
4. Click **Save**
5. Assign the fact to a policy containing the devices you want to monitor

The fact will run on the next auditor cycle (~5 minutes) or can be triggered manually via **GoLive > Refresh Data**.

## Create a Monitoring Item

1. Navigate to **Catalog > Monitoring**
2. Click **New**
3. Fill out the fields:
   - **Name:** OpenClaw Detected
   - **Alert Trigger:** Fact `OpenClaw Status` contains `installed`
   - **Category:** Security (or your preferred category)
   - **Send Email:** Add email addresses for notifications
   - **Create Support Ticket:** Enable if you have a ticketing integration configured
   - **Automated Remediation:** Optionally add a script to remove OpenClaw when detected
4. Click **Save**
5. Assign the monitoring item to a policy for deployment

When the alert triggers, it will run the remediation script (if configured). If remediation succeeds, the alert closes automatically. If it fails or is not configured, a notification is sent.

## Viewing Results

Custom Facts appear in the **Devices** table and can be used to filter devices. View the Monitoring dashboard for alert status across your fleet.

## Reference

- [Custom Facts](https://support.addigy.com/hc/en-us/articles/360035658991-Facts)
- [Monitoring](https://support.addigy.com/hc/en-us/articles/360037373251-Monitoring)
