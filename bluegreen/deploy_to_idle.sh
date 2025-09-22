#!/usr/bin/env bash
set -euo pipefail

BLUEGREEN_DIR="${HOME}/bluegreen"
ACTIVE_FILE="${BLUEGREEN_DIR}/ACTIVE"

TAG="${1:?usage: $(basename "$0") <tag>}"

# --- Determine which color is active and which is idle ---
ACTIVE=$(cat "$ACTIVE_FILE" 2>/dev/null || echo "blue")
if [[ "$ACTIVE" == "blue" ]]; then
  IDLE="green"
  COLOR_VAR="GREEN_TAG"
  SERVICE="hello-green"
else
  IDLE="blue"
  COLOR_VAR="BLUE_TAG"
  SERVICE="hello-blue"
fi

echo "Active: ${ACTIVE}; Idle: ${IDLE}; Tag to deploy: ${TAG}"
cd "$BLUEGREEN_DIR"

# --- Deploy the idle service with the new image tag ---
env "${COLOR_VAR}=${TAG}" docker compose -f docker-compose.bluegreen.yml up -d --no-deps "$SERVICE"

# --- Health check with retry loop ---
PORT=80
URL="http://hello-${IDLE}:${PORT}/healthz"   # change to "/" if no /healthz route exists

READY=0
for i in {1..30}; do
  if docker run --rm --network web curlimages/curl:8.9.1 -fsS "$URL" >/dev/null; then
    echo "✅ Idle (${IDLE}) healthy"
    READY=1
    break
  fi
  echo "…waiting for hello-${IDLE}:${PORT} (${i}/30)"
  sleep 1
done

if [[ "$READY" -ne 1 ]]; then
  echo "❌ Idle (${IDLE}) did not become healthy in time"
  docker run --rm --network web curlimages/curl:8.9.1 -v "$URL" || true
  exit 1
fi

echo "🎉 Deployment to ${IDLE} successful with tag '${TAG}'"
