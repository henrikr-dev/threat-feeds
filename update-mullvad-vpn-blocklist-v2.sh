#!/usr/bin/env bash
set -euo pipefail

API_URL='https://api.mullvad.net/www/relays/all/'
OUTPUT='mullvad-ipv4.txt'
OPTIMIZED_OUTPUT='optimized-mullvad-ipv4.txt'

TEMP_FILE="$(mktemp)"
TEMP_OPTIMIZED="$(mktemp)"

trap 'rm -f "$TEMP_FILE" "$TEMP_OPTIMIZED"' EXIT

command -v curl >/dev/null || { echo "curl missing." >&2; exit 1; }
command -v jq >/dev/null || { echo "jq missing." >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 missing." >&2; exit 1; }

# 1. Hämta och validera alla enskilda aktiva IPv4-adresser
curl --fail --silent --show-error --location \
  --retry 3 --connect-timeout 10 --max-time 60 \
  "$API_URL" |
jq -r '
  .. | objects
  | select(has("ipv4_addr_in") and .active == true)
  | .ipv4_addr_in
' |
awk '
  /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ {
    split($0, p, ".")
    if (p[1] <= 255 && p[2] <= 255 && p[3] <= 255 && p[4] <= 255) print
  }
' |
LC_ALL=C sort -u > "$TEMP_FILE"

# 2. Generera den optimerade /24-kollapsade och supernetts-sammanfattade listan
python3 -c '
import sys, ipaddress

subnets = set()
with open(sys.argv[1], "r") as f:
    for line in f:
        ip = line.strip()
        if ip:
            # Maskera sista oktetten till /24
            net = ipaddress.ip_network(f"{ip}/24", strict=False)
            subnets.add(net)

# Supernetting / kollapsa alla angränsande /24-block till största möjliga CIDR
optimized = ipaddress.collapse_addresses(subnets)

with open(sys.argv[2], "w") as f:
    for cidr in optimized:
        f.write(f"{cidr}\n")
' "$TEMP_FILE" "$TEMP_OPTIMIZED"

# Skriv över målfilerna atomärt
mv "$TEMP_FILE" "$OUTPUT"
mv "$TEMP_OPTIMIZED" "$OPTIMIZED_OUTPUT"

trap - EXIT

printf 'Wrote %s uniq active IPv4 adresses to %s\n' \
  "$(wc -l < "$OUTPUT" | tr -d ' ')" "$OUTPUT"

printf 'Wrote %s optimized CIDR prefixes to %s\n' \
  "$(wc -l < "$OPTIMIZED_OUTPUT" | tr -d ' ')" "$OPTIMIZED_OUTPUT"
