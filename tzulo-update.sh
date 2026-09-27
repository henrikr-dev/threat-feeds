#!/bin/bash

# Sökväg till textfilen för FortiGate
OUTPUT_FILE="tzulo-blocklist.txt"

# Skapa en tillfällig fil
TMP_FILE=$(mktemp)

# Fråga RADB (Routing Assets Database) direkt efter alla IPv4-rader kopplade till AS11878
whois -h whois.radb.net -- "-i origin AS11878" | grep '^route:' | awk '{print $2}' | sort -u > "$TMP_FILE"

# Felsäkring: Skriv endast över den skarpa filen om vi faktiskt fick ett resultat
if [ -s "$TMP_FILE" ]; then
    mv "$TMP_FILE" "$OUTPUT_FILE"
    chmod 644 "$OUTPUT_FILE"
    echo "Lyckades! Listan sparad i $OUTPUT_FILE"
else
    echo "Fel: Kunde inte hämta BGP-data från RADB. Den befintliga filen sparades."
    rm -f "$TMP_FILE"
    exit 1
fi

