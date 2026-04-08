#!/usr/bin/env bash
# openclaw removal script for mdm deployment
# exit codes: 0=all-removed/nothing-to-remove, 1=partial, 2=error

set -uo pipefail

PROFILE="${OPENCLAW_PROFILE:-}"
PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
KEEP_DATA="${OPENCLAW_KEEP_DATA:-0}"
DRY_RUN="${OPENCLAW_DRY_RUN:-0}"

if [[ -n "$PROFILE" && ! "$PROFILE" =~ ^[A-Za-z0-9_-]{1,64}$ ]]; then
  echo "result: error"
  echo "error-detail: invalid OPENCLAW_PROFILE value"
  exit 2
fi

print_banner() {
  echo ''
  echo '  _  ___  _  ___  ___  _____ ___ ___'
  echo ' | |/ / \| |/ _ \/ __|_   _|_ _/ __|'
  echo ' |   <| .  | (_) \__ \ | |  | | (__ '
  echo ' |_|\_\_|\_|\___/|___/ |_| |___\___|'
  echo ''
  echo ' Open source from Knostic - https://knostic.ai'
  echo ' OpenClaw Removal Script'
  echo ''
}

print_banner

declare -i REMOVED_COUNT=0
declare -i SKIPPED_COUNT=0
declare -i ERROR_COUNT=0
output=""

out() { output+="$1"$'\n'; }

do_or_dry() {
  local description="$1"
  shift
  if [[ "$DRY_RUN" == "1" ]]; then
    out "dry-run: $description"
    ((SKIPPED_COUNT++))
    return 0
  fi
  if "$@" 2>/dev/null; then
    out "removed: $description"
    ((REMOVED_COUNT++))
    return 0
  else
    out "error: $description"
    ((ERROR_COUNT++))
    return 1
  fi
}

detect_platform() {
  case "$(uname -s)" in
    Darwin) echo "darwin" ;;
    Linux)  echo "linux" ;;
    *)      echo "unknown" ;;
  esac
}

get_users_to_check() {
  local platform="$1"
  if [[ $EUID -eq 0 ]]; then
    case "$platform" in
      darwin)
        for dir in /Users/*; do
          [[ -d "$dir" && "$(basename "$dir")" != "Shared" ]] && basename "$dir"
        done
        ;;
      linux)
        for dir in /home/*; do
          [[ -d "$dir" ]] && basename "$dir"
        done
        ;;
    esac
  else
    whoami
  fi
}

get_home_dir() {
  local user="$1" platform="$2"
  case "$platform" in
    darwin) echo "/Users/$user" ;;
    linux)  echo "/home/$user" ;;
  esac
}

get_uid_for_user() {
  id -u "$1" 2>/dev/null || echo ""
}

get_state_dir() {
  local home="$1"
  if [[ -n "$PROFILE" ]]; then
    echo "${home}/.openclaw-${PROFILE}"
  else
    echo "${home}/.openclaw"
  fi
}

get_configured_port() {
  local config_file="$1"
  if [[ -f "$config_file" ]]; then
    # extract port from json without jq (mdm environments may not have it)
    grep -o '"port"[[:space:]]*:[[:space:]]*[0-9]*' "$config_file" 2>/dev/null | head -1 | grep -o '[0-9]*$' || true
  fi
}

# -- Service removal ------------------------------------------------------

remove_launchd_service() {
  local uid="$1" label
  if [[ -n "$PROFILE" ]]; then
    label="bot.molt.${PROFILE}"
  else
    label="bot.molt.gateway"
  fi
  if launchctl print "gui/${uid}/${label}" &>/dev/null; then
    do_or_dry "launchd service gui/${uid}/${label}" launchctl bootout "gui/${uid}/${label}"
  fi
}

remove_systemd_service() {
  local uid="$1" service runtime_dir
  if [[ -n "$PROFILE" ]]; then
    service="openclaw-gateway-${PROFILE}.service"
  else
    service="openclaw-gateway.service"
  fi
  runtime_dir="/run/user/${uid}"
  if [[ -d "$runtime_dir" ]]; then
    if XDG_RUNTIME_DIR="$runtime_dir" systemctl --user is-active "$service" &>/dev/null 2>&1; then
      do_or_dry "systemd service ${service} stop (uid=${uid})" \
        env XDG_RUNTIME_DIR="$runtime_dir" systemctl --user stop "$service"
      do_or_dry "systemd service ${service} disable (uid=${uid})" \
        env XDG_RUNTIME_DIR="$runtime_dir" systemctl --user disable "$service"
    fi
  fi
}

# -- Kill gateway process on port -----------------------------------------

kill_gateway_port() {
  local port="$1"
  local pids
  pids=$(lsof -ti :"$port" 2>/dev/null) || true
  if [[ -z "$pids" ]]; then
    pids=$(fuser "$port/tcp" 2>/dev/null | tr -s ' ') || true
  fi
  if [[ -n "$pids" ]]; then
    for pid in $pids; do
      do_or_dry "kill gateway process pid=$pid on port $port" kill "$pid"
    done
  fi
}

# -- Docker removal -------------------------------------------------------

remove_docker_containers() {
  command -v docker &>/dev/null || return 0
  local ids
  ids=$(docker ps --filter "name=openclaw" -q 2>/dev/null) || true
  if [[ -n "$ids" ]]; then
    for cid in $ids; do
      do_or_dry "docker container $cid" bash -c "docker stop '$cid' && docker rm '$cid'"
    done
  fi
}

remove_docker_images() {
  command -v docker &>/dev/null || return 0
  local ids
  ids=$(docker images --filter "reference=*openclaw*" -q 2>/dev/null) || true
  if [[ -n "$ids" ]]; then
    for iid in $ids; do
      do_or_dry "docker image $iid" docker rmi "$iid"
    done
  fi
}

# -- Package manager uninstall --------------------------------------------

uninstall_via_package_managers() {
  if command -v brew &>/dev/null && brew list openclaw &>/dev/null 2>&1; then
    do_or_dry "brew uninstall openclaw" brew uninstall openclaw
  fi
  if command -v npm &>/dev/null && npm ls -g openclaw --depth=0 &>/dev/null 2>&1; then
    do_or_dry "npm uninstall -g openclaw" npm uninstall -g openclaw
  fi
  if command -v volta &>/dev/null && volta list openclaw 2>/dev/null | grep -q openclaw; then
    do_or_dry "volta uninstall openclaw" volta uninstall openclaw
  fi
}

# -- Binary removal -------------------------------------------------------

remove_binary() {
  local path="$1"
  if [[ -f "$path" || -L "$path" ]]; then
    do_or_dry "binary $path" rm -f "$path"
  fi
}

remove_cli_binaries_global() {
  local locations=(
    "/usr/local/bin/openclaw"
    "/opt/homebrew/bin/openclaw"
    "/usr/bin/openclaw"
  )
  for loc in "${locations[@]}"; do
    remove_binary "$loc"
  done
}

remove_cli_binaries_user() {
  local home="$1"
  local locations=(
    "${home}/.volta/bin/openclaw"
    "${home}/.local/bin/openclaw"
    "${home}/.nvm/current/bin/openclaw"
    "${home}/bin/openclaw"
  )
  for loc in "${locations[@]}"; do
    remove_binary "$loc"
  done
}

# -- App bundle removal (macOS) -------------------------------------------

remove_mac_app() {
  if [[ -d "/Applications/OpenClaw.app" ]]; then
    do_or_dry "macOS app bundle /Applications/OpenClaw.app" rm -rf "/Applications/OpenClaw.app"
  fi
}

# -- State directory removal ----------------------------------------------

remove_state_dir() {
  local state_dir="$1"
  if [[ ! -d "$state_dir" ]]; then
    return 0
  fi
  if [[ "$KEEP_DATA" == "1" ]]; then
    out "skipped-state-dir: $state_dir"
    ((SKIPPED_COUNT++))
    return 0
  fi
  do_or_dry "state-dir $state_dir" rm -rf "$state_dir"
}

# -- Main -----------------------------------------------------------------

main() {
  local platform
  platform=$(detect_platform)
  out "platform: $platform"

  if [[ "$platform" == "unknown" ]]; then
    echo "result: error"
    out "error-detail: unsupported platform"
    printf "%s" "$output"
    exit 2
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    out "mode: dry-run"
  fi
  if [[ "$KEEP_DATA" == "1" ]]; then
    out "keep-data: true"
  fi

  local users
  users=$(get_users_to_check "$platform")

  local ports_to_check="$PORT"
  local uid="" home_dir="" state_dir="" configured_port=""

  # Phase 1: Stop services per user
  for user in $users; do
    uid=$(get_uid_for_user "$user")
    if [[ -n "$uid" ]]; then
      case "$platform" in
        darwin) remove_launchd_service "$uid" ;;
        linux)  remove_systemd_service "$uid" ;;
      esac
    fi

    home_dir=$(get_home_dir "$user" "$platform")
    state_dir=$(get_state_dir "$home_dir")
    configured_port=$(get_configured_port "${state_dir}/openclaw.json")
    if [[ -n "$configured_port" ]]; then
      ports_to_check="$ports_to_check $configured_port"
    fi
  done

  # Phase 2: Kill gateway processes on all discovered ports
  local unique_ports
  unique_ports=$(echo "$ports_to_check" | tr ' ' '\n' | sort -u | tr '\n' ' ')
  for port in $unique_ports; do
    kill_gateway_port "$port"
  done

  # Phase 3: Docker
  remove_docker_containers
  remove_docker_images

  # Phase 4: Package managers
  uninstall_via_package_managers

  # Phase 5: Binary removal
  remove_cli_binaries_global
  for user in $users; do
    home_dir=$(get_home_dir "$user" "$platform")
    remove_cli_binaries_user "$home_dir"
  done

  # Phase 6: macOS app bundle
  if [[ "$platform" == "darwin" ]]; then
    remove_mac_app
  fi

  # Phase 7: State directories
  for user in $users; do
    home_dir=$(get_home_dir "$user" "$platform")
    state_dir=$(get_state_dir "$home_dir")
    remove_state_dir "$state_dir"
  done

  # Also remove CLI found via PATH at an unexpected location
  local path_cli
  path_cli=$(command -v openclaw 2>/dev/null) || true
  if [[ -n "$path_cli" ]]; then
    remove_binary "$path_cli"
  fi

  # -- Determine result ---------------------------------------------------
  local total=$((REMOVED_COUNT + SKIPPED_COUNT + ERROR_COUNT))
  if [[ $ERROR_COUNT -gt 0 ]]; then
    echo "result: partial"
    printf "%s" "$output"
    exit 1
  elif [[ $total -eq 0 ]]; then
    echo "result: nothing-to-remove"
    printf "%s" "$output"
    exit 0
  else
    echo "result: all-removed"
    printf "%s" "$output"
    exit 0
  fi
}

main
