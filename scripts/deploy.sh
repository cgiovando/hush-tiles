#!/usr/bin/env bash
# Deploy TiTiler to AWS via SAM.
# First run uses --guided for interactive config; subsequent runs reuse samconfig.toml.
#
# Usage:
#   ./scripts/deploy.sh          # build + deploy
#   ./scripts/deploy.sh build    # build only
#   ./scripts/deploy.sh deploy   # deploy only (skip build)

set -euo pipefail
cd "$(dirname "$0")/.."

STACK_NAME="titiler-private-imagery"
REGION="us-east-1"

# Check prerequisites
command -v sam >/dev/null 2>&1 || { echo "ERROR: AWS SAM CLI not installed. Install from https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html"; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "ERROR: Docker not installed or not running."; exit 1; }
aws sts get-caller-identity >/dev/null 2>&1 || { echo "ERROR: AWS CLI not configured. Run 'aws configure' first."; exit 1; }

ACTION="${1:-all}"

do_build() {
    echo "==> Building SAM application (Docker image)..."
    sam build --use-container
    echo "==> Build complete."
}

do_deploy() {
    if [ -f samconfig.toml ]; then
        echo "==> Deploying (using existing samconfig.toml)..."
        sam deploy
    else
        echo "==> First deploy — running guided setup..."
        sam deploy --guided \
            --stack-name "$STACK_NAME" \
            --region "$REGION" \
            --capabilities CAPABILITY_IAM \
            --resolve-image-repos
    fi

    echo ""
    echo "==> Deployment complete. Fetching outputs..."
    aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].Outputs' \
        --output table
}

case "$ACTION" in
    build)
        do_build
        ;;
    deploy)
        do_deploy
        ;;
    all|*)
        do_build
        do_deploy
        ;;
esac
