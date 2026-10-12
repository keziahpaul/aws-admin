#!/usr/bin/env bash
# Seed empty agent ECR repositories with the stub agent image.
#
# Why: the infra apply creates image-consuming resources (ECS services and
# Bedrock AgentCore runtimes) that reference `<repo>:latest`. A brand-new
# agent has no image yet, so those resources fail to create. This script
# pushes a minimal stub image into any EMPTY agent repo so the first apply
# can succeed. Repos that already contain images (e.g. a live agent's real
# image) are left untouched.
#
# Idempotent and safe to re-run. Intended to run AFTER the ECR repositories
# exist (targeted apply) and BEFORE the full apply.
#
# Usage:
#   ./scripts/seed-stub-images.sh <agents-dir>
#
# Example:
#   ./scripts/seed-stub-images.sh environments/datanp/dev/agents

set -euo pipefail

AGENTS_DIR="${1:?Usage: $0 <agents-dir>}"
REGION="${AWS_REGION:-ap-southeast-2}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUB_DIR="${SCRIPT_DIR}/../stub-agent"

if [[ ! -d "$AGENTS_DIR" ]]; then
  echo "No agents dir at '$AGENTS_DIR', nothing to seed."
  exit 0
fi

# Collect every ECR image URI referenced by the agent configs
# (both container_image and slack_bot_image), skipping any agent that is
# disabled via enable_agent = false (those are being torn down).
ENABLED_FILES=()
for f in "$AGENTS_DIR"/*.hcl; do
  [[ -e "$f" ]] || continue
  if grep -qE '^\s*enable_agent\s*=\s*false' "$f"; then
    echo "Skipping disabled agent config: $(basename "$f")"
    continue
  fi
  ENABLED_FILES+=( "$f" )
done

if [[ ${#ENABLED_FILES[@]} -eq 0 ]]; then
  echo "No enabled agent configs in $AGENTS_DIR, nothing to seed."
  exit 0
fi

mapfile -t IMAGE_URIS < <(
  grep -hoE '[0-9]+\.dkr\.ecr\.[a-z0-9-]+\.amazonaws\.com/[A-Za-z0-9._/-]+:[A-Za-z0-9._-]+' \
    "${ENABLED_FILES[@]}" 2>/dev/null | sort -u
)

if [[ ${#IMAGE_URIS[@]} -eq 0 ]]; then
  echo "No ECR image URIs found in $AGENTS_DIR/*.hcl, nothing to seed."
  exit 0
fi

echo "=== Stub image seeding ==="
echo "Region:     $REGION"
echo "Stub dir:   $STUB_DIR"
echo "Found ${#IMAGE_URIS[@]} image URI(s)."
echo ""

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
ARM64_STUB_BUILT=0
AMD64_STUB_BUILT=0

login_ecr() {
  aws ecr get-login-password --region "$REGION" \
    | docker login --username AWS --password-stdin "$REGISTRY" >/dev/null
}

build_stub_once() {
  local platform="$1"
  local image="$2"

  if [[ "$platform" == "linux/arm64" && "$ARM64_STUB_BUILT" -eq 0 ]]; then
    echo "→ Building AgentCore stub image ($platform)..."
    docker build --platform "$platform" -t "$image" "$STUB_DIR"
    ARM64_STUB_BUILT=1
  elif [[ "$platform" == "linux/amd64" && "$AMD64_STUB_BUILT" -eq 0 ]]; then
    echo "→ Building ECS stub image ($platform)..."
    docker build --platform "$platform" -t "$image" "$STUB_DIR"
    AMD64_STUB_BUILT=1
  fi
}

SEEDED=0
SKIPPED=0
for URI in "${IMAGE_URIS[@]}"; do
  # Strip registry prefix and tag to get "<repo-name>:<tag>" -> repo + tag
  REPO_AND_TAG="${URI#*/}"
  REPO="${REPO_AND_TAG%:*}"
  TAG="${REPO_AND_TAG##*:}"

  # Does the repo already contain any image?
  IMAGE_COUNT="$(aws ecr describe-images \
    --repository-name "$REPO" \
    --region "$REGION" \
    --query 'length(imageDetails)' \
    --output text 2>/dev/null || echo "REPO_MISSING")"

  if [[ "$IMAGE_COUNT" == "REPO_MISSING" ]]; then
    echo "  ⚠️  $REPO: repository does not exist yet (skipping - create ECR first)."
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  if [[ "$IMAGE_COUNT" != "0" && "$IMAGE_COUNT" != "None" ]]; then
    echo "  ✓  $REPO: already has $IMAGE_COUNT image(s), leaving untouched."
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  echo "  +  $REPO: empty, seeding stub $TAG ..."
  case "$REPO" in
    *-agent-runtime)
      PLATFORM="linux/arm64"
      STUB_IMAGE="agent-platform-stub:arm64"
      ;;
    *-slack-bot)
      PLATFORM="linux/amd64"
      STUB_IMAGE="agent-platform-stub:amd64"
      ;;
    *)
      echo "     unsupported agent repository name; skipping."
      SKIPPED=$((SKIPPED + 1))
      continue
      ;;
  esac

  build_stub_once "$PLATFORM" "$STUB_IMAGE"
  login_ecr
  docker tag "$STUB_IMAGE" "${REGISTRY}/${REPO}:${TAG}"
  docker push "${REGISTRY}/${REPO}:${TAG}" >/dev/null
  echo "     pushed ${REGISTRY}/${REPO}:${TAG} ($PLATFORM)"
  SEEDED=$((SEEDED + 1))
done

echo ""
echo "=== Done: $SEEDED seeded, $SKIPPED skipped ==="
