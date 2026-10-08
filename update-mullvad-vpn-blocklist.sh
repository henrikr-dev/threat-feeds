#!/usr/bin/env bash
set -euo pipefail

API_URL='https://api.mullvad.net/www/relays/all/'
OUTPUT='mullvad-ipv4.txt'
EARLIER_OUTPUT='mullvad-ipv4-earlier.txt'
OPTIMIZED_OUTPUT='optimized-mullvad-ipv4.txt'
EARLIER_OPTIMIZED_OUTPUT='optimized-mullvad-ipv4-earlier.txt'

TEMP_FILE="$(mktemp)"
TEMP_OPTIMIZED="$(mktemp)"

trap 'rm -f "$TEMP_FILE" "$TEMP_OPTIMIZED"' EXIT

command -v curl >/dev/null || { echo "Error: curl is missing." >&2; exit 1; }
command -v jq >/dev/null || { echo "Error: jq is missing." >&2; exit 1; }
command -v python3 >/dev/null || { echo "Error: python3 is missing." >&2; exit 1; }

# Fetch and validate active IPv4 addresses
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
        split($0, octets, ".")
        if (octets[1] <= 255 && octets[2] <= 255 &&
            octets[3] <= 255 && octets[4] <= 255) {
            print
        }
    }
' |
LC_ALL=C sort -u > "$TEMP_FILE"

# Create the optimized list by converting addresses to /24 networks
# and collapsing adjacent networks into the largest possible CIDR prefixes.
python3 -c '
import sys
import ipaddress

subnets = set()

with open(sys.argv[1], "r") as source:
    for line in source:
        ip = line.strip()
        if ip:
            subnets.add(ipaddress.ip_network(f"{ip}/24", strict=False))

optimized = ipaddress.collapse_addresses(subnets)

with open(sys.argv[2], "w") as destination:
    for cidr in optimized:
        destination.write(f"{cidr}\n")
' "$TEMP_FILE" "$TEMP_OPTIMIZED"

# Back up an existing file and report the number of differing lines.
backup_and_compare() {
    local current_file="$1"
    local earlier_file="$2"
    local new_file="$3"
    local difference_count

    if [[ -f "$current_file" ]]; then
        cp "$current_file" "$earlier_file"

        difference_count="$(
            comm -3 \
                <(LC_ALL=C sort -u "$earlier_file") \
                <(LC_ALL=C sort -u "$new_file") |
            wc -l |
            tr -d ' '
        )"

        echo "Previous list backed up to $earlier_file"
        echo "Different lines in $current_file: $difference_count"
    else
        echo "No previous list found for $current_file; creating a new one."
    fi
}

backup_and_compare "$OUTPUT" "$EARLIER_OUTPUT" "$TEMP_FILE"
backup_and_compare "$OPTIMIZED_OUTPUT" "$EARLIER_OPTIMIZED_OUTPUT" "$TEMP_OPTIMIZED"

# Replace the output files after both new lists have been generated.
mv "$TEMP_FILE" "$OUTPUT"
mv "$TEMP_OPTIMIZED" "$OPTIMIZED_OUTPUT"

trap - EXIT

printf 'Wrote %s unique active IPv4 addresses to %s\n' \
    "$(wc -l < "$OUTPUT" | tr -d ' ')" "$OUTPUT"

printf 'Wrote %s optimized CIDR prefixes to %s\n' \
    "$(wc -l < "$OPTIMIZED_OUTPUT" | tr -d ' ')" "$OPTIMIZED_OUTPUT"
