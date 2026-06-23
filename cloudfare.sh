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
  echo "❌ Please do NOT run cloudfare.sh with sudo / as root."
  echo ""
  echo "   Homebrew refuses to run as root (security), so the install"
  echo "   step will fail and the rest of the script cannot proceed."
  echo ""
  echo "   Run it as your normal user instead:"
  echo "     bash $SCRIPT_DIR/cloudfare.sh"
  echo ""
  echo "   When the script reaches the 'restart service' step, it will"
  echo "   prompt you for the sudo / Administrator password on its own."
  echo ""
  exit 1
fi

print_intro() {
  echo ""
  echo "================================================================="
  echo "                CLOUDFLARE TUNNEL MANAGER"
  echo "================================================================="
  echo ""
  echo "📌 CHỨC NĂNG CHÍNH"
  echo "   • Quản lý danh sách ánh xạ: local port  <->  domain"
  echo "   • Tự động cấu hình Cloudflare Tunnel để mỗi domain trỏ"
  echo "     thẳng về app đang chạy trên máy này (qua localhost:port)"
  echo "   • Không cần mở port trên router/NAT"
  echo "   • Cài tunnel thành service hệ thống — tự khởi động lại"
  echo "     sau khi reboot"
  echo ""
  echo "📋 YÊU CẦU TỐI THIỂU"
  echo ""
  echo "  1) Cấu hình Cloudflare"
  echo "     - Domain phải ĐÃ dùng Cloudflare làm DNS"
  echo "       (zone phải tồn tại trong tài khoản Cloudflare của bạn)"
  echo ""
  echo "  2) Công cụ"
  echo "     - cloudflared     : Cloudflare Tunnel daemon"
  echo "       (script sẽ TỰ CÀI qua Homebrew / winget / choco"
  echo "        nếu máy chưa có — KHÔNG chạy script với sudo)"
  echo ""
  echo "  3) Chứng thực (chỉ cần thực hiện 1 lần trên máy này)"
  echo "     - Cloudflare login → sinh file ~/.cloudflared/cert.pem"
  echo "       (script sẽ tự hướng dẫn khi cần)"
  echo "     - macOS: cần quyền sudo để cài launchd service"
  echo "     - Windows 11: chạy Git Bash với quyền Administrator"
  echo "       để cài Windows Service"
  echo ""
  echo "  4) File cấu hình: $CONFIG_FILE"
  echo "     - User chỉ cần sửa $CONFIG_FILE rồi chạy lại script —"
  echo "       mọi route sẽ được TỰ ĐỘNG đồng bộ với Cloudflare"
  echo "       (không cần nhập gì trên terminal)"
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

  cat <<EOF
❌ Config file not found: $CONFIG_FILE

The default tunnel name for this machine would be: $default_tunnel_name

Please create $CONFIG_FILE with the content below, then run this script again:

# tunnel_name: $default_tunnel_name   # (optional; uncomment to override)
myapp.ngthientrung.com 12345
api.ngthientrung.com 3000
EOF
  exit 0
}

list_entries() {
  echo ""
  echo "===== Current routes (from cloudfare.yml) ====="
  local count
  count=$(route_count)
  if [ "$count" -eq 0 ]; then
    echo "  (no entries yet)"
  else
    local i
    read_routes
    for ((i = 0; i < ${#__ROUTE_DOMAINS[@]}; i++)); do
      echo "  - Port ${__ROUTE_PORTS[$i]}  ->  ${__ROUTE_DOMAINS[$i]}"
    done
  fi
  echo "==============================================="
  echo ""
}

# ---------- 3. Cloudflare Tunnel configuration ----------

ensure_login() {
  local cert_path="$HOME/.cloudflared/cert.pem"
  if [ -f "$cert_path" ]; then
    return
  fi

  echo ""
  echo "===== CLOUDFLARE LOGIN (one-time on this machine) ====="
  echo "1. cloudflared will open: https://dash.cloudflare.com/argotunnel"
  echo "2. Log in to your Cloudflare account."
  echo "3. Select the domain (zone) you want to use for this tunnel."
  echo "4. Click 'Authorize'."
  echo "   (No browser? Copy the link to another device — same steps.)"
  echo "This script auto-receives the result. Just wait."
  echo "======================================================="
  echo ""

  cloudflared tunnel login

  if [ ! -f "$cert_path" ]; then
    echo "❌ cert.pem was not found after login. Please check and re-run the script."
    exit 1
  fi
  echo "✅ Successfully logged in to Cloudflare on this machine."
}

get_tunnel_id() {
  # Parse `cloudflared tunnel list -o json` (a JSON array of {id,name,...})
  # without requiring jq. We look for the object whose "name":"<name>" field
  # matches $1, then grab its "id" value.
  cloudflared tunnel list -o json 2>/dev/null | \
    awk -v want="$1" '
      {
        # Strip the opening/closing [ ] and treat as a stream of objects.
        s = $0
        # Replace commas at end-of-line with nothing so we can split.
        gsub(/,[[:space:]]*$/, "", s)
        # Find "name":"..." and "id":"..."
        n = ""; i = ""
        if (match(s, /"name"[[:space:]]*:[[:space:]]*"[^"]*"/)) {
          t = substr(s, RSTART, RLENGTH)
          sub(/^"name"[[:space:]]*:[[:space:]]*"/, "", t)
          sub(/"$/, "", t)
          n = t
        }
        if (match(s, /"id"[[:space:]]*:[[:space:]]*"[^"]*"/)) {
          t = substr(s, RSTART, RLENGTH)
          sub(/^"id"[[:space:]]*:[[:space:]]*"/, "", t)
          sub(/"$/, "", t)
          i = t
        }
        if (n == want && i != "") { print i; exit }
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

# List of domains already declared in the active tunnel's config.yml
routed_domains() {
  local config_path="$HOME/.cloudflared/config.yml"
  if [ -f "$config_path" ]; then
    awk '/^[[:space:]]*-[[:space:]]*hostname:/ { sub(/^[[:space:]]*-[[:space:]]*hostname:[[:space:]]*/, ""); sub(/[[:space:]]*$/, ""); print }' "$config_path"
  fi
}

route_dns() {
  local tunnel_name
  tunnel_name=$(get_tunnel_name)
  local -a routed=() need_route=()
  read_routes
  if [ "${#__ROUTE_DOMAINS[@]}" -eq 0 ]; then
    return
  fi

  # Read routed domains into array
  local d
  while IFS= read -r d; do
    [ -n "$d" ] && routed+=("$d")
  done < <(routed_domains)

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
  echo "================== CURRENT FULL CONFIGURATION ==================="
  echo "Machine (hostname): $(hostname 2>/dev/null || echo "?")"
  echo "Tunnel name:         $tunnel_name"
  echo "Tunnel ID:           ${tunnel_id:-"(could not determine - check the tunnel creation step)"}"
  echo "config.yml path:     $config_path"
  echo ""
  echo "Tunnel connection status:"
  if [ -n "$tunnel_id" ]; then
    cloudflared tunnel info "$tunnel_name" 2>&1 | sed 's/^/  /'
  else
    echo "  (could not retrieve tunnel info)"
  fi
  echo ""
  echo "Active routes (from $CONFIG_FILE):"
  local count
  count=$(route_count)
  if [ "$count" -eq 0 ]; then
    echo "  (no entries yet)"
  else
    local i
    read_routes
    for ((i = 0; i < ${#__ROUTE_DOMAINS[@]}; i++)); do
      echo "  - https://${__ROUTE_DOMAINS[$i]}  ->  http://localhost:${__ROUTE_PORTS[$i]}"
    done
  fi
  echo "==================================================================="
  echo ""
}

sync_cloudflare() {
  echo ""
  echo ">>> Syncing configuration to Cloudflare..."
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
    echo "Choose an option below by typing its number, then press Enter."
    echo "1) Sync now (re-apply the current cloudfare.yml to Cloudflare)"
    echo "2) Show status (full configuration & tunnel info)"
    echo "3) Exit"
    read -r -p "Your choice (1-3): " choice
    case "$choice" in
      1) sync_cloudflare ;;
      2) show_full_status ;;
      3) echo "Goodbye!"; exit 0 ;;
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