#!/usr/bin/env bash
# openclaw detection script for mdm deployment
# exit codes: 0=not-installed (clean), 1=found (non-compliant), 2=error

set -euo pipefail

PROFILE="${OPENCLAW_PROFILE:-}"
PORT="${OPENCLAW_GATEWAY_PORT:-18789}"

print_banner() {
  echo ''
  echo '  _  ___  _  ___  ___  _____ ___ ___'
  echo ' | |/ / \| |/ _ \/ __|_   _|_ _/ __|'
  echo ' |   <| .  | (_) \__ \ | |  | | (__ '
  echo ' |_|\_\_|\_|\___/|___/ |_| |___\___|'
  echo ''
  echo ' Open source from Knostic - https://knostic.ai'
  echo ' OpenClaw Detection Script'
  echo ''
}

print_banner

detect_platform() {
  case "$(uname -s)" in
    Darwin) echo "darwin" ;;
    Linux) echo "linux" ;;
    *) echo "unknown" ;;
  esac
}

get_state_dir() {
  local home="$1"
  if [[ -n "$PROFILE" ]]; then
    echo "${home}/.openclaw-${PROFILE}"
  else
    echo "${home}/.openclaw"
  fi
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
  local user="$1"
  local platform="$2"
  case "$platform" in
    darwin) echo "/Users/$user" ;;
    linux) echo "/home/$user" ;;
  esac
}

check_cli_in_path() {
  local path
  path=$(command -v openclaw 2>/dev/null) || true
  if [[ -n "$path" ]]; then
    echo "$path"
    return 0
  fi
  return 1
}

check_cli_for_user() {
  local home="$1"
  local locations=(
    "${home}/.volta/bin/openclaw"
    "${home}/.local/bin/openclaw"
    "${home}/.nvm/current/bin/openclaw"
    "${home}/bin/openclaw"
  )
  for loc in "${locations[@]}"; do
    if [[ -x "$loc" ]]; then
      echo "$loc"
      return 0
    fi
  done
  return 1
}

check_cli_global() {
  local locations=(
    "/usr/local/bin/openclaw"
    "/opt/homebrew/bin/openclaw"
    "/usr/bin/openclaw"
  )
  for loc in "${locations[@]}"; do
    if [[ -x "$loc" ]]; then
      echo "$loc"
      return 0
    fi
  done
  return 1
}

check_mac_app() {
  local app_path="/Applications/OpenClaw.app"
  if [[ -d "$app_path" ]]; then
    echo "$app_path"
    return 0
  else
    echo "not-found"
    return 1
  fi
}

check_state_dir() {
  local state_dir="$1"
  if [[ -d "$state_dir" ]]; then
    echo "$state_dir"
    return 0
  else
    echo "not-found"
    return 1
  fi
}

check_config() {
  local config_file="${1}/openclaw.json"
  if [[ -f "$config_file" ]]; then
    echo "$config_file"
  else
    echo "not-found"
  fi
}

check_launchd_service() {
  local label uid
  uid=$(id -u)
  if [[ -n "$PROFILE" ]]; then
    label="bot.molt.${PROFILE}"
  else
    label="bot.molt.gateway"
  fi
  if launchctl print "gui/${uid}/${label}" &>/dev/null; then
    echo "gui/${uid}/${label}"
  else
    echo "not-loaded"
  fi
}

check_systemd_service() {
  local service
  if [[ -n "$PROFILE" ]]; then
    service="openclaw-gateway-${PROFILE}.service"
  else
    service="openclaw-gateway.service"
  fi
  if systemctl --user is-active "$service" &>/dev/null; then
    echo "$service"
  else
    echo "inactive"
  fi
}

get_configured_port() {
  local config_file="$1"
  if [[ -f "$config_file" ]]; then
    # extract port from json without jq (mdm environments may not have it)
    grep -o '"port"[[:space:]]*:[[:space:]]*[0-9]*' "$config_file" 2>/dev/null | head -1 | grep -o '[0-9]*$' || true
  fi
}

check_gateway_port() {
  local port="$1"
  if nc -z localhost "$port" &>/dev/null; then
    echo "listening"
    return 0
  else
    echo "not-listening"
    return 1
  fi
}

check_docker_containers() {
  if ! command -v docker &>/dev/null; then
    return 0
  fi
  docker ps --format '{{.Names}} ({{.Image}})' 2>/dev/null | grep -i openclaw || true
}

check_docker_images() {
  if ! command -v docker &>/dev/null; then
    return 0
  fi
  docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -i openclaw || true
}

main() {
  local platform cli_found=false app_found=false state_found=false service_running=false port_listening=false
  local output=""

  out() { output+="$1"$'\n'; }

  platform=$(detect_platform)
  out "platform: $platform"

  if [[ "$platform" == "unknown" ]]; then
    echo "summary: error"
    echo "$output"
    exit 2
  fi

  # check global CLI locations first
  local cli_result=""
  cli_result=$(check_cli_in_path) || cli_result=$(check_cli_global) || true
  if [[ -n "$cli_result" ]]; then
    cli_found=true
    out "cli: $cli_result"
    out "cli-version: $("$cli_result" --version 2>/dev/null | head -1 || echo "unknown")"
  fi

  if [[ "$platform" == "darwin" ]]; then
    local app_result
    app_result=$(check_mac_app) && app_found=true || app_found=false
    out "app: $app_result"
  fi

  local users
  users=$(get_users_to_check "$platform")
  local multi_user=false
  local user_count
  user_count=$(echo "$users" | wc -l | tr -d ' ')
  [[ $user_count -gt 1 ]] && multi_user=true

  local ports_to_check="$PORT"

  for user in $users; do
    local home_dir state_dir
    home_dir=$(get_home_dir "$user" "$platform")
    state_dir=$(get_state_dir "$home_dir")

    if $multi_user; then
      out "user: $user"
      # check user-specific CLI if not already found
      if ! $cli_found; then
        local user_cli
        user_cli=$(check_cli_for_user "$home_dir") || true
        if [[ -n "$user_cli" ]]; then
          cli_found=true
          out "  cli: $user_cli"
          out "  cli-version: $("$user_cli" --version 2>/dev/null | head -1 || echo "unknown")"
        fi
      fi
      local state_result
      state_result=$(check_state_dir "$state_dir") && state_found=true
      out "  state-dir: $state_result"
      local config_result
      config_result=$(check_config "$state_dir")
      out "  config: $config_result"
      local configured_port
      configured_port=$(get_configured_port "${state_dir}/openclaw.json")
      if [[ -n "$configured_port" ]]; then
        out "  config-port: $configured_port"
        ports_to_check="$ports_to_check $configured_port"
      fi
    else
      # single user mode - check user CLI
      if ! $cli_found; then
        local user_cli
        user_cli=$(check_cli_for_user "$home_dir") || true
        if [[ -n "$user_cli" ]]; then
          cli_found=true
          out "cli: $user_cli"
          out "cli-version: $("$user_cli" --version 2>/dev/null | head -1 || echo "unknown")"
        fi
      fi
      if ! $cli_found; then
        out "cli: not-found"
        out "cli-version: n/a"
      fi
      local state_result
      state_result=$(check_state_dir "$state_dir") && state_found=true
      out "state-dir: $state_result"
      out "config: $(check_config "$state_dir")"
      local configured_port
      configured_port=$(get_configured_port "${state_dir}/openclaw.json")
      if [[ -n "$configured_port" ]]; then
        out "config-port: $configured_port"
        ports_to_check="$ports_to_check $configured_port"
      fi
    fi
  done

  # print cli not-found for multi-user if none found
  if $multi_user && ! $cli_found; then
    out "cli: not-found"
    out "cli-version: n/a"
  fi

  case "$platform" in
    darwin)
      local service_result
      service_result=$(check_launchd_service) && service_running=true || service_running=false
      out "gateway-service: $service_result"
      ;;
    linux)
      local service_result
      service_result=$(check_systemd_service) && service_running=true || service_running=false
      out "gateway-service: $service_result"
      ;;
  esac

  # check all unique ports (default + any configured in user configs)
  local unique_ports listening_port=""
  unique_ports=$(echo "$ports_to_check" | tr ' ' '\n' | sort -u | tr '\n' ' ')
  for port in $unique_ports; do
    if check_gateway_port "$port" >/dev/null; then
      port_listening=true
      listening_port="$port"
      break
    fi
  done
  if $port_listening; then
    out "gateway-port: $listening_port"
  else
    out "gateway-port: not-listening"
  fi

  local docker_containers docker_images docker_running=false docker_installed=false
  docker_containers=$(check_docker_containers)
  if [[ -n "$docker_containers" ]]; then
    docker_running=true
    out "docker-container: $docker_containers"
  else
    out "docker-container: not-found"
  fi

  docker_images=$(check_docker_images)
  if [[ -n "$docker_images" ]]; then
    docker_installed=true
    out "docker-image: $docker_images"
  else
    out "docker-image: not-found"
  fi

  local installed=false running=false

  if $cli_found || $app_found || $state_found || $docker_installed; then
    installed=true
  fi

  if $service_running || $port_listening || $docker_running; then
    running=true
  fi

  # exit codes: 0=not-installed (clean), 1=found (non-compliant), 2=error
  if ! $installed; then
    echo "summary: not-installed"
    printf "%s" "$output"
    exit 0
  elif $running; then
    echo "summary: installed-and-running"
    printf "%s" "$output"
    exit 1
  else
    echo "summary: installed-not-running"
    printf "%s" "$output"
    exit 1
  fi
}

main
