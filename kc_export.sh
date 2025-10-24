#!/usr/bin/env bash
# kc_export_full_v2.sh (fixed)
# Liệt kê và export certificate (public + private key) từ login & system keychains
# Compat: macOS bash (default). Avoids problematic conditional patterns.

set -euo pipefail

KEYCHAIN_LOGIN="$HOME/Library/Keychains/login.keychain-db"
KEYCHAIN_SYSTEM="/Library/Keychains/System.keychain"
EXPORT_DIR="./exported_certs"

mkdir -p "$EXPORT_DIR"

echo "🔍 Listing all certificates from Login & System keychains..."
printf "%-4s %-8s %-40s %s\n" "Idx" "Type" "SHA1" "Common Name"
printf "%-4s %-8s %-40s %s\n" "----" "--------" "----------------------------------------" "-------------------------------"

idx=1
declare -a certs_list=()

# Function: list for a keychain (tries identities first, then certificates)
list_certs() {
  local type="$1"
  local keychain="$2"

  # 1) Try identities (those with private key)
  local ids
  ids=$(security find-identity -p codesigning -v "$keychain" 2>/dev/null || true)

  # Use grep to check if output says "0 valid identities found"
  if [ -n "$ids" ] && ! printf "%s" "$ids" | grep -qi "0 valid identities found"; then
    # parse lines like: "  1) <SHA1> "Common Name""
    while IFS= read -r line; do
      if printf "%s" "$line" | grep -qE '\)[[:space:]]*[0-9A-F]{40}'; then
        if [[ $line =~ ([0-9A-F]{40})[[:space:]]+\"([^\"]+)\" ]]; then
          sha=${BASH_REMATCH[1]}
          cn=${BASH_REMATCH[2]}
          printf "%-4s [%-6s] %-40s %s\n" "$idx" "$type" "$sha" "$cn"
          certs_list+=("$type|$sha|$cn")
          idx=$((idx+1))
        fi
      fi
    done <<< "$ids"
  fi

  # 2) Also parse certificates (to get SHA1/CN from system certs or non-identity certs)
  # We will parse output from: security find-certificate -a -Z -p <keychain>
  local certs
  certs=$(security find-certificate -a -Z -p "$keychain" 2>/dev/null || true)
  local cur_sha=""
  while IFS= read -r line; do
    # Detect SHA-1 hash line
    if printf "%s" "$line" | grep -qE '^SHA-1'; then
      # extract hex (3rd token usually)
      cur_sha=$(printf "%s" "$line" | awk '{print $3}' | tr 'a-f' 'A-F')
      continue
    fi
    # Detect alis (Common Name) line: "alis"<blob>="..."
    if printf "%s" "$line" | grep -q '"alis"<blob>='; then
      cn=$(printf "%s" "$line" | sed -n 's/.*"alis"<blob>="\([^"]*\)".*/\1/p')
      # If CN empty, skip
      [ -z "${cn:-}" ] && continue
      # If sha empty, mark UNKNOWN
      [ -n "${cur_sha:-}" ] || cur_sha="UNKNOWN"
      # Avoid duplicates: check if sha already in certs_list
      local found=0
      for entry in "${certs_list[@]}"; do
        entry_sha=$(printf "%s" "$entry" | cut -d'|' -f2)
        if [ "$entry_sha" = "$cur_sha" ]; then
          found=1
          break
        fi
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

# Ask user whether to export
read -p "👉 Enter certificate index to export (or press Enter to quit): " idx_input
if [ -z "$idx_input" ]; then
  echo "Exit without export."
  exit 0
fi

# Validate numeric
if ! printf "%s" "$idx_input" | grep -qE '^[0-9]+$'; then
  echo "❌ Index must be a number."
  exit 1
fi

if [ "$idx_input" -lt 1 ] || [ "$idx_input" -gt "${#certs_list[@]}" ]; then
  echo "❌ Index out of range."
  exit 1
fi

# Read passphrase for export .p12 (can be empty)
read -s -p "🔑 Enter export passphrase (for .p12 file, leave empty for none): " pass_input
echo ""

# Export function
export_certificate() {
  local index="$1"
  local passphrase="$2"

  IFS='|' read -r type sha cn <<< "${certs_list[$((index-1))]}"

  local keychain
  if [ "$type" = "login" ]; then
    keychain="$KEYCHAIN_LOGIN"
  else
    keychain="$KEYCHAIN_SYSTEM"
  fi

  local outfile="$EXPORT_DIR/$(printf '%s' "$cn" | tr ' /' '__').p12"

  echo "Exporting: $cn"
  echo " Type : $type"
  echo " SHA1 : $sha"
  echo " Out  : $outfile"

  # Try export identities (private key + cert). If fails, fallback to export public cert only.
  if [ -n "$passphrase" ]; then
    if security export -k "$keychain" -t identities -f pkcs12 -o "$outfile" -P "$passphrase" -Z "$sha" >/dev/null 2>&1; then
      echo "✅ Exported .p12: $outfile"
      return 0
    fi
  else
    if security export -k "$keychain" -t identities -f pkcs12 -o "$outfile" -Z "$sha" >/dev/null 2>&1; then
      echo "✅ Exported .p12: $outfile"
      return 0
    fi
  fi

  # fallback: export public cert only to .cer file
  local outcer="${outfile%.p12}.cer"
  if security find-certificate -Z "$sha" -p "$keychain" > "$outcer" 2>/dev/null; then
    echo "⚠️  Could not export private key (or not permitted). Public certificate saved: $outcer"
    return 0
  fi

  echo "❌ Export failed for $cn (sha=$sha). You may need to run with sudo or unlock the keychain."
  return 1
}

export_certificate "$idx_input" "$pass_input"
