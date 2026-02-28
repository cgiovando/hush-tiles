#!/usr/bin/env bash
# Download a test COG from OpenAerialMap for local TiTiler testing.
# OAM images are already in COG format.

set -euo pipefail

DATA_DIR="$(cd "$(dirname "$0")/.." && pwd)/data"
mkdir -p "$DATA_DIR"

echo "Fetching recent imagery metadata from OAM..."
RESPONSE=$(curl -s "https://api.openaerialmap.org/meta?limit=5&has_tiled=true")

# Extract the first image URL
IMAGE_URL=$(echo "$RESPONSE" | python3 -c "
import json, sys
data = json.load(sys.stdin)
results = data.get('results', [])
if not results:
    print('No results found', file=sys.stderr)
    sys.exit(1)
# Pick the first result with a valid uuid/url
for r in results:
    url = r.get('uuid', r.get('url', ''))
    if url:
        print(url)
        # Also print metadata for reference
        print(f\"Title: {r.get('title', 'N/A')}\", file=sys.stderr)
        print(f\"Resolution: {r.get('gsd', 'N/A')}m\", file=sys.stderr)
        print(f\"Provider: {r.get('provider', 'N/A')}\", file=sys.stderr)
        break
")

if [ -z "$IMAGE_URL" ]; then
    echo "ERROR: Could not find an image URL from OAM API."
    echo "You can browse https://map.openaerialmap.org and pick one manually."
    exit 1
fi

OUTPUT="$DATA_DIR/test-image.tif"

echo ""
echo "Downloading COG from:"
echo "  $IMAGE_URL"
echo "To: $OUTPUT"
echo ""

curl -L -o "$OUTPUT" "$IMAGE_URL"

FILE_SIZE=$(ls -lh "$OUTPUT" | awk '{print $5}')
echo ""
echo "Downloaded: $OUTPUT ($FILE_SIZE)"
echo ""
echo "To test with TiTiler locally:"
echo "  uvicorn titiler.application.main:app --port 8000"
echo "  Open: http://localhost:8000/cog/WebMercatorQuad/map?url=file://$OUTPUT"
