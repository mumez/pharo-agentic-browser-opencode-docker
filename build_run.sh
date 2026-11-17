#!/bin/bash
set -euo pipefail

IMAGE="${IMAGE:-pharo-agentic-browser-opencode-docker}"
# The base image is linux/amd64-only, so pin the platform (emulated on Apple Silicon).
PLATFORM="${PLATFORM:-linux/amd64}"

docker build --platform "$PLATFORM" -t "$IMAGE" .

IMAGE="$IMAGE" PLATFORM="$PLATFORM" exec "$(dirname "$0")/run.sh"
