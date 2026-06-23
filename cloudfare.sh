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
#   - macOS: sudo access is required (to install the launchd
#     service).
#   - Windows 11: run Git Bash as Administrator (required to
#     install the Windows Service).
#
# STEP-BY-STEP BEHAVIOR (in the order the script runs)
#
#   [0] DETECT OPERATING SYSTEM
#       Uses `uname -s` to detect macOS / Windows (Git Bash,
#       MSYS, Cygwin) / WSL / Linux, so the script can pick the
#       right install commands and service-management approach
#       in later steps.
#
#   [1] CHECK & AUTO-INSTALL REQUIRED TOOLS (ensure_tools)
#       - ensure_jq(): checks for the `jq` command (used to
#         read/write JSON from bash). If missing:
#           macOS    -> auto-installs Homebrew (if missing),
#                       then `brew install jq`
#           Windows  -> `winget install jqlang.jq` (falls back
#                       to `choco install jq` if winget is
#                       unavailable)
#       - ensure_cloudflared(): checks for the `cloudflared`
#         command (Cloudflare's official tunnel client). If
#         missing, installs it the same way via brew/winget/choco.
#       - After installing, since the current terminal session's
#         PATH may not yet recognize the newly installed command,
#         the script asks you to reopen the terminal and re-run
#         the script.
#
#   [2] INITIALIZE THE ports.json CONFIG FILE (init_config)
#       If ports.json (located next to the script) does not
#       exist yet, create it with:
#         { "tunnel_name": "tunnel-<hostname>", "ports": [] }
#       "tunnel_name" is AUTO-GENERATED from this machine's
#       hostname (e.g. a machine named "MacBook-Trung" becomes
#       "tunnel-macbook-trung"). This guarantees EVERY MACHINE
#       ALWAYS HAS ITS OWN TUNNEL, so two different machines can
#       never accidentally share the same tunnel. ports.json is
#       the single source of truth for the port/domain list; you
#       may edit it by hand and re-run the sync option afterward.
#
#   [3] MAIN MENU (main_menu) - loops until you choose Exit:
#
#       1) Add / edit a port-domain mapping (add_or_edit_entry)
#          - Asks for a port (1-65535) and a domain.
#          - Saves to ports.json: if the port already exists,
#            its domain is OVERWRITTEN; otherwise a new entry is
#            appended.
#          - After saving, automatically calls sync_cloudflare()
#            to apply the change immediately (see step 4).
#
#       2) Remove a port-domain mapping (remove_entry)
#          - Asks for the port to remove, deletes that entry from
#            ports.json.
#          - Automatically calls sync_cloudflare() to re-apply.
#
#       3) Re-sync with Cloudflare (sync_cloudflare)
#          - Lets you re-apply the current ports.json at any time
#            (e.g. after manually editing the JSON file), without
#            adding or removing an entry.
#
#       4) Exit.
#
#   [4] SYNC CONFIGURATION TO CLOUDFLARE (sync_cloudflare)
#       This is the core routine, called every time the
#       port/domain list changes. It runs these sub-steps in
#       order:
#
#       4.1 ensure_login()
#           Checks for ~/.cloudflared/cert.pem. If it doesn't
#           exist yet (this machine has never logged in), prints
#           clear instructions, then runs `cloudflared tunnel
#           login`:
#             - Machine WITH a browser: it opens automatically to
#               log in.
#             - Headless/server machine WITHOUT a browser: the
#               command prints a LOGIN LINK; copy that link and
#               open it in a browser on A DIFFERENT MACHINE (e.g.
#               your admin laptop) to log in and select the right
#               domain. Once login completes on that other
#               machine, this server (which is still waiting)
#               will AUTOMATICALLY receive cert.pem — no manual
#               file copying needed. Only required once per
#               machine.
#
#       4.2 ensure_tunnel()
#           Reads "tunnel_name" (auto-generated from the hostname
#           in step 2) from ports.json, and checks via
#           `cloudflared tunnel list -o json` whether this tunnel
#           already exists in your Cloudflare account. If not,
#           creates it with `cloudflared tunnel create <name>`
#           (which generates a credentials *.json file under
#           ~/.cloudflared/). Because the name is always unique
#           per machine, the tunnel is GUARANTEED never to be
#           shared between machines.
#
#       4.3 write_config_yml()
#           Looks up the tunnel id, then rewrites the ENTIRE
#           ~/.cloudflared/config.yml file based on the CURRENT
#           full content of ports.json:
#             tunnel: <id>
#             credentials-file: <path to credentials file>
#             ingress:
#               - hostname: <domain 1>
#                 service: http://localhost:<port 1>
#               - hostname: <domain 2>
#                 service: http://localhost:<port 2>
#               ...
#               - service: http_status:404   (default catch-all)
#           This file is COMPLETELY rewritten on every sync, so
#           it always matches ports.json exactly.
#
#       4.4 route_dns()
#           For every domain in ports.json, runs:
#             cloudflared tunnel route dns --overwrite-dns
#               <tunnel_name> <domain>
#           This automatically creates/updates the CNAME record
#           on Cloudflare pointing that domain to the tunnel (no
#           dashboard visit needed). The --overwrite-dns flag
#           safely overwrites the record if one already exists.
#
#       4.5 restart_service()
#           Installs or restarts the background cloudflared
#           process, so it survives a machine reboot:
#             macOS    -> first run: `sudo cloudflared service
#                         install` (creates a launchd daemon).
#                         Later runs: `sudo launchctl kickstart
#                         -k system/com.cloudflare.cloudflared`
#                         to reload the new config.yml without
#                         rebooting.
#             Windows  -> first run: `cloudflared service
#                         install` (creates a Windows Service
#                         named "Cloudflared", requires
#                         Administrator). Later runs: `net
#                         stop/start Cloudflared` to reload the
#                         new config.yml.
#             Other    -> just prints manual instructions
#                         (`cloudflared tunnel run <name>`), since
#                         service automation isn't supported on
#                         this OS yet.
#
#       4.6 show_full_status()
#           After syncing, prints the ENTIRE current
#           configuration for visual confirmation: hostname,
#           tunnel name, tunnel ID, config.yml path, tunnel
#           connection status (`cloudflared tunnel info`), and
#           the full list of domain -> port mappings currently
#           in effect.
#
#   FINAL RESULT
#       After syncing, every domain in ports.json resolves
#       through Cloudflare, travels through this machine's OWN
#       tunnel, and forwards to the matching localhost port. The
#       whole pipeline restarts automatically on reboot thanks to
#       the service installed in step 4.5 - you never need to
#       re-run the script after every reboot. The final screen
#       (step 4.6) shows you the full running configuration so
#       you can confirm everything is correct.
# ============================================================

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/ports.json"

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

# ---------- 1. Install required tools ----------

ensure_brew() {
  if command -v brew >/dev/null 2>&1; then return; fi
  echo "Homebrew is not installed. Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

ensure_jq() {
  if command -v jq >/dev/null 2>&1; then return; fi
  echo "jq is not installed. Installing now..."
  case "$OS" in
    mac)
      ensure_brew
      brew install jq
      ;;
    windows)
      if command -v winget >/dev/null 2>&1; then
        winget install -e --id jqlang.jq
      elif command -v choco >/dev/null 2>&1; then
        choco install jq -y
      else
        echo "❌ Neither winget nor choco was found. Please install jq manually: https://jqlang.org/download/"
        exit 1
      fi
      ;;
    *)
      echo "❌ Please install jq manually for this operating system."
      exit 1
      ;;
  esac
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
  ensure_jq
  ensure_cloudflared
  # PATH may not pick up a newly installed command in this same session
  hash -r 2>/dev/null || true
  if ! command -v jq >/dev/null 2>&1 || ! command -v cloudflared >/dev/null 2>&1; then
    echo "⚠️  New tools were just installed. Please CLOSE AND REOPEN your terminal, then run this script again."
    exit 0
  fi
}

# ---------- 2. Manage the ports.json file ----------

init_config() {
  if [ ! -f "$CONFIG_FILE" ]; then
    # Name the tunnel after this machine's hostname, guaranteeing
    # every machine always has its own separate tunnel.
    local raw_hostname safe_hostname default_tunnel_name
    raw_hostname=$(hostname 2>/dev/null || echo "my-machine")
    # Normalize: keep only letters, digits, hyphens; collapse repeats
    safe_hostname=$(echo "$raw_hostname" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-' '-' | sed 's/-\{2,\}/-/g; s/^-//; s/-$//')
    [ -z "$safe_hostname" ] && safe_hostname="my-machine"
    default_tunnel_name="tunnel-${safe_hostname}"

    jq -n --arg tn "$default_tunnel_name" '{"tunnel_name": $tn, "ports": []}' > "$CONFIG_FILE" 2>/dev/null \
      || echo "{\"tunnel_name\":\"$default_tunnel_name\",\"ports\":[]}" > "$CONFIG_FILE"

    echo "Created new config file: $CONFIG_FILE"
    echo "Tunnel name for this machine: $default_tunnel_name (auto-generated from hostname, never shared with other machines)"
  fi
}

list_entries() {
  echo ""
  echo "===== Current port / domain list ====="
  local count
  count=$(jq '.ports | length' "$CONFIG_FILE")
  if [ "$count" -eq 0 ]; then
    echo "  (no entries yet)"
  else
    jq -r '.ports[] | "  - Port \(.port)  ->  \(.domain)"' "$CONFIG_FILE"
  fi
  echo "======================================="
  echo ""
}

add_or_edit_entry() {
  local port domain
  echo ""
  echo "----- Add / edit a port-domain mapping -----"
  echo "Enter the LOCAL PORT your app is listening on (a number"
  echo "between 1 and 65535, e.g. 12345)."
  read -r -p "Port: " port
  if ! echo "$port" | grep -Eq '^[0-9]+$' || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
    echo "❌ Invalid port."
    return
  fi

  echo ""
  echo "Enter the FULL DOMAIN you want to point to this port"
  echo "(e.g. myapp.ngthientrung.dev). The domain's root zone must"
  echo "already be using Cloudflare DNS."
  read -r -p "Domain: " domain
  if [ -z "$domain" ]; then
    echo "❌ Domain cannot be empty."
    return
  fi

  local tmp
  tmp=$(jq --argjson port "$port" --arg domain "$domain" '
    .ports |= ((map(select(.port != $port))) + [{"port": $port, "domain": $domain}])
  ' "$CONFIG_FILE")
  echo "$tmp" > "$CONFIG_FILE"
  echo "✅ Saved: port $port -> $domain (if the port already existed, its old domain was overwritten)."
  sync_cloudflare
}

remove_entry() {
  local port tmp
  echo ""
  echo "----- Remove a port-domain mapping -----"
  echo "Enter the PORT NUMBER of the entry you want to remove"
  echo "from the list (check the list above for valid ports)."
  read -r -p "Port to remove: " port
  if ! echo "$port" | grep -Eq '^[0-9]+$'; then
    echo "❌ Invalid port."
    return
  fi
  tmp=$(jq --argjson port "$port" '.ports |= map(select(.port != $port))' "$CONFIG_FILE")
  echo "$tmp" > "$CONFIG_FILE"
  echo "✅ Removed port $port from the list."
  sync_cloudflare
}

# ---------- 3. Cloudflare Tunnel configuration ----------

ensure_login() {
  local cert_path="$HOME/.cloudflared/cert.pem"
  if [ -f "$cert_path" ]; then
    return
  fi

  echo ""
  echo "===== CLOUDFLARE LOGIN (only needed once on this machine) ====="
  echo "This machine has no Cloudflare certificate yet (~/.cloudflared/cert.pem)."
  echo ""
  echo "cloudflared will print a login link right below this message."
  echo "  - If this machine HAS a browser: it will open automatically."
  echo "  - If this is a headless/server machine WITHOUT a browser: COPY"
  echo "    that link and open it in a browser on A DIFFERENT MACHINE (e.g."
  echo "    your admin laptop). After logging in and selecting the right"
  echo "    domain there, come back here — this script is waiting and will"
  echo "    AUTOMATICALLY receive the result, no manual file copying needed."
  echo "================================================================="
  echo ""

  cloudflared tunnel login

  if [ ! -f "$cert_path" ]; then
    echo "❌ cert.pem was not found after login. Please check and re-run the script."
    exit 1
  fi
  echo "✅ Successfully logged in to Cloudflare on this machine."
}

get_tunnel_id() {
  cloudflared tunnel list -o json 2>/dev/null | jq -r --arg name "$1" '.[] | select(.name==$name) | .id' | head -n1
}

ensure_tunnel() {
  local tunnel_name tunnel_id
  tunnel_name=$(jq -r '.tunnel_name' "$CONFIG_FILE")
  tunnel_id=$(get_tunnel_id "$tunnel_name")
  if [ -z "$tunnel_id" ]; then
    echo "Creating tunnel '$tunnel_name'..."
    cloudflared tunnel create "$tunnel_name"
  fi
}

write_config_yml() {
  local tunnel_name tunnel_id cred_file config_path
  tunnel_name=$(jq -r '.tunnel_name' "$CONFIG_FILE")
  tunnel_id=$(get_tunnel_id "$tunnel_name")
  cred_file="$HOME/.cloudflared/${tunnel_id}.json"
  config_path="$HOME/.cloudflared/config.yml"

  {
    echo "tunnel: $tunnel_id"
    echo "credentials-file: $cred_file"
    echo "ingress:"
    jq -r '.ports[] | "  - hostname: \(.domain)\n    service: http://localhost:\(.port)"' "$CONFIG_FILE"
    echo "  - service: http_status:404"
  } > "$config_path"

  echo "Wrote tunnel config to: $config_path"
}

route_dns() {
  local tunnel_name
  tunnel_name=$(jq -r '.tunnel_name' "$CONFIG_FILE")
  jq -r '.ports[].domain' "$CONFIG_FILE" | while read -r domain; do
    [ -z "$domain" ] && continue
    echo "Routing DNS: $domain -> tunnel $tunnel_name"
    cloudflared tunnel route dns --overwrite-dns "$tunnel_name" "$domain" 2>&1 | sed 's/^/    /'
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
      echo "   cloudflared tunnel run $(jq -r '.tunnel_name' "$CONFIG_FILE")"
      ;;
  esac
}

show_full_status() {
  local tunnel_name tunnel_id config_path
  tunnel_name=$(jq -r '.tunnel_name' "$CONFIG_FILE")
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
  echo "Active port -> domain mappings:"
  local count
  count=$(jq '.ports | length' "$CONFIG_FILE")
  if [ "$count" -eq 0 ]; then
    echo "  (no entries yet)"
  else
    jq -r '.ports[] | "  - https://\(.domain)  ->  http://localhost:\(.port)"' "$CONFIG_FILE"
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
    echo "1) Add / edit a port-domain mapping"
    echo "2) Remove a port-domain mapping"
    echo "3) Re-sync with Cloudflare (apply the current configuration)"
    echo "4) Exit"
    read -r -p "Your choice (1-4): " choice
    case "$choice" in
      1) add_or_edit_entry ;;
      2) remove_entry ;;
      3) sync_cloudflare ;;
      4) echo "Goodbye!"; exit 0 ;;
      *) echo "Invalid choice." ;;
    esac
  done
}

# ---------- Run ----------
ensure_tools
init_config
main_menu