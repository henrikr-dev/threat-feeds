#!/bin/bash

# Path to the ip list files
OUTPUT_FILE="../nordvpn-blocklist.txt"
EARLIER_FILE="../ip-lists-history/nordvpn-blocklist-earlier.txt"

# URL to NordVPN servers API
NORD_URL="https://api.nordvpn.com/v1/servers?limit=16384"

# Create a temporary file
TMP_FILE=$(mktemp)
trap 'rm -f "$TMP_FILE"' EXIT

# Fetch NordVPN server IPs using curl and extract the 'station' field with jq, then append /32
curl -s "$NORD_URL" | jq -r '.[].station' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | sed 's/$/\/32/' | sort -u > "$TMP_FILE"

# Update the output file only if data was received
if [ -s "$TMP_FILE" ]; then
    if [ -f "$OUTPUT_FILE" ]; then
        cp "$OUTPUT_FILE" "$EARLIER_FILE"

        DIFFERENT_LINES=$(
            comm -3 \
                <(sort -u "$EARLIER_FILE") \
                <(sort -u "$TMP_FILE") |
            wc -l |
            tr -d ' '
        )

        echo "Previous list backed up to $EARLIER_FILE"
        echo "Different lines: $DIFFERENT_LINES"
    else
        echo "No previous list found; creating a new one."
    fi

    mv "$TMP_FILE" "$OUTPUT_FILE"
    echo "Success! List saved to $OUTPUT_FILE"
else
    echo "Error: Could not fetch IP data from NordVPN. The existing file was left unchanged."
    exit 1
fi
