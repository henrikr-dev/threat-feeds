#!/bin/bash

# Sökväg till textfilen för FortiGate
OUTPUT_FILE="datacamp-blocklist.txt"

# Kontrollera att whois-paketet är installerat
if ! command -v whois &> /dev/null; then
    sudo apt-get update && sudo apt-get install -y whois || sudo yum install -y whois
fi

TMP_FILE=$(mktemp)

# Hämta alla IPv4-rader kopplade till AS43350 (DataCamp)
whois -h whois.radb.net -- "-i origin AS43350" | grep '^route:' | awk '{print $2}' | sort -u > "$TMP_FILE"

# Felsäkring: Skriv endast över om vi fick ett resultat
if [ -s "$TMP_FILE" ]; then
    mv "$TMP_FILE" "$OUTPUT_FILE"
    chmod 644 "$OUTPUT_FILE"
    echo "Lyckades! Listan sparad i $OUTPUT_FILE"
else
    echo "Fel: Kunde inte hämta BGP-data för DataCamp."
    rm -f "$TMP_FILE"
    exit 1
fi

