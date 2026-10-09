#!/bin/bash

# Path to the FortiGate blocklist file
OUTPUT_FILE="aws-iplist.txt"
EARLIER_FILE="aws-iplist-earlier.txt"

# URL to AWS IP ranges
AWS_URL="https://ip-ranges.amazonaws.com/ip-ranges.json"

# Create a temporary file
TMP_FILE=$(mktemp)
trap 'rm -f "$TMP_FILE"' EXIT

# Fetch AWS IPv4 prefixes using curl, extract with jq, and aggregate/collapse networks with Python
curl -s "$AWS_URL" | jq -r '.prefixes[].ip_prefix' | python3 -c '
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
    chmod 644 "$OUTPUT_FILE"
    echo "Success! List saved to $OUTPUT_FILE"
else
    echo "Error: Could not fetch IP data from AWS. The existing file was left unchanged."
    exit 1
fi
