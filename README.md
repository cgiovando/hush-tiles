# hush-tiles

Serve private/sensitive imagery as map tiles — without exposing the source files publicly.

Built for [HOT (Humanitarian OpenStreetMap Team)](https://www.hotosm.org/) teams that need to use sensitive aerial or satellite imagery in [uMap](https://umap-project.org/), QGIS, or other mapping tools, but can't upload it to public platforms like [OpenAerialMap](https://openaerialmap.org/).

## How it works

```
                         uMap / QGIS / any XYZ client
                                    │
                          requests /{z}/{x}/{y}.png
                                    ▼
                    ┌───────────────────────────────┐
                    │   API Gateway (HTTP, CORS)     │
                    │   public URL, pay-per-request   │
                    └───────────────┬───────────────┘
                                    ▼
                    ┌───────────────────────────────┐
                    │   AWS Lambda (TiTiler)          │
                    │   reads COG byte-ranges on      │
                    │   demand via IAM role            │
                    └───────────────┬───────────────┘
                                    ▼
                    ┌───────────────────────────────┐
                    │   S3 (private bucket)           │
                    │   Cloud Optimized GeoTIFF       │
                    │   not publicly accessible       │
                    └───────────────────────────────┘
```

**Key points:**
- The S3 bucket is **private** — no public access, no signed URLs leaking to browsers
- Lambda reads imagery via its **IAM role** — the only path to the data
- Tiles are served on demand — **no pre-rendering**, no tile cache to manage
- [Cloud Optimized GeoTIFF (COG)](https://www.cogeo.org/) format allows Lambda to read just the bytes it needs (byte-range requests), making it fast and cheap
- **Zero idle cost** — Lambda is pay-per-request, ideal for low-traffic humanitarian use

## Why not just use OpenAerialMap?

[OAM](https://openaerialmap.org/) is great for publicly shareable imagery. But sometimes imagery is:
- **Licensed for internal use only** (e.g., commercial satellite providers granting humanitarian access)
- **Sensitive** (e.g., imagery of conflict zones, refugee camps, or disaster areas before public release)
- **Embargoed** (e.g., pre-publication survey imagery)

hush-tiles gives teams a way to use this imagery in their mapping workflows (uMap, QGIS, iD editor, JOSM) without making the source files public.

## Architecture choices

| Choice | Rationale |
|--------|-----------|
| **TiTiler** | FastAPI-based COG tile server, already used by HOT for OAM. No new technology to learn. |
| **AWS SAM** | Simplest way to deploy Lambda + API Gateway. Single `template.yaml`, no framework overhead. |
| **Lambda + API Gateway** | Serverless, zero idle cost. HOT has AWS non-profit credits. |
| **COG on S3** | Industry-standard format. Byte-range reads = Lambda only fetches what it needs. |
| **Docker-based Lambda** | TiTiler + GDAL have native dependencies. Container image (~200MB) handles this cleanly. |
| **No auth (yet)** | API Gateway URL is obscure but public. Fine for demo/internal use. Production would add a Lambda authorizer with token-based auth (compatible with uMap's URL template system). |

> **Note:** If HOT already runs a TiTiler instance (e.g., for OAM), this same approach works by simply granting that existing instance's IAM role access to the private S3 bucket. No separate deployment needed.

## Quick start

### Prerequisites

- AWS CLI configured (`aws sts get-caller-identity`)
- [AWS SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html) installed
- Docker running

### 1. Prepare imagery

Convert your GeoTIFF to COG format and clean up nodata borders:

```bash
# Install local dependencies (for preprocessing only)
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# Download a test image from OAM (optional)
bash scripts/download-test-image.sh

# Clean near-black borders → internal transparency mask
python scripts/clean-cog-edges.py data/test-image.tif data/test-image-clean.tif
```

### 2. Upload to S3

```bash
bash scripts/upload-to-s3.sh data/test-image-clean.tif
# → s3://private-imagery-cog/imagery/test-image-clean.tif
```

### 3. Deploy

```bash
bash scripts/deploy.sh
```

First run will prompt for stack configuration. Outputs include the API Gateway URL.

### 4. Use the tiles

**Tile URL template** (for uMap, QGIS, etc.):
```
https://<api-id>.execute-api.us-east-1.amazonaws.com/cog/tiles/WebMercatorQuad/{z}/{x}/{y}.png?url=s3://private-imagery-cog/imagery/test-image-clean.tif
```

**WMTS** (for QGIS — includes bounds, supports Zoom to Layer):
```
https://<api-id>.execute-api.us-east-1.amazonaws.com/cog/WMTSCapabilities.xml?url=s3://private-imagery-cog/imagery/test-image-clean.tif
```

**TiTiler API docs:**
```
https://<api-id>.execute-api.us-east-1.amazonaws.com/api.html
```

See [docs/umap-setup.md](docs/umap-setup.md) for detailed uMap configuration instructions.

## Local development

```bash
source .venv/bin/activate
uvicorn titiler.application.main:app --host 0.0.0.0 --port 8000
```

Open `viewer.html` in a browser — it's a MapLibre GL JS viewer with environment presets (local / AWS) for testing tile rendering, opacity, and nodata handling.

## Cost estimate

For low-traffic humanitarian use with AWS non-profit credits:

| Resource | Cost |
|----------|------|
| Lambda (1536 MB, ~100ms/tile) | ~$0.25 per 10,000 tiles |
| API Gateway | ~$0.10 per 10,000 requests |
| S3 storage | ~$0.023/GB/month |
| S3 GET requests | ~$0.004 per 10,000 |

A typical mapping session loads ~200-500 tiles. Monthly cost for a small team: **< $1**.

## Project structure

```
template.yaml                   # SAM template (Lambda + API Gateway)
Dockerfile                      # Lambda container image
handler.py                      # Lambda handler (TiTiler + Mangum)
viewer.html                     # MapLibre tile viewer for testing
requirements.txt                # Python deps for local dev / preprocessing
scripts/
  deploy.sh                     # SAM build + deploy
  upload-to-s3.sh               # Upload COG to private S3
  download-test-image.sh        # Fetch sample COG from OAM
  validate-cog.sh               # COG format validation
  clean-cog-edges.py            # Remove black borders → transparency mask
docs/
  umap-setup.md                 # uMap configuration guide
```

## Future improvements

- **Token-based auth**: Lambda authorizer with `?token=SECRET` — works with uMap/QGIS URL templates
- **CloudFront**: CDN caching for faster tile delivery
- **Multiple images**: Mosaic endpoint for serving several COGs as a single layer
- **Custom domain**: `tiles.hot.example.org` instead of API Gateway URL

## License

[BSD-2-Clause](LICENSE)
