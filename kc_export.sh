#!/usr/bin/env bash
# kc_export_full_v4.sh
# List + export certs from login & system keychain.
# If export fails, offers to retry with sudo/unlock. Explains non-exportable cases.

set -euo pipefail

KEYCHAIN_LOGIN="$HOME/Library/Keychains/login.keychain-db"
KEYCHAIN_SYSTEM="/Library/Keychains/System.keychain"
EXPORT_DIR="./exported_certs"
mkdir -p "$EXPORT_DIR"

echo "🔍 Scanning Login & System keychains..."
printf "%-4s %-8s %-40s %s\n" "Idx" "Type" "SHA1" "Common Name"
printf "%-4s %-8s %-40s %s\n" "----" "--------" "----------------------------------------" "-------------------------------"

idx=1
declare -a certs_list=()

list_certs() {
  local type="$1"; local keychain="$2"
  local ids
  ids=$(security find-identity -p codesigning -v "$keychain" 2>/dev/null || true)

  if [ -n "$ids" ] && ! printf "%s" "$ids" | grep -qi "0 valid identities found"; then
    while IFS= read -r line; do
      if printf "%s" "$line" | grep -qE '\)[[:space:]]*[0-9A-F]{40}'; then
        if [[ $line =~ ([0-9A-F]{40})[[:space:]]+\"([^\"]+)\" ]]; then
          sha=${BASH_REMATCH[1]}; cn=${BASH_REMATCH[2]}
          printf "%-4s [%-6s] %-40s %s\n" "$idx" "$type" "$sha" "$cn"
          certs_list+=("$type|$sha|$cn")
          idx=$((idx+1))
        fi
      fi
    done <<< "$ids"
  fi

  # Parse certificates to capture system-only public certs (SHA + CN)
  local certs
  certs=$(security find-certificate -a -Z -p "$keychain" 2>/dev/null || true)
  local cur_sha=""
  while IFS= read -r line; do
    if printf "%s" "$line" | grep -qE '^SHA-1'; then
      cur_sha=$(printf "%s" "$line" | awk '{print $3}' | tr 'a-f' 'A-F')
      continue
    fi
    if printf "%s" "$line" | grep -q '"alis"<blob>='; then
      cn=$(printf "%s" "$line" | sed -n 's/.*"alis"<blob>="\([^"]*\)".*/\1/p')
      [ -z "${cn:-}" ] && continue
      [ -n "${cur_sha:-}" ] || cur_sha="UNKNOWN"
      # avoid duplicate sha
      local found=0
      for entry in "${certs_list[@]}"; do
        entry_sha=$(printf "%s" "$entry" | cut -d'|' -f2)
        if [ "$entry_sha" = "$cur_sha" ]; then found=1; break; fi
      done
      if [ $found -eq 0 ]; then
        printf "%-4s [%-6s] %-40s %s\n" "$idx" "$type" "$cur_sha" "$cn"
        certs_list+=("$type|$cur_sha|$cn")
        idx=$((idx+1))
      fi
      cur_sha=""
    fi
  done <<< "$certs"
}

list_certs "login" "$KEYCHAIN_LOGIN"
list_certs "system" "$KEYCHAIN_SYSTEM"

echo "-----------------------------------------------"
echo "Total certificates found: ${#certs_list[@]}"
echo ""

read -p "👉 Enter certificate index to export (or press Enter to quit): " idx_input
if [ -z "$idx_input" ]; then echo "Exit."; exit 0; fi
if ! printf "%s" "$idx_input" | grep -qE '^[0-9]+$'; then echo "Index must be numeric."; exit 1; fi
if [ "$idx_input" -lt 1 ] || [ "$idx_input" -gt "${#certs_list[@]}" ]; then echo "Index out of range."; exit 1; fi

read -s -p "🔑 Enter export passphrase for .p12 (leave empty for no passphrase): " pass_input
echo ""

IFS='|' read -r type sha cn <<< "${certs_list[$((idx_input-1))]}"
keychain="${KEYCHAIN_LOGIN}"
[ "$type" != "login" ] && keychain="$KEYCHAIN_SYSTEM"
outfile="$EXPORT_DIR/$(printf '%s' "$cn" | tr ' /' '__').p12"

echo "Exporting: $cn"
echo " Type : $type"
echo " SHA1 : $sha"
echo " Out  : $outfile"

# Try export normally (without sudo)
try_export() {
  local kc="$1"; local out="$2"; local pass="$3"; local fingerprint="$4"
  # Always pass -P even if empty (security requires explicit -P)
  if security export -k "$kc" -t identities -f pkcs12 -o "$out" -P "$pass" -Z "$fingerprint" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

if try_export "$keychain" "$outfile" "$pass_input" "$sha"; then
  echo "✅ Exported .p12: $outfile"
  exit 0
fi

# If failed, try to export with sudo after asking user
echo "⚠️  Could not export private key without elevated privileges or private key not exportable."
read -p "Do you want to retry with sudo/unlock (may ask for macOS password)? [y/N]: " yn
yn=${yn:-N}
if printf "%s" "$yn" | grep -qiE '^(y|yes)$'; then
  echo "Attempting sudo unlock + export..."
  # unlock system keychain if system
  if [ "$type" != "login" ]; then
    sudo security unlock-keychain /Library/Keychains/System.keychain || true
  else
    # unlock login keychain (current user) - may not be necessary
    sudo security unlock-keychain "$KEYCHAIN_LOGIN" || true
  fi

  sudo_sh() {
    # run security export with sudo; passphrase may be empty string
    if sudo security export -k "$keychain" -t identities -f pkcs12 -o "$outfile" -P "${pass_input:-}" -Z "$sha" >/dev/null 2>&1; then
      echo "✅ Exported .p12 (with sudo): $outfile"
      exit 0
    else
      return 1
    fi
  }

  if sudo_sh; then
    exit 0
  else
    echo "⚠️  Export with sudo failed as well."
    echo "Possible reasons:"
    echo "  - Private key is not present in that keychain (only public certificate exists)."
    echo "  - Private key is marked non-exportable or resides on a hardware token / Secure Enclave (T2/SEP/smartcard)."
    echo "  - Access control prevents export even for root."
    echo ""
    echo "Diagnostic steps you can run:"
    echo "  1) Check identities in login/system:"
    echo "     security find-identity -p codesigning -v ~/Library/Keychains/login.keychain-db"
    echo "     security find-identity -p codesigning -v /Library/Keychains/System.keychain"
    echo "  2) Open Keychain Access GUI -> select certificate, expand it to see private key (icon key). If not shown, private key is not available here."
    echo "  3) If private key on Secure Enclave or smartcard, export is impossible."
    echo ""
    echo "Script will now fallback to exporting public certificate only (PEM)."
  fi
fi

# Fallback: export public certificate (.cer/.pem)
outcer="${outfile%.p12}.cer"
if security find-certificate -Z "$sha" -p "$keychain" > "$outcer" 2>/dev/null; then
  echo "✅ Public certificate saved: $outcer"
  echo "Note: private key not exported."
  exit 0
fi

echo "❌ Final export attempt failed. Please check keychain permissions or whether private key is on hardware token."
exit 1
