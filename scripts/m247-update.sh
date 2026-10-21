#!/bin/bash

# Output file path for M247 blocklist
OUTPUT_FILE="../m247-blocklist.txt"
# History file path for backup
EARLIER_FILE="../ip-lists-history/m247-blocklist-earlier.txt"

# Create a temporary file and ensure it is cleaned up on exit
TMP_FILE=$(mktemp)
trap 'rm -f "$TMP_FILE"' EXIT

# Query RADB (Routing Assets Database) directly for all IPv4 routes originating from AS60068 (M247)
whois -h whois.radb.net -- "-i origin AS60068" |
    grep '^route:' |
    awk '{print $2}' |
    sort -u > "$TMP_FILE"

# Safety check: Only overwrite the production file if we actually got results
if [ -s "$TMP_FILE" ]; then
    # If the current output file exists, back it up to the history file first
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
        echo "Number of different lines: $DIFFERENT_LINES"
    else
        echo "No previous list found; creating a new one."
    fi

    # Overwrite output file, set permissions, and report success
    mv "$TMP_FILE" "$OUTPUT_FILE"
    echo "Success! List saved to $OUTPUT_FILE"
else
    echo "Error: Could not fetch BGP data for M247 from RADB. The existing file was left unchanged."
    exit 1
fi
