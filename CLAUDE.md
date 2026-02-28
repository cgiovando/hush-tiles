# hush-tiles — Private Imagery via TiTiler for uMap

## Purpose
Serve private GeoTIFF imagery as map tiles for uMap overlays. Sensitive imagery that can't be publicly hosted (e.g., on OAM) is stored in a private S3 bucket and served through TiTiler.

## Architecture
```
uMap (custom overlay layer)
  |  requests /{z}/{x}/{y}.png
  v
TiTiler (FastAPI on AWS Lambda + API Gateway)
  |  reads byte ranges via IAM role
  v
S3 (private bucket, COG format)
```

## Tech Stack
- **Tile server**: TiTiler (FastAPI-based COG tile server)
- **Image format**: Cloud Optimized GeoTIFF (COG)
- **Local dev**: uvicorn + titiler.application
- **Deployment**: AWS Lambda + API Gateway via SAM
- **Storage**: S3 (private bucket)
- **Viewer**: uMap (custom tile overlay)

## Key Files
```
viewer.html                     # MapLibre GL JS viewer for testing tile overlay
template.yaml                   # SAM template (Lambda + API Gateway)
Dockerfile                      # Lambda container image (TiTiler + Mangum)
handler.py                      # Lambda handler wrapping TiTiler with Mangum
requirements.txt                # Python dependencies (local dev)
scripts/deploy.sh               # SAM build + deploy wrapper
scripts/download-test-image.sh  # Fetch test COG from OAM
scripts/validate-cog.sh         # Validate/convert to COG format
scripts/clean-cog-edges.py      # Preprocess COG: near-black borders → internal mask
scripts/upload-to-s3.sh         # Upload COG to private S3 bucket
docs/umap-setup.md              # uMap configuration instructions
data/                            # Test imagery (gitignored)
```

## Quick Start (Local)
```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
bash scripts/download-test-image.sh
uvicorn titiler.application.main:app --host 0.0.0.0 --port 8000
```

## AWS Deployment
```bash
# Prerequisites: AWS CLI configured, SAM CLI installed, Docker running
bash scripts/deploy.sh          # build + deploy (first run is guided)
bash scripts/upload-to-s3.sh data/test-image-clean.tif  # upload COG
```
After deploy, the API Gateway URL is printed. Paste it into `viewer.html` AWS preset or use directly in uMap.

## TiTiler Endpoints (v1.2.0)
- **API docs**: `http://localhost:8000/api.html`
- **API spec**: `http://localhost:8000/api`
- **Map viewer**: `http://localhost:8000/cog/viewer?url=<COG_URL>`
- **Map preview**: `http://localhost:8000/cog/map?url=<COG_URL>`
- **Tile endpoint**: `http://localhost:8000/cog/tiles/WebMercatorQuad/{z}/{x}/{y}.png?url=<COG_URL>`
- **COG info**: `http://localhost:8000/cog/info?url=<COG_URL>`

Note: TiTiler v1.x uses `/api.html` for docs (not `/docs`), and `/cog/viewer` / `/cog/map` for map views.

## Test Image
- Source: OAM — "Carretera / Puente Rio Chico" (Ecuador road/bridge aerial)
- Bounds: lon -80.42, lat -0.98 (Ecuador)
- 3-band RGB uint8, 32768x28672px, 7 overview levels, 45MB
- Original: `data/test-image.tif` (raw from OAM, has JPEG edge artifacts)
- Cleaned: `data/test-image-clean.tif` (border pixels → internal mask, no edge artifacts)

## Phases
- **Phase 1**: Local testing with uvicorn — COMPLETE
- **Phase 2**: AWS deployment (personal account) — COMPLETE, deployed and tested
- **Phase 3**: Production on HOT infra — CloudFront, auth, custom domain

## Nodata & Edge Cleanup
COG imagery often has black borders (nodata pixels) and JPEG compression artifacts (near-black pixels at edges).

**Recommended workflow** (fastest, zero runtime overhead):
1. Preprocess COG with `scripts/clean-cog-edges.py` — flood-fills from edges to find connected near-black pixels, sets them to 0, re-creates COG with lossless internal mask band
2. TiTiler reads the internal mask automatically — tiles have correct transparency with no extra parameters
3. No `nodata=0` param or client-side processing needed

**Fallback options** (for unprocessed COGs):
- **`nodata=0`**: TiTiler URL parameter, makes exact-black (0,0,0) pixels transparent server-side. Doesn't catch JPEG artifacts (values 1-10).
- **Edge cleanup slider**: Client-side canvas processing in `viewer.html` via MapLibre `addProtocol`. Makes near-black pixels transparent. Adds ~23ms overhead per tile.

## AWS Deployment Details
- **API Gateway URL**: `https://cf38pke0w3.execute-api.us-east-1.amazonaws.com`
- **Stack name**: `titiler-private-imagery`
- **Region**: `us-east-1`
- **Architecture**: arm64 (cheaper Lambda, native build on Apple Silicon)
- **AWS Profile**: `admin` (user `claude-code`) — the `default` profile lacks CloudFormation permissions
- **S3 bucket**: `private-imagery-cog` (private, public access blocked)
- **Test COG**: `s3://private-imagery-cog/imagery/test-image-clean.tif`
- **Dockerfile note**: Requires `dnf install expat` — Lambda Python base image lacks libexpat needed by GDAL/rasterio

## Status
- Phase 1 complete: TiTiler running locally, test COG serving tiles successfully
- Phase 2 complete: Deployed to AWS, TMS and WMTS tested working (MapLibre viewer + QGIS)
- GitHub repo: https://github.com/cgiovando/hush-tiles
- MapLibre viewer updated with Local/AWS environment presets
