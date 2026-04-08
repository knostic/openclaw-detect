# OpenClaw Removal Script for MDM deployment (Windows)
# Exit codes: 0=all-removed/nothing-to-remove, 1=partial, 2=error

$ErrorActionPreference = "Stop"

$script:Profile = $env:OPENCLAW_PROFILE
$Port = if ($env:OPENCLAW_GATEWAY_PORT) { [int]$env:OPENCLAW_GATEWAY_PORT } else { 18789 }
$script:KeepData = if ($env:OPENCLAW_KEEP_DATA) { $env:OPENCLAW_KEEP_DATA } else { "0" }
$script:DryRun = if ($env:OPENCLAW_DRY_RUN) { $env:OPENCLAW_DRY_RUN } else { "0" }

if ($script:Profile -and $script:Profile -notmatch '^[A-Za-z0-9_-]{1,64}$') {
    Write-Output "result: error"
    Write-Output "error-detail: invalid OPENCLAW_PROFILE value"
    exit 2
}

$script:RemovedCount = 0
$script:SkippedCount = 0
$script:ErrorCount = 0
$script:Output = [System.Collections.ArrayList]::new()

function Show-Banner {
    $banner = @"

  _  ___  _  ___  ___  _____ ___ ___
 | |/ / \| |/ _ \/ __|_   _|_ _/ __|
 | ' <| .  | (_) \__ \ | |  | | (__
 |_|\_\_|\_|\___/|___/ |_| |___\___|

 Open source from Knostic - https://knostic.ai
 OpenClaw Removal Script

"@
    Write-Output $banner
}

Show-Banner

function Out {
    param([string]$Line)
    [void]$script:Output.Add($Line)
}

function Invoke-OrDry {
    param([string]$Description, [scriptblock]$Action)
    if ($script:DryRun -eq "1") {
        Out "dry-run: $Description"
        $script:SkippedCount++
        return $true
    }
    try {
        & $Action 2>$null
        Out "removed: $Description"
        $script:RemovedCount++
        return $true
    } catch {
        Out "error: $Description"
        $script:ErrorCount++
        return $false
    }
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-UsersToCheck {
    if (Test-IsAdmin) {
        Get-ChildItem "C:\Users" -Directory |
            Where-Object { $_.Name -notin @('Public', 'Default', 'Default User', 'All Users') } |
            ForEach-Object { $_.Name }
    } else {
        $env:USERNAME
    }
}

function Get-HomeDir {
    param([string]$User)
    return "C:\Users\$User"
}

function Get-StateDir {
    param([string]$HomeDir)
    if ($script:Profile) {
        return Join-Path $HomeDir ".openclaw-$($script:Profile)"
    }
    return Join-Path $HomeDir ".openclaw"
}

function Get-ConfiguredPort {
    param([string]$ConfigFile)
    if (Test-Path $ConfigFile) {
        try {
            $content = Get-Content $ConfigFile -Raw
            if ($content -match '"port"\s*:\s*(\d+)') {
                return [int]$matches[1]
            }
        } catch {}
    }
    return $null
}

# -- Scheduled task removal -----------------------------------------------

function Remove-OpenClawScheduledTask {
    $taskName = if ($script:Profile) { "OpenClaw Gateway $($script:Profile)" } else { "OpenClaw Gateway" }
    try {
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($task) {
            Invoke-OrDry "scheduled task '$taskName'" {
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
            }
        }
    } catch {}
}

# -- Kill gateway process on port -----------------------------------------

function Stop-GatewayOnPort {
    param([int]$PortNum)
    try {
        $connections = Get-NetTCPConnection -LocalPort $PortNum -ErrorAction SilentlyContinue
        foreach ($conn in $connections) {
            if ($conn.OwningProcess -and $conn.OwningProcess -ne 0) {
                Invoke-OrDry "kill gateway pid=$($conn.OwningProcess) on port $PortNum" {
                    Stop-Process -Id $conn.OwningProcess -Force -ErrorAction SilentlyContinue
                }
            }
        }
    } catch {}
}

# -- Docker removal -------------------------------------------------------

function Remove-DockerContainers {
    try {
        if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { return }
        $ids = docker ps --filter "name=openclaw" -q 2>$null
        foreach ($cid in $ids) {
            if ($cid) {
                Invoke-OrDry "docker container $cid" {
                    docker stop $cid 2>$null
                    docker rm $cid 2>$null
                }
            }
        }
    } catch {}
}

function Remove-DockerImages {
    try {
        if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { return }
        $ids = docker images --filter "reference=*openclaw*" -q 2>$null
        foreach ($iid in $ids) {
            if ($iid) {
                Invoke-OrDry "docker image $iid" {
                    docker rmi $iid 2>$null
                }
            }
        }
    } catch {}
}

# -- Package manager uninstall --------------------------------------------

function Uninstall-ViaPackageManagers {
    try {
        if ((Get-Command scoop -ErrorAction SilentlyContinue) -and (scoop list 2>$null | Select-String "openclaw")) {
            Invoke-OrDry "scoop uninstall openclaw" { scoop uninstall openclaw 2>$null }
        }
    } catch {}
    try {
        if ((Get-Command npm -ErrorAction SilentlyContinue) -and (npm ls -g openclaw --depth=0 2>$null | Select-String "openclaw")) {
            Invoke-OrDry "npm uninstall -g openclaw" { npm uninstall -g openclaw 2>$null }
        }
    } catch {}
    try {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            $found = winget list openclaw 2>$null | Select-String "openclaw"
            if ($found) {
                Invoke-OrDry "winget uninstall openclaw" { winget uninstall openclaw --silent 2>$null }
            }
        }
    } catch {}
}

# -- Binary removal -------------------------------------------------------

function Remove-CliBinary {
    param([string]$Path)
    if (Test-Path $Path) {
        Invoke-OrDry "binary $Path" { Remove-Item -Path $Path -Force }
    }
}

function Remove-CliBinariesGlobal {
    $locations = @(
        "C:\Program Files\openclaw\openclaw.exe",
        "C:\Program Files (x86)\openclaw\openclaw.exe"
    )
    foreach ($loc in $locations) {
        Remove-CliBinary $loc
    }
}

function Remove-CliBinariesUser {
    param([string]$HomeDir)
    $locations = @(
        (Join-Path $HomeDir "AppData\Local\Programs\openclaw\openclaw.exe"),
        (Join-Path $HomeDir "AppData\Roaming\npm\openclaw.cmd"),
        (Join-Path $HomeDir "AppData\Local\pnpm\openclaw.cmd"),
        (Join-Path $HomeDir ".volta\bin\openclaw.exe"),
        (Join-Path $HomeDir "scoop\shims\openclaw.exe")
    )
    foreach ($loc in $locations) {
        Remove-CliBinary $loc
    }
}

# -- State directory removal ----------------------------------------------

function Remove-StateDir {
    param([string]$StateDir)
    if (-not (Test-Path $StateDir -PathType Container)) { return }
    if ($script:KeepData -eq "1") {
        Out "skipped-state-dir: $StateDir"
        $script:SkippedCount++
        return
    }
    Invoke-OrDry "state-dir $StateDir" { Remove-Item -Path $StateDir -Recurse -Force }
}

# -- WSL removal ----------------------------------------------------------

function Remove-WslOpenclaw {
    try {
        if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) { return }
        $wslPath = (wsl -e which openclaw 2>$null)
        if ($wslPath) {
            $wslPath = $wslPath.Trim()
            Invoke-OrDry "WSL openclaw at $wslPath" {
                wsl -e rm -f -- $wslPath 2>$null
            }
        }
    } catch {}
}

# -- Main -----------------------------------------------------------------

function Main {
    Out "platform: windows"

    if ($script:DryRun -eq "1") { Out "mode: dry-run" }
    if ($script:KeepData -eq "1") { Out "keep-data: true" }

    $users = @(Get-UsersToCheck)
    $portsToCheck = @($Port)

    foreach ($user in $users) {
        $homeDir = Get-HomeDir $user
        $stateDir = Get-StateDir $homeDir
        $configFile = Join-Path $stateDir "openclaw.json"
        $configPort = Get-ConfiguredPort $configFile
        if ($configPort) { $portsToCheck += $configPort }
    }

    # Phase 1: Scheduled tasks
    Remove-OpenClawScheduledTask

    # Phase 2: Kill gateway processes
    $uniquePorts = $portsToCheck | Sort-Object -Unique
    foreach ($p in $uniquePorts) {
        Stop-GatewayOnPort $p
    }

    # Phase 3: Docker
    Remove-DockerContainers
    Remove-DockerImages

    # Phase 4: Package managers
    Uninstall-ViaPackageManagers

    # Phase 5: Binaries
    Remove-CliBinariesGlobal
    foreach ($user in $users) {
        $homeDir = Get-HomeDir $user
        Remove-CliBinariesUser $homeDir
    }

    # Phase 6: State directories
    foreach ($user in $users) {
        $homeDir = Get-HomeDir $user
        $stateDir = Get-StateDir $homeDir
        Remove-StateDir $stateDir
    }

    # Phase 7: WSL
    Remove-WslOpenclaw

    # Also remove CLI found via PATH at unexpected locations
    try {
        $pathCli = (Get-Command openclaw -ErrorAction SilentlyContinue).Source
        if ($pathCli) { Remove-CliBinary $pathCli }
    } catch {}

    # -- Result -------------------------------------------------------------
    $total = $script:RemovedCount + $script:SkippedCount + $script:ErrorCount
    if ($script:ErrorCount -gt 0) {
        Write-Output "result: partial"
        $script:Output | ForEach-Object { Write-Output $_ }
        exit 1
    } elseif ($total -eq 0) {
        Write-Output "result: nothing-to-remove"
        $script:Output | ForEach-Object { Write-Output $_ }
        exit 0
    } else {
        Write-Output "result: all-removed"
        $script:Output | ForEach-Object { Write-Output $_ }
        exit 0
    }
}

try {
    Main
} catch {
    Write-Output "result: error"
    Write-Output "error-detail: $_"
    exit 2
}
