# uMap Setup for Private Imagery Overlay

## Overview
Add private COG imagery as a custom tile overlay in uMap, served through TiTiler.

## Prerequisites
- TiTiler deployed and accessible (local or AWS)
- COG imagery uploaded to S3 (for AWS deployment)

## Adding the Tile Layer in uMap

### 1. Open your uMap instance
Navigate to your uMap map and click **Edit**.

### 2. Add a custom tile layer
- Click the **layers icon** (stacked squares) in the right panel
- Click **Add a layer** or edit an existing layer
- In layer settings, go to **Remote data** or use the **Custom background** option

### 3. For a custom background/overlay
- Go to map settings (gear icon)
- Under **Tilelayer**, choose **Custom**
- Enter the tile URL template:

**Local testing:**
```
http://localhost:8000/cog/tiles/WebMercatorQuad/{z}/{x}/{y}.png?url=<COG_URL>
```

**AWS deployment:**
```
https://<api-gateway-id>.execute-api.us-east-1.amazonaws.com/cog/tiles/WebMercatorQuad/{z}/{x}/{y}.png?url=s3://private-imagery-cog/imagery/test-image-clean.tif
```

To find your API Gateway URL after deploying, run:
```bash
aws cloudformation describe-stacks \
    --stack-name titiler-private-imagery \
    --region us-east-1 \
    --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
    --output text
```

### 4. Important settings
- **TMS checkbox**: Leave **unchecked** — TiTiler uses standard XYZ tile convention (not TMS)
- **Min/Max zoom**: Set appropriate zoom levels for your imagery (e.g., 10–20)

## URL Parameters

TiTiler supports several query parameters for rendering:

| Parameter | Description | Example |
|-----------|-------------|---------|
| `url` | COG file URL (required) | `s3://bucket/image.tif` |
| `nodata` | Pixel value to treat as transparent | `nodata=0` |
| `rescale` | Min/max values for display | `rescale=0,255` |
| `bidx` | Band indexes to use | `bidx=1&bidx=2&bidx=3` |
| `colormap_name` | Named colormap | `colormap_name=viridis` |
| `return_mask` | Include alpha mask | `return_mask=true` |

## Example: Full Tile URL with Options
```
https://<host>/cog/tiles/WebMercatorQuad/{z}/{x}/{y}.png?url=s3://private-imagery-cog/imagery/image.tif&rescale=0,255&return_mask=true
```

## Security Notes
- The API Gateway URL is publicly reachable but obscure (acceptable for testing)
- For production, add a `?token=SECRET` parameter via Lambda authorizer
  - This works with uMap's URL template system (unlike header-based auth)
  - Example: `https://<host>/cog/tiles/WebMercatorQuad/{z}/{x}/{y}.png?url=...&token=YOUR_TOKEN`

## Troubleshooting

### Tiles not loading
- Check browser dev tools Network tab for errors
- Verify TiTiler is running: visit `/api.html` endpoint (Swagger UI)
- Check CORS if uMap is on a different domain

### Black or blank tiles
- Try adding `&rescale=0,255` to the URL
- Check band indexes with: `<host>/cog/info?url=<COG_URL>`
- Verify the COG is valid: `rio cogeo validate <file.tif>`

### Black border around imagery
COG imagery often has black (nodata) borders. Add `&nodata=0` to the tile URL to make exact-black pixels transparent.

If a jagged near-black border remains (JPEG compression artifacts), the `viewer.html` has an "Edge cleanup" slider that processes tiles client-side, making pixels with all RGB values ≤ threshold transparent. A threshold of 10-15 typically eliminates the artifacts. This is a viewer-only feature — for uMap, `nodata=0` handles most cases.

### Wrong projection
- TiTiler reprojects on the fly, but source should ideally be EPSG:4326 or EPSG:3857
- Check with: `<host>/cog/info?url=<COG_URL>`

### Localhost doesn't work with public uMap
- Use ngrok: `ngrok http 8000`, then use the ngrok URL in uMap
- Or deploy to AWS (Phase 2)
