#!/bin/bash

# Path to the files
OUTPUT_FILE="azure-iplist.txt"
EARLIER_FILE="azure-iplist-earlier.txt"

# Microsoft's official download page for Azure IP Ranges
AZURE_PAGE_URL="https://www.microsoft.com/en-us/download/details.aspx?id=56519"

# Create a temporary file
TMP_FILE=$(mktemp)
trap 'rm -f "$TMP_FILE"' EXIT

# 1. Fetch the direct JSON download link dynamically from Microsoft
DOWNLOAD_URL=$(curl -sL "$AZURE_PAGE_URL" | grep -oE 'https://download\.microsoft\.com/download/[^"]+ServiceTags_Public_[0-9]+\.json' | head -n 1)

if [ -z "$DOWNLOAD_URL" ]; then
    echo "Error: Could not dynamically extract Azure JSON download URL."
    exit 1
fi

# 2. Fetch Azure IPv4 prefixes using curl, extract with jq, and aggregate with Python
curl -sL "$DOWNLOAD_URL" | jq -r '.values[].properties.addressPrefixes[]' | grep -v ':' | python3 -c '
import sys, ipaddress
nets = [ipaddress.ip_network(line.strip()) for line in sys.stdin if line.strip()]
for net in ipaddress.collapse_addresses(nets):
    print(net)
' > "$TMP_FILE"

# 3. Update the output file only if data was received
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
    echo "Error: Could not fetch IP data from Azure. The existing file was left unchanged."
    exit 1
fi
