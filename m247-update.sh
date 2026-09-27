#!/bin/bash

OUTPUT_FILE="m247-blocklist.txt"
TMP_FILE=$(mktemp)

# Fetch all IPv4 connected to AS60068 (M247)
whois -h whois.radb.net -- "-i origin AS60068" | grep '^route:' | awk '{print $2}' | sort -u > "$TMP_FILE"

# Do only write output if result is received
if [ -s "$TMP_FILE" ]; then
    mv "$TMP_FILE" "$OUTPUT_FILE"
    chmod 644 "$OUTPUT_FILE"
    echo "Success! List saved in $OUTPUT_FILE"
else
    echo "Error: Could not fetch BGP data for M247."
    rm -f "$TMP_FILE"
    exit 1
fi
