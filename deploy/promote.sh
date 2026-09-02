#!/usr/bin/env bash
# Promote an already-built, already-scanned image to a target environment
# by retagging — never rebuilds.
#
# Usage: ./promote.sh <commit-sha> <target-environment>
# Example: ./promote.sh a1b2c3d production

set -euo pipefail

SHA="${1:?Usage: promote.sh <commit-sha> <target-environment>}"
TARGET_ENV="${2:?Usage: promote.sh <commit-sha> <target-environment>}"

# Set once ECR exists (Day 19) — placeholders for now
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:?Set AWS_ACCOUNT_ID env var}"
AWS_REGION="${AWS_REGION:?Set AWS_REGION env var}"
REPO="employee-directory"

REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
SOURCE_TAG="${REGISTRY}/${REPO}:${SHA}"
TARGET_TAG="${REGISTRY}/${REPO}:${TARGET_ENV}"

echo "Authenticating to ECR..."
aws ecr get-login-password --region "${AWS_REGION}" | \
  docker login --username AWS --password-stdin "${REGISTRY}"

echo "Verifying source image exists: ${SOURCE_TAG}"
if ! docker manifest inspect "${SOURCE_TAG}" > /dev/null 2>&1; then
  echo "ERROR: ${SOURCE_TAG} not found in registry." >&2
  echo "This commit was never built/scanned — refusing to promote a" >&2
  echo "non-existent artifact. Promotion only retags images that" >&2
  echo "already passed CI (build + Trivy scan)." >&2
  exit 1
fi

echo "Pulling ${SOURCE_TAG}..."
docker pull "${SOURCE_TAG}"

echo "Retagging as ${TARGET_TAG} (no rebuild)..."
docker tag "${SOURCE_TAG}" "${TARGET_TAG}"

echo "Pushing ${TARGET_TAG}..."
docker push "${TARGET_TAG}"

echo "Promoted ${SHA} -> ${TARGET_ENV}. Same image, new tag, no rebuild."
