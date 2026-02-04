# OpenClaw Detection Script for MDM deployment (Windows)
# Exit codes: 0=not-installed (clean), 1=found (non-compliant), 2=error

$ErrorActionPreference = "Stop"

$script:Profile = $env:OPENCLAW_PROFILE
$Port = if ($env:OPENCLAW_GATEWAY_PORT) { $env:OPENCLAW_GATEWAY_PORT } else { 18789 }
$script:Output = [System.Collections.ArrayList]::new()

function Show-Banner {
    $banner = @"

  _  ___  _  ___  ___  _____ ___ ___
 | |/ / \| |/ _ \/ __|_   _|_ _/ __|
 | ' <| .  | (_) \__ \ | |  | | (__
 |_|\_\_|\_|\___/|___/ |_| |___\___|

 Open source from Knostic - https://knostic.ai
 OpenClaw Detection Script

"@
    Write-Output $banner
}

Show-Banner

function Out {
    param([string]$Line)
    [void]$script:Output.Add($Line)
}

function Get-StateDir {
    param([string]$HomeDir)
    if ($script:Profile) {
        return Join-Path $HomeDir ".openclaw-$($script:Profile)"
    }
    return Join-Path $HomeDir ".openclaw"
}

function Get-UsersToCheck {
    if ([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544') {
        Get-ChildItem "C:\Users" -Directory | Where-Object { $_.Name -notin @('Public', 'Default', 'Default User', 'All Users') } | ForEach-Object { $_.Name }
    } else {
        $env:USERNAME
    }
}

function Get-HomeDir {
    param([string]$User)
    return "C:\Users\$User"
}

function Test-CliInPath {
    try {
        $cmd = Get-Command openclaw -ErrorAction SilentlyContinue
        if ($cmd) {
            return $cmd.Source
        }
    } catch {}
    return $null
}

function Test-CliGlobal {
    $locations = @(
        "C:\Program Files\openclaw\openclaw.exe",
        "C:\Program Files (x86)\openclaw\openclaw.exe"
    )
    foreach ($loc in $locations) {
        if (Test-Path $loc) {
            return $loc
        }
    }
    return $null
}

function Test-CliForUser {
    param([string]$HomeDir)
    $locations = @(
        (Join-Path $HomeDir "AppData\Local\Programs\openclaw\openclaw.exe"),
        (Join-Path $HomeDir "AppData\Roaming\npm\openclaw.cmd"),
        (Join-Path $HomeDir "AppData\Local\pnpm\openclaw.cmd"),
        (Join-Path $HomeDir ".volta\bin\openclaw.exe"),
        (Join-Path $HomeDir "scoop\shims\openclaw.exe")
    )
    foreach ($loc in $locations) {
        if (Test-Path $loc) {
            return $loc
        }
    }
    return $null
}

function Get-CliVersion {
    param([string]$CliPath)
    try {
        $version = & $CliPath --version 2>$null | Select-Object -First 1
        if ($version) { return $version }
    } catch {}
    return "unknown"
}

function Test-StateDir {
    param([string]$Path)
    return Test-Path $Path -PathType Container
}

function Test-Config {
    param([string]$StateDir)
    return Test-Path (Join-Path $StateDir "openclaw.json") -PathType Leaf
}

function Get-ConfiguredPort {
    param([string]$ConfigFile)
    if (Test-Path $ConfigFile) {
        try {
            $content = Get-Content $ConfigFile -Raw
            if ($content -match '"port"\s*:\s*(\d+)') {
                return $matches[1]
            }
        } catch {}
    }
    return $null
}

function Test-ScheduledTask {
    $taskName = if ($script:Profile) { "OpenClaw Gateway $($script:Profile)" } else { "OpenClaw Gateway" }
    try {
        $null = schtasks /Query /TN $taskName 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $taskName
        }
    } catch {}
    return $null
}

function Test-GatewayPort {
    param([int]$PortNum)
    try {
        $result = Test-NetConnection -ComputerName localhost -Port $PortNum -WarningAction SilentlyContinue
        return $result.TcpTestSucceeded
    } catch {
        return $false
    }
}

function Get-DockerContainers {
    try {
        $cmd = Get-Command docker -ErrorAction SilentlyContinue
        if (-not $cmd) { return $null }
        $containers = docker ps --format '{{.Names}} ({{.Image}})' 2>$null | Select-String -Pattern "openclaw" -SimpleMatch
        if ($containers) {
            return ($containers -join ", ")
        }
    } catch {}
    return $null
}

function Get-DockerImages {
    try {
        $cmd = Get-Command docker -ErrorAction SilentlyContinue
        if (-not $cmd) { return $null }
        $images = docker images --format '{{.Repository}}:{{.Tag}}' 2>$null | Select-String -Pattern "openclaw" -SimpleMatch
        if ($images) {
            return ($images -join ", ")
        }
    } catch {}
    return $null
}

function Main {
    $cliFound = $false
    $stateFound = $false
    $serviceRunning = $false
    $portListening = $false

    Out "platform: windows"

    # check global CLI locations first
    $cliPath = Test-CliInPath
    if (-not $cliPath) { $cliPath = Test-CliGlobal }
    if ($cliPath) {
        $cliFound = $true
        Out "cli: $cliPath"
        Out "cli-version: $(Get-CliVersion $cliPath)"
    }

    $users = @(Get-UsersToCheck)
    $multiUser = $users.Count -gt 1
    $portsToCheck = @($Port)

    foreach ($user in $users) {
        $homeDir = Get-HomeDir $user
        $stateDir = Get-StateDir $homeDir
        $configFile = Join-Path $stateDir "openclaw.json"

        if ($multiUser) {
            Out "user: $user"
            # check user-specific CLI if not already found
            if (-not $cliFound) {
                $userCli = Test-CliForUser $homeDir
                if ($userCli) {
                    $cliFound = $true
                    Out "  cli: $userCli"
                    Out "  cli-version: $(Get-CliVersion $userCli)"
                }
            }
            if (Test-StateDir $stateDir) {
                Out "  state-dir: $stateDir"
                $stateFound = $true
            } else {
                Out "  state-dir: not-found"
            }
            if (Test-Config $stateDir) {
                Out "  config: $configFile"
            } else {
                Out "  config: not-found"
            }
            $configPort = Get-ConfiguredPort $configFile
            if ($configPort) {
                Out "  config-port: $configPort"
                $portsToCheck += [int]$configPort
            }
        } else {
            # single user mode - check user CLI
            if (-not $cliFound) {
                $userCli = Test-CliForUser $homeDir
                if ($userCli) {
                    $cliFound = $true
                    Out "cli: $userCli"
                    Out "cli-version: $(Get-CliVersion $userCli)"
                }
            }
            if (-not $cliFound) {
                Out "cli: not-found"
                Out "cli-version: n/a"
            }
            if (Test-StateDir $stateDir) {
                Out "state-dir: $stateDir"
                $stateFound = $true
            } else {
                Out "state-dir: not-found"
            }
            if (Test-Config $stateDir) {
                Out "config: $configFile"
            } else {
                Out "config: not-found"
            }
            $configPort = Get-ConfiguredPort $configFile
            if ($configPort) {
                Out "config-port: $configPort"
                $portsToCheck += [int]$configPort
            }
        }
    }

    # print cli not-found for multi-user if none found
    if ($multiUser -and -not $cliFound) {
        Out "cli: not-found"
        Out "cli-version: n/a"
    }

    $taskResult = Test-ScheduledTask
    if ($taskResult) {
        Out "gateway-service: $taskResult"
        $serviceRunning = $true
    } else {
        Out "gateway-service: not-scheduled"
    }

    $uniquePorts = $portsToCheck | Sort-Object -Unique
    $listeningPort = $null
    foreach ($p in $uniquePorts) {
        if (Test-GatewayPort $p) {
            $portListening = $true
            $listeningPort = $p
            break
        }
    }
    if ($portListening) {
        Out "gateway-port: $listeningPort"
    } else {
        Out "gateway-port: not-listening"
    }

    $dockerContainers = Get-DockerContainers
    $dockerRunning = $false
    if ($dockerContainers) {
        $dockerRunning = $true
        Out "docker-container: $dockerContainers"
    } else {
        Out "docker-container: not-found"
    }

    $dockerImages = Get-DockerImages
    $dockerInstalled = $false
    if ($dockerImages) {
        $dockerInstalled = $true
        Out "docker-image: $dockerImages"
    } else {
        Out "docker-image: not-found"
    }

    $installed = $cliFound -or $stateFound -or $dockerInstalled
    $running = $serviceRunning -or $portListening -or $dockerRunning

    # exit codes: 0=not-installed (clean), 1=found (non-compliant), 2=error
    if (-not $installed) {
        Write-Output "summary: not-installed"
        $script:Output | ForEach-Object { Write-Output $_ }
        exit 0
    } elseif ($running) {
        Write-Output "summary: installed-and-running"
        $script:Output | ForEach-Object { Write-Output $_ }
        exit 1
    } else {
        Write-Output "summary: installed-not-running"
        $script:Output | ForEach-Object { Write-Output $_ }
        exit 1
    }
}

try {
    Main
} catch {
    Write-Output "summary: error"
    Write-Output "error: $_"
    exit 2
}
