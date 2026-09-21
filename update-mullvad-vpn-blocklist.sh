#!/usr/bin/env bash
set -euo pipefail

API_URL='https://api.mullvad.net/www/relays/all/'
OUTPUT='mullvad-ipv4.txt'
TEMP_FILE="$(mktemp)"

trap 'rm -f "$TEMP_FILE"' EXIT

command -v curl >/dev/null || { echo "curl missing." >&2; exit 1; }
command -v jq >/dev/null || { echo "jq missing." >&2; exit 1; }

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

mv "$TEMP_FILE" "$OUTPUT"
trap - EXIT

printf 'Wrote %s uniq active IPv4 adresses to %s\n' \
  "$(wc -l < "$OUTPUT" | tr -d ' ')" "$OUTPUT"
