#!/usr/bin/env bash
# Upload a COG to the private S3 bucket for TiTiler serving.
# Usage: ./upload-to-s3.sh <local-file.tif> [s3-key]

set -euo pipefail

BUCKET="private-imagery-cog"
REGION="us-east-1"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <local-file.tif> [s3-key]"
    echo ""
    echo "Examples:"
    echo "  $0 data/test-image.tif"
    echo "  $0 data/test-image.tif imagery/project-name/image.tif"
    exit 1
fi

INPUT="$1"
S3_KEY="${2:-imagery/$(basename "$INPUT")}"

if [ ! -f "$INPUT" ]; then
    echo "ERROR: File not found: $INPUT"
    exit 1
fi

# Ensure bucket exists
if ! aws s3 ls "s3://$BUCKET" --region "$REGION" 2>/dev/null; then
    echo "Creating bucket: s3://$BUCKET"
    aws s3 mb "s3://$BUCKET" --region "$REGION"
    # Block all public access
    aws s3api put-public-access-block \
        --bucket "$BUCKET" \
        --region "$REGION" \
        --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    echo "Bucket created with public access blocked."
fi

echo "Uploading: $INPUT -> s3://$BUCKET/$S3_KEY"
aws s3 cp "$INPUT" "s3://$BUCKET/$S3_KEY" --region "$REGION"

echo ""
echo "Uploaded successfully."
echo ""
echo "TiTiler URL (after deployment):"
echo "  https://<api-gateway-id>.execute-api.$REGION.amazonaws.com/cog/WebMercatorQuad/map?url=s3://$BUCKET/$S3_KEY"
echo ""
echo "uMap tile URL template:"
echo "  https://<api-gateway-id>.execute-api.$REGION.amazonaws.com/cog/tiles/WebMercatorQuad/{z}/{x}/{y}.png?url=s3://$BUCKET/$S3_KEY"
