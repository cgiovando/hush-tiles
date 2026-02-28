#!/usr/bin/env bash
# Validate a GeoTIFF is a valid COG. Optionally convert if it isn't.
# Usage:
#   ./validate-cog.sh <input.tif>              # validate only
#   ./validate-cog.sh <input.tif> --convert     # validate, convert if needed

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <input.tif> [--convert]"
    exit 1
fi

INPUT="$1"
CONVERT="${2:-}"

if [ ! -f "$INPUT" ]; then
    echo "ERROR: File not found: $INPUT"
    exit 1
fi

echo "Validating COG: $INPUT"
echo "---"

# Run rio cogeo validate
if rio cogeo validate "$INPUT"; then
    echo ""
    echo "File is a valid COG."
else
    echo ""
    echo "File is NOT a valid COG."

    if [ "$CONVERT" = "--convert" ]; then
        OUTPUT="${INPUT%.tif}-cog.tif"
        echo ""
        echo "Converting to COG: $OUTPUT"
        rio cogeo create "$INPUT" "$OUTPUT" --cog-profile deflate --web-optimized
        echo ""
        echo "Validating converted file..."
        rio cogeo validate "$OUTPUT"
        echo ""
        echo "COG created: $OUTPUT"
    else
        echo "Run with --convert to create a COG version."
    fi
fi
