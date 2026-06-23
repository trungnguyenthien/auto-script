#!/usr/bin/env bash
# ============================================================
# cloudfare.sh
#
# PURPOSE
#   Manage a list of (local port <-> domain) mappings and
#   automatically configure a Cloudflare Tunnel so each domain
#   points directly to an app running on this machine (via
#   localhost:port), with no router/NAT port forwarding needed.
#   The tunnel is installed as a system service, so it will
#   automatically restart every time this machine boots.
#
# REQUIREMENTS
#   - The domain must already use Cloudflare as its DNS (the
#     zone must exist in your Cloudflare account).
#   - Routes are managed by editing cloudfare.yml next to this
#     script (see the file for the format). No terminal input
#     is needed — just edit the file and re-run the script.
#   - macOS: sudo access is required (to install the launchd
#     service).
#   - Windows 11: run Git Bash as Administrator (required to
#     install the Windows Service).

set -u

# Force UTF-8 so emoji icons (✅ ❌ ⚠️ 👉) render correctly
# in Git Bash on Windows (otherwise mintty/cmd may show mojibake).
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/cloudfare.yml"

# ---------- 0. Detect operating system ----------
case "$(uname -s)" in
  Darwin*) OS="mac" ;;
  MINGW*|MSYS*|CYGWIN*) OS="windows" ;;
  Linux*)
    if grep -qi "microsoft" /proc/version 2>/dev/null; then
      OS="wsl"
    else
      OS="linux"
    fi
    ;;
  *) OS="unknown" ;;
esac

echo "Detected operating system: $OS"
if [ "$OS" = "wsl" ] || [ "$OS" = "linux" ] || [ "$OS" = "unknown" ]; then
  echo "⚠️  This script is optimized for macOS and Windows (Git Bash)."
  echo "   On this OS, the auto-start service step will only print manual instructions."
fi

# Reject running as root. The first steps (tool checks, login, tunnel
# creation, DNS routing) must run as a normal user. Only the very last
# `restart_service` step needs elevated privileges (sudo / Administrator),
# and that step will prompt for the password itself.
if [ "$(id -u)" -eq 0 ]; then
  echo ""
  echo "❌ Do NOT run cloudfare.sh with sudo / as root."
  echo "   Homebrew refuses to run as root, so the install step would fail."
  echo ""
  echo "   Run it as your normal user instead:"
  echo "     bash $SCRIPT_DIR/cloudfare.sh"
  echo ""
  echo "   The 'restart service' step will prompt for sudo on its own."
  echo ""
  exit 1
fi

print_intro() {
  echo ""
  echo "================================================================="
  echo "                CLOUDFLARE TUNNEL MANAGER"
  echo "================================================================="
  echo ""
  echo "What it does"
  echo "  • Maps each domain to a local port (localhost:<port>)"
  echo "  • Configures a Cloudflare Tunnel — no router/NAT forwarding"
  echo "  • Installs the tunnel as a system service (auto-restart on boot)"
  echo ""
  echo "Requirements"
  echo "  1) Your domain must use Cloudflare DNS (zone exists in CF account)"
  echo "  2) cloudflared installed (script auto-installs via brew / winget /"
  echo "     choco). Do NOT run this script with sudo."
  echo "  3) Cloudflare login — one-time, guided by the script"
  echo "     - macOS: sudo needed at the restart-service step"
  echo "     - Windows 11: run Git Bash as Administrator"
  echo "  4) Config file: $CONFIG_FILE"
  echo "     Edit it, re-run the script → routes auto-sync. No terminal input."
  echo ""
  echo "================================================================="
  echo ""
}

# ---------- 1. Install required tools ----------

ensure_brew() {
  if command -v brew >/dev/null 2>&1; then return; fi
  echo "Homebrew is not installed. Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

ensure_cloudflared() {
  if command -v cloudflared >/dev/null 2>&1; then return; fi
  echo "cloudflared is not installed. Installing now..."
  case "$OS" in
    mac)
      ensure_brew
      brew install cloudflared
      ;;
    windows)
      if command -v winget >/dev/null 2>&1; then
        winget install -e --id Cloudflare.cloudflared
      elif command -v choco >/dev/null 2>&1; then
        choco install cloudflared -y
      else
        echo "❌ Neither winget nor choco was found. Please install cloudflared manually:"
        echo "   https://github.com/cloudflare/cloudflared/releases"
        exit 1
      fi
      ;;
    *)
      echo "❌ Please install cloudflared manually for this operating system:"
      echo "   https://github.com/cloudflare/cloudflared/releases"
      exit 1
      ;;
  esac
}

ensure_tools() {
  ensure_cloudflared
  # PATH may not pick up a newly installed command in this same session
  hash -r 2>/dev/null || true
  if ! command -v cloudflared >/dev/null 2>&1; then
    echo "⚠️  New tools were just installed. Please CLOSE AND REOPEN your terminal, then run this script again."
    exit 0
  fi
}

# ---------- 2. Manage the cloudfare.yml file ----------
#
# File format (hosts-style, very simple):
#
#   # Lines starting with '#' are comments
#   # tunnel_name: my-tunnel     (optional; uncomment to override
#   #                              the default tunnel-<hostname>)
#   myapp.example.com 12345
#   api.example.com   3000
#   admin.example.com 8080
#
# Each non-comment, non-blank, non-tunnel_name line is "<domain> <port>".
# Whitespace between domain and port is any number of spaces or tabs.

# safe hostname -> "tunnel-<safe_hostname>"
safe_hostname() {
  local raw
  raw=$(hostname 2>/dev/null || echo "my-machine")
  echo "$raw" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-' '-' | sed 's/-\{2,\}/-/g; s/^-//; s/-$//' | sed 's/^$/my-machine/'
}

# tunnel_name: explicit "tunnel_name: X" from file, else "tunnel-<safe_hostname>"
get_tunnel_name() {
  local name
  if [ -f "$CONFIG_FILE" ]; then
    name=$(awk '/^[[:space:]]*tunnel_name:[[:space:]]*/ { sub(/^[[:space:]]*tunnel_name:[[:space:]]*/, ""); sub(/[[:space:]]*$/, ""); print; exit }' "$CONFIG_FILE")
  fi
  if [ -n "$name" ]; then
    echo "$name"
  else
    echo "tunnel-$(safe_hostname)"
  fi
}

# Print "<domain>\t<port>" for each route, one per line.
# Reject lines whose port is not a number 1..65535.
parse_routes() {
  awk '
    function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
    /^[[:space:]]*#/ { next }                 # comment
    /^[[:space:]]*$/ { next }                 # blank
    /^[[:space:]]*tunnel_name:/ { next }      # tunnel override line
    {
      d = $1
      p = $2
      if (d == "" || p == "") next
      if (p !~ /^[0-9]+$/) next
      if (p+0 < 1 || p+0 > 65535) next
      print d "\t" p
    }
  ' "$CONFIG_FILE"
}

route_count() {
  parse_routes | wc -l | tr -d ' '
}

# Read all (domain, port) pairs into two parallel global arrays:
#   __ROUTE_DOMAINS[]   __ROUTE_PORTS[]
# (globals instead of `local -n` so it works on bash 3.2 / macOS)
read_routes() {
  __ROUTE_DOMAINS=()
  __ROUTE_PORTS=()
  local line domain port
  while IFS=$'\t' read -r domain port; do
    [ -n "$domain" ] && [ -n "$port" ] || continue
    __ROUTE_DOMAINS+=("$domain")
    __ROUTE_PORTS+=("$port")
  done < <(parse_routes)
}

init_config() {
  if [ -f "$CONFIG_FILE" ]; then
    return
  fi

  local default_tunnel_name
  default_tunnel_name="tunnel-$(safe_hostname)"

  echo ""
  echo "❌ Config file not found: $CONFIG_FILE"
  echo ""
  echo "Creating a starter file with one sample route."
  echo "Edit it (replace the sample domain/port with your own), then"
  echo "re-run this script to sync with Cloudflare."
  echo ""

  cat > "$CONFIG_FILE" <<EOF
# tunnel_name: $default_tunnel_name   # (optional; uncomment to override)

# One route per line:  <domain> <port>
# Lines starting with '#' are comments.
# Replace the sample below with your real domain and local port.
myapp.ngthientrung.com 12345
EOF

  echo "✅ Created $CONFIG_FILE"
  echo ""
  echo "👉 Open the file, edit the route, then run:  bash $SCRIPT_DIR/cloudfare.sh"
  echo ""

  # Wait for user to read the message (in a TTY). Skip if not interactive.
  if [ -t 0 ]; then
    read -r -p "Press Enter to exit (or Ctrl+C to abort)..."
  fi
  exit 0
}

list_entries() {
  echo ""
  echo "Routes (from cloudfare.yml):"
  local count
  count=$(route_count)
  if [ "$count" -eq 0 ]; then
    echo "  (none)"
  else
    local i
    read_routes
    for ((i = 0; i < ${#__ROUTE_DOMAINS[@]}; i++)); do
      echo "  - ${__ROUTE_DOMAINS[$i]}  ->  :${__ROUTE_PORTS[$i]}"
    done
  fi
  echo ""
}

# ---------- 3. Cloudflare Tunnel configuration ----------

ensure_login() {
  local cert_path="$HOME/.cloudflared/cert.pem"
  if [ -f "$cert_path" ]; then
    return
  fi

  local choice
  echo ""
  echo "===== CLOUDFLARE LOGIN (one-time on this machine) ====="
  echo "1) Login from THIS machine (opens browser here)"
  echo "2) Login from ANOTHER machine (copies URL to clipboard)"
  read -r -p "Your choice (1-2): " choice
  echo ""

  case "$choice" in
    1)
      cloudflared tunnel login
      ;;
    2)
      local login_url="https://dash.cloudflare.com/argotunnel"
      echo "Open this URL on another machine (where you can log in):"
      echo "  $login_url"
      if copy_to_clipboard "$login_url"; then
        echo "✅ Copied to clipboard."
      else
        echo "(Could not copy automatically — please copy it manually.)"
      fi
      echo ""
      echo "On that machine: log in → select your domain → click 'Authorize'."
      echo "This script auto-receives the result. Just wait."
      echo "======================================================="
      echo ""

      cloudflared tunnel login --loginURL "$login_url"
      ;;
    *)
      echo "Invalid choice."
      return 1
      ;;
  esac

  if [ ! -f "$cert_path" ]; then
    echo "❌ cert.pem was not found after login. Please check and re-run the script."
    exit 1
  fi
  echo "✅ Successfully logged in to Cloudflare on this machine."
}

# Copy a string to the OS clipboard. Returns 0 on success, 1 otherwise.
copy_to_clipboard() {
  local text="$1"
  case "$OS" in
    mac)        printf "%s" "$text" | pbcopy ;;
    windows)    printf "%s" "$text" | clip.exe ;;
    linux|wsl)
      if command -v xclip >/dev/null 2>&1; then
        printf "%s" "$text" | xclip -selection clipboard
      elif command -v wl-copy >/dev/null 2>&1; then
        printf "%s" "$text" | wl-copy
      else
        return 1
      fi
      ;;
    *)          return 1 ;;
  esac
}

get_tunnel_id() {
  # Parse `cloudflared tunnel list -o json` (a JSON array of {id,name,...})
  # without requiring jq. The output is pretty-printed multi-line, so we
  # accumulate `name` and `id` fields across lines until the object ends
  # (a closing `}`).
  cloudflared tunnel list -o json 2>/dev/null | \
    awk -v want="$1" '
      {
        if (match($0, /"name"[[:space:]]*:[[:space:]]*"[^"]*"/)) {
          t = substr($0, RSTART, RLENGTH)
          sub(/^"name"[[:space:]]*:[[:space:]]*"/, "", t)
          sub(/"$/, "", t)
          cur_name = t
        }
        if (match($0, /"id"[[:space:]]*:[[:space:]]*"[^"]*"/)) {
          t = substr($0, RSTART, RLENGTH)
          sub(/^"id"[[:space:]]*:[[:space:]]*"/, "", t)
          sub(/"$/, "", t)
          cur_id = t
        }
        if (index($0, "}") > 0) {
          if (cur_name == want && cur_id != "") { print cur_id; exit }
          cur_name = ""; cur_id = ""
        }
      }
    '
}

ensure_tunnel() {
  local tunnel_name tunnel_id
  tunnel_name=$(get_tunnel_name)
  tunnel_id=$(get_tunnel_id "$tunnel_name")
  if [ -z "$tunnel_id" ]; then
    echo "Creating tunnel '$tunnel_name'..."
    cloudflared tunnel create "$tunnel_name"
  fi
}

write_config_yml() {
  local tunnel_name tunnel_id cred_file config_path
  tunnel_name=$(get_tunnel_name)
  tunnel_id=$(get_tunnel_id "$tunnel_name")
  cred_file="$HOME/.cloudflared/${tunnel_id}.json"
  config_path="$HOME/.cloudflared/config.yml"

  {
    echo "tunnel: $tunnel_id"
    echo "credentials-file: $cred_file"
    echo "ingress:"
    local i
    read_routes
    for ((i = 0; i < ${#__ROUTE_DOMAINS[@]}; i++)); do
      echo "  - hostname: ${__ROUTE_DOMAINS[$i]}"
      echo "    service: http://localhost:${__ROUTE_PORTS[$i]}"
    done
    echo "  - service: http_status:404"
  } > "$config_path"

  echo "Wrote tunnel config to: $config_path"
}

# Read all ingress entries from ~/.cloudflared/config.yml.
# Output per line: "<hostname>\t<service>\t<is_local>" where is_local
# is 1 if service contains "localhost:" (route owned by this machine),
# 0 otherwise (route owned by another machine in the same zone).
parse_tunnel_routes() {
  local config_path="$HOME/.cloudflared/config.yml"
  [ -f "$config_path" ] || return 0
  awk '
    /^[[:space:]]*-[[:space:]]*hostname:/ {
      # flush previous entry
      if (host != "" && svc != "" && svc !~ /^http_status:/) {
        is_local = (svc ~ /localhost:/) ? 1 : 0
        printf "%s\t%s\t%d\n", host, svc, is_local
      }
      line = $0
      sub(/^[[:space:]]*-[[:space:]]*hostname:[[:space:]]*/, "", line)
      sub(/[[:space:]]*$/, "", line)
      host = line
      svc = ""
    }
    /^[[:space:]]*service:/ {
      line = $0
      sub(/^[[:space:]]*service:[[:space:]]*/, "", line)
      sub(/[[:space:]]*$/, "", line)
      svc = line
    }
    END {
      if (host != "" && svc != "" && svc !~ /^http_status:/) {
        is_local = (svc ~ /localhost:/) ? 1 : 0
        printf "%s\t%s\t%d\n", host, svc, is_local
      }
    }
  ' "$config_path"
}

# Extract the port from a service URL like "http://localhost:8080".
extract_port_from_service() {
  echo "$1" | grep -oE ':[0-9]+$' | tr -d ':'
}

# TCP-connect check: returns "✅ up" if localhost:<port> is listening,
# "❌ down" otherwise. Uses `nc -z` if available, else falls back
# through OS-specific options (PowerShell on Windows, python3 elsewhere,
# bash /dev/tcp as last resort).
test_tcp_target() {
  local port="$1"
  if [ -z "$port" ] || ! echo "$port" | grep -Eq '^[0-9]+$'; then
    echo "—"
    return
  fi
  if command -v nc >/dev/null 2>&1; then
    nc -z localhost "$port" 2>/dev/null && echo "✅ up" || echo "❌ down"
    return
  fi
  case "$OS" in
    windows)
      # PowerShell is bundled with Windows 7+/11. Test-NetConnection returns
      # True if the port accepts a TCP connection within 1 second.
      if powershell.exe -NoProfile -Command "
        try {
          (Test-NetConnection -ComputerName 'localhost' -Port $port -InformationLevel Quiet -WarningAction SilentlyContinue) | Out-String
        } catch { 'False' }
      " 2>/dev/null | tr -d '\r\n ' | grep -qi '^true'; then
        echo "✅ up"
      else
        echo "❌ down"
      fi
      ;;
    *)
      # Try python3 first (works on macOS, Linux, WSL), then bash /dev/tcp.
      if command -v python3 >/dev/null 2>&1; then
        if python3 -c "
import socket, sys
s = socket.socket(); s.settimeout(0.5)
try: s.connect(('localhost', int(sys.argv[1]))); s.close(); sys.exit(0)
except Exception: sys.exit(1)
" "$port" 2>/dev/null; then
          echo "✅ up"
        else
          echo "❌ down"
        fi
      elif command -v python >/dev/null 2>&1; then
        if python -c "
import socket, sys
s = socket.socket(); s.settimeout(0.5)
try: s.connect(('localhost', int(sys.argv[1]))); s.close(); sys.exit(0)
except Exception: sys.exit(1)
" "$port" 2>/dev/null; then
          echo "✅ up"
        else
          echo "❌ down"
        fi
      elif (echo >/dev/tcp/localhost/"$port") 2>/dev/null; then
        echo "✅ up"
      else
        echo "❌ down"
      fi
      ;;
  esac
}

route_dns() {
  local tunnel_name
  tunnel_name=$(get_tunnel_name)
  local -a routed=() need_route=()
  read_routes
  if [ "${#__ROUTE_DOMAINS[@]}" -eq 0 ]; then
    return
  fi

  # Read currently-routed domains (from the live config.yml) into array
  local d
  while IFS=$'\t' read -r d _ _; do
    [ -n "$d" ] && routed+=("$d")
  done < <(parse_tunnel_routes)

  local i
  for ((i = 0; i < ${#__ROUTE_DOMAINS[@]}; i++)); do
    need_route+=("${__ROUTE_DOMAINS[$i]}")
  done

  if [ "${#need_route[@]}" -eq 0 ]; then
    echo "No domains need DNS routing (all already present in config.yml)."
    return
  fi

  for d in "${need_route[@]}"; do
    echo "Routing DNS: $d -> tunnel $tunnel_name"
    cloudflared tunnel route dns --overwrite-dns "$tunnel_name" "$d" 2>&1 | sed 's/^/    /'
  done
}

restart_service() {
  case "$OS" in
    mac)
      if sudo launchctl list 2>/dev/null | grep -q com.cloudflare.cloudflared; then
        echo "Restarting cloudflared service..."
        sudo launchctl kickstart -k system/com.cloudflare.cloudflared
      else
        echo "Installing cloudflared as an auto-start service (sudo password required)..."
        sudo cloudflared service install
      fi
      ;;
    windows)
      echo "⚠️  This step requires Git Bash to be running as Administrator."
      if sc.exe query Cloudflared >/dev/null 2>&1; then
        echo "Restarting the Cloudflared service..."
        net stop Cloudflared
        net start Cloudflared
      else
        echo "Installing cloudflared as a Windows Service..."
        cloudflared service install
      fi
      ;;
    *)
      echo "⚠️  Please restart cloudflared manually, e.g.:"
      echo "   cloudflared tunnel run $(get_tunnel_name)"
      ;;
  esac
}

show_full_status() {
  local tunnel_name tunnel_id config_path
  tunnel_name=$(get_tunnel_name)
  tunnel_id=$(get_tunnel_id "$tunnel_name")
  config_path="$HOME/.cloudflared/config.yml"

  echo ""
  echo "=== STATUS (from cloudflared) ==="
  echo "Hostname:        $(hostname 2>/dev/null || echo "?")"
  echo "Tunnel name:     $tunnel_name"
  echo "Tunnel ID:       ${tunnel_id:-(not created — run 'Sync now')}"
  echo "config.yml:      $config_path"
  echo ""
  echo "Tunnel connection:"
  if [ -n "$tunnel_id" ]; then
    cloudflared tunnel info "$tunnel_name" 2>&1 | sed 's/^/  /'
  elif [ -z "$tunnel_name" ]; then
    echo "  (tunnel name not set)"
  else
    echo "  (tunnel '$tunnel_name' not found on Cloudflare — run 'Sync now' to create it)"
  fi
  echo ""

  if [ ! -f "$config_path" ]; then
    echo "Routes: (config.yml not found on this machine)"
    echo "==============="
    return
  fi

  # Read all tunnel routes
  local -a all_d=() all_s=() all_local=()
  local d s loc
  while IFS=$'\t' read -r d s loc; do
    [ -n "$d" ] || continue
    all_d+=("$d")
    all_s+=("$s")
    all_local+=("$loc")
  done < <(parse_tunnel_routes)

  # Split into "this machine" (localhost:) vs "other machine"
  local -a my_d=() my_s=() other_d=() other_s=()
  local i port status
  for ((i = 0; i < ${#all_d[@]}; i++)); do
    if [ "${all_local[$i]}" = "1" ]; then
      my_d+=("${all_d[$i]}")
      my_s+=("${all_s[$i]}")
    else
      other_d+=("${all_d[$i]}")
      other_s+=("${all_s[$i]}")
    fi
  done

  echo "Routes on THIS machine (service: localhost:*):"
  if [ "${#my_d[@]}" -eq 0 ]; then
    echo "  (none)"
  else
    for ((i = 0; i < ${#my_d[@]}; i++)); do
      port=$(extract_port_from_service "${my_s[$i]}")
      status=$(test_tcp_target "$port")
      printf "  - %-40s -> localhost:%-5s  target: %s\n" "${my_d[$i]}" "$port" "$status"
    done
  fi
  echo ""
  echo "Routes on OTHER machines in same zone:"
  if [ "${#other_d[@]}" -eq 0 ]; then
    echo "  (none)"
  else
    for ((i = 0; i < ${#other_d[@]}; i++)); do
      printf "  - %-40s -> %s\n" "${other_d[$i]}" "${other_s[$i]}"
    done
  fi
  echo "==============="
  echo ""
}

sync_cloudflare() {
  echo ""
  echo ">>> Syncing to Cloudflare..."
  ensure_login
  ensure_tunnel
  write_config_yml
  route_dns
  restart_service
  echo ">>> ✅ Sync complete."
  show_full_status
}

# ---------- 4. Main menu ----------

main_menu() {
  while true; do
    list_entries
    echo "1) Sync now"
    echo "2) Show status"
    echo "3) Exit"
    read -r -p "Choice (1-3): " choice
    case "$choice" in
      1) sync_cloudflare ;;
      2) show_full_status ;;
      3) echo "Bye!"; exit 0 ;;
      *) echo "Invalid choice." ;;
    esac
  done
}

# ---------- Run ----------
print_intro
ensure_tools
init_config
# Auto-sync once on every run, so editing cloudfare.yml and re-running
# the script is enough to push changes to Cloudflare.
sync_cloudflare
main_menu