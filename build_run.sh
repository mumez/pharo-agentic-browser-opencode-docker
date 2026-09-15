#!/bin/bash
set -euo pipefail

IMAGE="${IMAGE:-pharo-agentic-browser-opencode-docker-sis-pharo}"

docker build -t "$IMAGE" .

IMAGE="$IMAGE" exec "$(dirname "$0")/run.sh"
