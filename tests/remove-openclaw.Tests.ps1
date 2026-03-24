# Pester tests for remove-openclaw.ps1
#
# Uses OPENCLAW_PROFILE=pestertest for isolation so planted artifacts
# live under ~\.openclaw-pestertest\ instead of the default location.

$Script = Join-Path $PSScriptRoot "..\remove-openclaw.ps1"
$DetectScript = Join-Path $PSScriptRoot "..\detect-openclaw.ps1"
$Profile = "pestertest"
$HomeDir = $env:USERPROFILE
$StateDir = Join-Path $HomeDir ".openclaw-$Profile"
$LocalPrograms = Join-Path $HomeDir "AppData\Local\Programs\openclaw"
$FakeBinary = Join-Path $LocalPrograms "openclaw.exe"

# -- helpers --------------------------------------------------------------

function Plant-Artifacts {
    New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
    '{"port": 18789, "version": "0.99.0-fake"}' | Set-Content (Join-Path $StateDir "openclaw.json")
    'fake gateway' | Set-Content (Join-Path $StateDir "gateway")

    New-Item -ItemType Directory -Path $LocalPrograms -Force | Out-Null
    'fake openclaw binary' | Set-Content $FakeBinary
}

function Remove-PlantedArtifacts {
    if (Test-Path $StateDir) { Remove-Item $StateDir -Recurse -Force -ErrorAction SilentlyContinue }
    if (Test-Path $FakeBinary) { Remove-Item $FakeBinary -Force -ErrorAction SilentlyContinue }
}

function Test-RealOpenClaw {
    $realState = Join-Path $HomeDir ".openclaw"
    if (Test-Path $realState) { return $true }
    if (Get-Command openclaw -ErrorAction SilentlyContinue) { return $true }
    return $false
}

function Invoke-RemovalScript {
    param([hashtable]$EnvOverrides = @{})

    $savedEnv = @{}
    foreach ($key in $EnvOverrides.Keys) {
        $savedEnv[$key] = [Environment]::GetEnvironmentVariable($key, "Process")
        [Environment]::SetEnvironmentVariable($key, $EnvOverrides[$key], "Process")
    }

    try {
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $Script 2>&1
        $exitCode = $LASTEXITCODE
        return @{ Output = ($output | Out-String); ExitCode = $exitCode }
    } finally {
        foreach ($key in $savedEnv.Keys) {
            [Environment]::SetEnvironmentVariable($key, $savedEnv[$key], "Process")
        }
    }
}

function Invoke-DetectScript {
    param([hashtable]$EnvOverrides = @{})

    $savedEnv = @{}
    foreach ($key in $EnvOverrides.Keys) {
        $savedEnv[$key] = [Environment]::GetEnvironmentVariable($key, "Process")
        [Environment]::SetEnvironmentVariable($key, $EnvOverrides[$key], "Process")
    }

    try {
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $DetectScript 2>&1
        $exitCode = $LASTEXITCODE
        return @{ Output = ($output | Out-String); ExitCode = $exitCode }
    } finally {
        foreach ($key in $savedEnv.Keys) {
            [Environment]::SetEnvironmentVariable($key, $savedEnv[$key], "Process")
        }
    }
}

# -- tests ----------------------------------------------------------------

Describe "remove-openclaw.ps1" {

    BeforeEach {
        Remove-PlantedArtifacts
    }

    AfterEach {
        Remove-PlantedArtifacts
    }

    # =====================================================================
    # Clean machine tests
    # =====================================================================

    Context "Clean machine" {
        It "exits 0" {
            $r = Invoke-RemovalScript @{ OPENCLAW_PROFILE = $Profile }
            $r.ExitCode | Should -Be 0
        }

        It "reports nothing-to-remove" {
            $r = Invoke-RemovalScript @{ OPENCLAW_PROFILE = $Profile }
            $r.Output | Should -Match "result: nothing-to-remove"
        }

        It "reports platform as windows" {
            $r = Invoke-RemovalScript @{ OPENCLAW_PROFILE = $Profile }
            $r.Output | Should -Match "platform: windows"
        }

        It "shows banner" {
            $r = Invoke-RemovalScript @{ OPENCLAW_PROFILE = $Profile }
            $r.Output | Should -Match "Knostic"
            $r.Output | Should -Match "Removal Script"
        }
    }

    # =====================================================================
    # Profile validation
    # =====================================================================

    Context "Profile validation" {
        It "rejects path traversal" {
            $r = Invoke-RemovalScript @{ OPENCLAW_PROFILE = "..\etc\passwd" }
            $r.ExitCode | Should -Be 2
            $r.Output | Should -Match "result: error"
            $r.Output | Should -Match "invalid OPENCLAW_PROFILE"
        }

        It "rejects spaces" {
            $r = Invoke-RemovalScript @{ OPENCLAW_PROFILE = "bad profile" }
            $r.ExitCode | Should -Be 2
        }

        It "rejects shell metacharacters" {
            $r = Invoke-RemovalScript @{ OPENCLAW_PROFILE = "test;rm -rf /" }
            $r.ExitCode | Should -Be 2
        }

        It "accepts alphanumeric with hyphens and underscores" {
            $r = Invoke-RemovalScript @{ OPENCLAW_PROFILE = "my-test_profile123" }
            $r.ExitCode | Should -Be 0
        }

        It "accepts empty profile (default)" {
            $r = Invoke-RemovalScript @{ OPENCLAW_PROFILE = "" }
            $r.ExitCode | Should -Be 0
        }
    }

    # =====================================================================
    # Planted artifact removal
    # =====================================================================

    Context "Planted artifacts" {
        BeforeEach {
            if (Test-RealOpenClaw) { Set-ItResult -Skipped -Because "Real OpenClaw present" }
            Plant-Artifacts
        }

        It "removes state directory" {
            Test-Path $StateDir | Should -Be $true
            $r = Invoke-RemovalScript @{ OPENCLAW_PROFILE = $Profile }
            $r.ExitCode | Should -Be 0
            Test-Path $StateDir | Should -Be $false
        }

        It "removes binary" {
            Test-Path $FakeBinary | Should -Be $true
            $r = Invoke-RemovalScript @{ OPENCLAW_PROFILE = $Profile }
            $r.ExitCode | Should -Be 0
            Test-Path $FakeBinary | Should -Be $false
        }

        It "reports all-removed" {
            $r = Invoke-RemovalScript @{ OPENCLAW_PROFILE = $Profile }
            $r.Output | Should -Match "result: all-removed"
        }

        It "output contains removed lines" {
            $r = Invoke-RemovalScript @{ OPENCLAW_PROFILE = $Profile }
            $r.Output | Should -Match "removed:"
        }
    }

    # =====================================================================
    # Dry-run mode
    # =====================================================================

    Context "Dry-run mode" {
        BeforeEach {
            if (Test-RealOpenClaw) { Set-ItResult -Skipped -Because "Real OpenClaw present" }
            Plant-Artifacts
        }

        It "preserves state directory" {
            $r = Invoke-RemovalScript @{ OPENCLAW_PROFILE = $Profile; OPENCLAW_DRY_RUN = "1" }
            $r.ExitCode | Should -Be 0
            Test-Path $StateDir | Should -Be $true
        }

        It "preserves binary" {
            $r = Invoke-RemovalScript @{ OPENCLAW_PROFILE = $Profile; OPENCLAW_DRY_RUN = "1" }
            $r.ExitCode | Should -Be 0
            Test-Path $FakeBinary | Should -Be $true
        }

        It "reports dry-run mode" {
            $r = Invoke-RemovalScript @{ OPENCLAW_PROFILE = $Profile; OPENCLAW_DRY_RUN = "1" }
            $r.Output | Should -Match "mode: dry-run"
        }

        It "logs dry-run actions" {
            $r = Invoke-RemovalScript @{ OPENCLAW_PROFILE = $Profile; OPENCLAW_DRY_RUN = "1" }
            $r.Output | Should -Match "dry-run:"
        }
    }

    # =====================================================================
    # Keep-data mode
    # =====================================================================

    Context "Keep-data mode" {
        BeforeEach {
            if (Test-RealOpenClaw) { Set-ItResult -Skipped -Because "Real OpenClaw present" }
            Plant-Artifacts
        }

        It "preserves state directory" {
            $r = Invoke-RemovalScript @{ OPENCLAW_PROFILE = $Profile; OPENCLAW_KEEP_DATA = "1" }
            $r.ExitCode | Should -Be 0
            Test-Path $StateDir | Should -Be $true
        }

        It "removes binary" {
            $r = Invoke-RemovalScript @{ OPENCLAW_PROFILE = $Profile; OPENCLAW_KEEP_DATA = "1" }
            $r.ExitCode | Should -Be 0
            Test-Path $FakeBinary | Should -Be $false
        }

        It "reports keep-data in output" {
            $r = Invoke-RemovalScript @{ OPENCLAW_PROFILE = $Profile; OPENCLAW_KEEP_DATA = "1" }
            $r.Output | Should -Match "keep-data: true"
        }

        It "reports skipped state dir" {
            $r = Invoke-RemovalScript @{ OPENCLAW_PROFILE = $Profile; OPENCLAW_KEEP_DATA = "1" }
            $r.Output | Should -Match "skipped-state-dir:"
        }
    }

    # =====================================================================
    # Idempotency
    # =====================================================================

    Context "Idempotency" {
        BeforeEach {
            if (Test-RealOpenClaw) { Set-ItResult -Skipped -Because "Real OpenClaw present" }
            Plant-Artifacts
        }

        It "second removal succeeds with nothing-to-remove" {
            $r1 = Invoke-RemovalScript @{ OPENCLAW_PROFILE = $Profile }
            $r1.ExitCode | Should -Be 0

            $r2 = Invoke-RemovalScript @{ OPENCLAW_PROFILE = $Profile }
            $r2.ExitCode | Should -Be 0
            $r2.Output | Should -Match "result: nothing-to-remove"
        }
    }

    # =====================================================================
    # Detect -> Remove -> Detect cycle
    # =====================================================================

    Context "Full cycle" {
        BeforeEach {
            if (Test-RealOpenClaw) { Set-ItResult -Skipped -Because "Real OpenClaw present" }
            Plant-Artifacts
        }

        It "detect finds artifacts, removal cleans, detect confirms clean" {
            $detect1 = Invoke-DetectScript @{ OPENCLAW_PROFILE = $Profile }
            $detect1.ExitCode | Should -Be 1

            $remove = Invoke-RemovalScript @{ OPENCLAW_PROFILE = $Profile }
            $remove.ExitCode | Should -Be 0
            $remove.Output | Should -Match "result: all-removed"

            $detect2 = Invoke-DetectScript @{ OPENCLAW_PROFILE = $Profile }
            $detect2.ExitCode | Should -Be 0
            $detect2.Output | Should -Match "summary: not-installed"
        }
    }

    # =====================================================================
    # Script content validation
    # =====================================================================

    Context "Script content" {
        $scriptContent = Get-Content $Script -Raw

        It "contains exit codes 0, 1, 2" {
            $scriptContent | Should -Match "exit 0"
            $scriptContent | Should -Match "exit 1"
            $scriptContent | Should -Match "exit 2"
        }

        It "validates OPENCLAW_PROFILE with strict regex" {
            $scriptContent | Should -Match "\[A-Za-z0-9_-\]"
        }

        It "has dry-run support" {
            $scriptContent | Should -Match "DryRun"
            $scriptContent | Should -Match "dry-run"
        }

        It "has keep-data support" {
            $scriptContent | Should -Match "KeepData"
            $scriptContent | Should -Match "skipped-state-dir"
        }

        It "has Remove-Item for file removal" {
            $scriptContent | Should -Match "Remove-Item"
        }

        It "checks scoop" {
            $scriptContent | Should -Match "scoop uninstall"
        }

        It "checks npm" {
            $scriptContent | Should -Match "npm uninstall"
        }

        It "checks winget" {
            $scriptContent | Should -Match "winget uninstall"
        }

        It "kills gateway by port" {
            $scriptContent | Should -Match "Stop-Process"
        }

        It "handles scheduled tasks" {
            $scriptContent | Should -Match "Unregister-ScheduledTask"
        }

        It "handles WSL" {
            $scriptContent | Should -Match "Remove-WslOpenclaw"
        }

        It "no dangerous Remove-Item on root" {
            $scriptContent | Should -Not -Match 'Remove-Item.*-Path\s+"?C:\\["\s]'
        }
    }
}
