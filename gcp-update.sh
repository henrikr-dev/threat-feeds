#!/bin/bash

# Path to the ip list
OUTPUT_FILE="gcp-iplist.txt"
EARLIER_FILE="gcp-iplist-earlier.txt"

# Official URL for Google Cloud IP ranges
GCP_URL="https://www.gstatic.com/ipranges/cloud.json"

# Create a temporary file
TMP_FILE=$(mktemp)
trap 'rm -f "$TMP_FILE"' EXIT

# Fetch GCP IPv4 prefixes using curl, extract with jq, and aggregate with Python
curl -s "$GCP_URL" | jq -r '.prefixes[].ipv4Prefix // empty' | python3 -c '
import sys, ipaddress
nets = [ipaddress.ip_network(line.strip()) for line in sys.stdin if line.strip()]
for net in ipaddress.collapse_addresses(nets):
    print(net)
' > "$TMP_FILE"

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
    echo "Error: Could not fetch IP data from GCP. The existing file was left unchanged."
    exit 1
fi
