#!/bin/bash

OUTPUT_FILE="m247-blocklist.txt"
EARLIER_FILE="m247-blocklist-earlier.txt"
TMP_FILE=$(mktemp)

trap 'rm -f "$TMP_FILE"' EXIT

# Fetch all IPv4 routes for AS60068 (M247)
whois -h whois.radb.net -- "-i origin AS60068" |
    grep '^route:' |
    awk '{print $2}' |
    sort -u > "$TMP_FILE"

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
    echo "Success! List saved in $OUTPUT_FILE"
else
    echo "Error: Could not fetch BGP data for M247."
    exit 1
fi
