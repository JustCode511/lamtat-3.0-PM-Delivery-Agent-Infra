#!/usr/bin/env bash
set -euo pipefail

# Builds the Lambda deployment package into build/package/ (arm64 Linux wheels +
# app source). Terraform's archive_file then zips it.
# RUN THIS BEFORE `terraform apply` (and again whenever backend code changes).

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND="$(cd "$HERE/../pm-agent-backend" && pwd)"
BUILD="$HERE/build"
PKG="$BUILD/package"
PY="$BACKEND/.venv/bin/python"

echo "→ backend: $BACKEND"
rm -rf "$BUILD"
mkdir -p "$PKG"

echo "→ installing arm64 (Graviton) Linux wheels for Python 3.13 …"
# Excluded on purpose:
#   boto3            — provided by the Lambda runtime (~80MB saved)
#   google/openai    — only used on the gemini/openai LLM paths (we use Bedrock)
#   mcp / uvicorn    — not on the Lambda runtime path
"$PY" -m pip install \
  --platform manylinux2014_aarch64 \
  --implementation cp \
  --python-version 3.13 \
  --only-binary=:all: \
  --target "$PKG" \
  fastapi==0.115.0 \
  mangum \
  langgraph \
  httpx==0.27.2 \
  python-pptx \
  pyjwt \
  python-dotenv==1.0.1

echo "→ copying application source …"
rsync -a \
  --exclude '.venv' \
  --exclude '.git' \
  --exclude '__pycache__' \
  --exclude '*.pyc' \
  --exclude 'data' \
  --exclude 'tests' \
  --exclude 'test_*' \
  --exclude '.env' \
  --exclude 'pm-agent-backend' \
  "$BACKEND"/ "$PKG"/

echo "→ package size:"
du -sh "$PKG"
echo "✓ build/package ready — now run: terraform apply"
