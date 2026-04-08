#!/usr/bin/env bats
# Tests for remove-openclaw.sh
#
# Uses OPENCLAW_PROFILE=batstest for isolation so planted artifacts
# live under ~/.openclaw-batstest/ instead of the default location.

SCRIPT="$BATS_TEST_DIRNAME/../remove-openclaw.sh"
DETECT_SCRIPT="$BATS_TEST_DIRNAME/../detect-openclaw.sh"
PROFILE="batstest"
STATE_DIR="$HOME/.openclaw-${PROFILE}"
LOCAL_BIN="$HOME/.local/bin"
FAKE_BINARY="$LOCAL_BIN/openclaw"

# -- helpers --------------------------------------------------------------

plant_artifacts() {
  mkdir -p "$STATE_DIR"
  printf '{"port": 18789, "version": "0.99.0-fake"}\n' > "$STATE_DIR/openclaw.json"
  printf 'fake gateway binary\n' > "$STATE_DIR/gateway"
  chmod +x "$STATE_DIR/gateway"

  mkdir -p "$LOCAL_BIN"
  printf '#!/bin/sh\necho "fake openclaw"\n' > "$FAKE_BINARY"
  chmod +x "$FAKE_BINARY"
}

skip_if_real_openclaw() {
  if [[ -d "$HOME/.openclaw" ]]; then
    skip "Real OpenClaw state dir exists -- skipping to avoid interference"
  fi
  if command -v openclaw &>/dev/null; then
    skip "Real openclaw binary in PATH -- skipping to avoid interference"
  fi
}

# -- setup / teardown -----------------------------------------------------

setup() {
  rm -rf "$STATE_DIR"
  rm -f "$FAKE_BINARY"
}

teardown() {
  rm -rf "$STATE_DIR"
  rm -f "$FAKE_BINARY"
}

# =========================================================================
# Clean machine tests
# =========================================================================

@test "clean machine: exits 0" {
  run env OPENCLAW_PROFILE="$PROFILE" bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "clean machine: reports nothing-to-remove" {
  run env OPENCLAW_PROFILE="$PROFILE" bash "$SCRIPT"
  [[ "$output" == *"result: nothing-to-remove"* ]]
}

@test "clean machine: reports platform" {
  run env OPENCLAW_PROFILE="$PROFILE" bash "$SCRIPT"
  [[ "$output" == *"platform: "* ]]
}

@test "clean machine: shows banner" {
  run env OPENCLAW_PROFILE="$PROFILE" bash "$SCRIPT"
  [[ "$output" == *"Knostic"* ]]
  [[ "$output" == *"Removal Script"* ]]
}

# =========================================================================
# Profile validation (security)
# =========================================================================

@test "invalid profile with path traversal: exits 2" {
  run env OPENCLAW_PROFILE="../etc/passwd" bash "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"result: error"* ]]
  [[ "$output" == *"invalid OPENCLAW_PROFILE"* ]]
}

@test "invalid profile with spaces: exits 2" {
  run env OPENCLAW_PROFILE="bad profile" bash "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "invalid profile with shell metacharacters: exits 2" {
  run env OPENCLAW_PROFILE='test;rm -rf /' bash "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "valid profile with alphanumeric and hyphens: exits 0" {
  run env OPENCLAW_PROFILE="my-test_profile123" bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "empty profile (default): exits 0" {
  run env OPENCLAW_PROFILE="" bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

# =========================================================================
# Planted artifact removal
# =========================================================================

@test "removal: cleans state directory" {
  skip_if_real_openclaw
  plant_artifacts
  [ -d "$STATE_DIR" ]

  run env OPENCLAW_PROFILE="$PROFILE" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ ! -d "$STATE_DIR" ]
}

@test "removal: cleans binary" {
  skip_if_real_openclaw
  plant_artifacts
  [ -x "$FAKE_BINARY" ]

  run env OPENCLAW_PROFILE="$PROFILE" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ ! -f "$FAKE_BINARY" ]
}

@test "removal: reports all-removed" {
  skip_if_real_openclaw
  plant_artifacts

  run env OPENCLAW_PROFILE="$PROFILE" bash "$SCRIPT"
  [[ "$output" == *"result: all-removed"* ]]
}

@test "removal: output contains removed lines" {
  skip_if_real_openclaw
  plant_artifacts

  run env OPENCLAW_PROFILE="$PROFILE" bash "$SCRIPT"
  [[ "$output" == *"removed:"* ]]
}

# =========================================================================
# Dry-run mode
# =========================================================================

@test "dry-run: preserves state directory" {
  skip_if_real_openclaw
  plant_artifacts

  run env OPENCLAW_PROFILE="$PROFILE" OPENCLAW_DRY_RUN=1 bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -d "$STATE_DIR" ]
}

@test "dry-run: preserves binary" {
  skip_if_real_openclaw
  plant_artifacts

  run env OPENCLAW_PROFILE="$PROFILE" OPENCLAW_DRY_RUN=1 bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -x "$FAKE_BINARY" ]
}

@test "dry-run: reports mode in output" {
  skip_if_real_openclaw
  plant_artifacts

  run env OPENCLAW_PROFILE="$PROFILE" OPENCLAW_DRY_RUN=1 bash "$SCRIPT"
  [[ "$output" == *"mode: dry-run"* ]]
}

@test "dry-run: logs dry-run actions" {
  skip_if_real_openclaw
  plant_artifacts

  run env OPENCLAW_PROFILE="$PROFILE" OPENCLAW_DRY_RUN=1 bash "$SCRIPT"
  [[ "$output" == *"dry-run:"* ]]
}

# =========================================================================
# Keep-data mode
# =========================================================================

@test "keep-data: preserves state directory" {
  skip_if_real_openclaw
  plant_artifacts

  run env OPENCLAW_PROFILE="$PROFILE" OPENCLAW_KEEP_DATA=1 bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -d "$STATE_DIR" ]
}

@test "keep-data: removes binary" {
  skip_if_real_openclaw
  plant_artifacts

  run env OPENCLAW_PROFILE="$PROFILE" OPENCLAW_KEEP_DATA=1 bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ ! -f "$FAKE_BINARY" ]
}

@test "keep-data: reports keep-data in output" {
  skip_if_real_openclaw
  plant_artifacts

  run env OPENCLAW_PROFILE="$PROFILE" OPENCLAW_KEEP_DATA=1 bash "$SCRIPT"
  [[ "$output" == *"keep-data: true"* ]]
}

@test "keep-data: reports skipped state dir" {
  skip_if_real_openclaw
  plant_artifacts

  run env OPENCLAW_PROFILE="$PROFILE" OPENCLAW_KEEP_DATA=1 bash "$SCRIPT"
  [[ "$output" == *"skipped-state-dir:"* ]]
}

# =========================================================================
# Idempotency
# =========================================================================

@test "idempotent: second removal succeeds" {
  skip_if_real_openclaw
  plant_artifacts

  run env OPENCLAW_PROFILE="$PROFILE" bash "$SCRIPT"
  [ "$status" -eq 0 ]

  run env OPENCLAW_PROFILE="$PROFILE" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"result: nothing-to-remove"* ]]
}

# =========================================================================
# Detect -> Remove -> Detect cycle
# =========================================================================

@test "full cycle: detect finds artifacts, removal cleans, detect confirms clean" {
  skip_if_real_openclaw
  plant_artifacts

  # detect should find planted artifacts (exit 1)
  run env OPENCLAW_PROFILE="$PROFILE" bash "$DETECT_SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"installed"* ]]

  # remove
  run env OPENCLAW_PROFILE="$PROFILE" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"result: all-removed"* ]]

  # detect should report clean (exit 0)
  run env OPENCLAW_PROFILE="$PROFILE" bash "$DETECT_SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"summary: not-installed"* ]]
}

# =========================================================================
# Script content validation (security / correctness)
# =========================================================================

@test "script: contains exit codes 0, 1, 2" {
  grep -q 'exit 0' "$SCRIPT"
  grep -q 'exit 1' "$SCRIPT"
  grep -q 'exit 2' "$SCRIPT"
}

@test "script: validates OPENCLAW_PROFILE with strict regex" {
  grep -q '\^.A-Za-z0-9_-.' "$SCRIPT"
}

@test "script: no dangerous rm -rf / pattern" {
  # rm -rf /Applications is allowed; rm -rf / alone is not
  ! grep -E 'rm -rf /[^A-Za-z]' "$SCRIPT"
}

@test "script: no rm -rf with wildcards" {
  ! grep -q 'rm -rf \*' "$SCRIPT"
}

@test "script: has dry-run support" {
  grep -q 'DRY_RUN' "$SCRIPT"
  grep -q 'do_or_dry' "$SCRIPT"
}

@test "script: has keep-data support" {
  grep -q 'KEEP_DATA' "$SCRIPT"
  grep -q 'skipped-state-dir' "$SCRIPT"
}

@test "script: checks brew" {
  grep -q 'brew uninstall' "$SCRIPT"
}

@test "script: checks npm" {
  grep -q 'npm uninstall' "$SCRIPT"
}

@test "script: kills gateway by port" {
  grep -q 'lsof' "$SCRIPT" || grep -q 'fuser' "$SCRIPT"
}

@test "script: handles launchd on darwin" {
  grep -q 'launchctl bootout' "$SCRIPT"
}

@test "script: handles systemd on linux" {
  grep -q 'systemctl --user' "$SCRIPT"
}
